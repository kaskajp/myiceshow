import argparse
import json
import math
from pathlib import Path
import runpy
import sys

from pxr import Gf, Usd, UsdGeom, UsdSkel


CHECKS = runpy.run_path(str(Path(__file__).with_name("validate-glide.py")))
require = CHECKS["require"]
distance = CHECKS["distance"]


def rotate_heading(point, yaw):
    cosine, sine = math.cos(yaw), math.sin(yaw)
    return Gf.Vec3d(cosine * point[0] + sine * point[2], point[1], -sine * point[0] + cosine * point[2])


def blade_heading(points, landmarks):
    delta = points[landmarks["forward"]] - points[landmarks["backward"]]
    require(math.hypot(delta[0], delta[2]) > 0, "Degenerate supporting blade heading")
    return Gf.Vec3d(delta[0], 0, delta[2]).GetNormalized()


def repeat_placement(first, last, landmarks):
    start_heading = blade_heading(first, landmarks)
    end_heading = blade_heading(last, landmarks)
    yaw = math.atan2(end_heading[0], end_heading[2]) - math.atan2(start_heading[0], start_heading[2])
    start_contact, end_contact = first[landmarks["outside"]], last[landmarks["outside"]]

    def place(points):
        return [end_contact + rotate_heading(point - start_contact, yaw) for point in points]

    return place


def audit_repeat(sample, report, place):
    first_frame, last_frame, fps = 1, report["last_frame"], report["fps"]
    duration = (last_frame - first_frame) / fps
    landmarks = report["landmark_indices"]
    first, last = sample(first_frame), sample(last_frame)
    next_first = place(first)
    seam_error = max(distance(before, after) for before, after in zip(last, next_first))
    require(seam_error < CHECKS["TOLERANCE"], f"Repeated mesh pose is discontinuous: {seam_error} m")
    heading_error = distance(blade_heading(last, landmarks), blade_heading(next_first, landmarks))
    require(heading_error < CHECKS["HEADING_TOLERANCE"], "Repeated support heading is discontinuous")
    maximum_path_error = 0
    maximum_support_height = 0
    minimum_free_clearance = math.inf
    maximum_penetration = 0
    maximum_heading_error = 0
    captures = 0
    initial = Gf.Vec3d(*report["initial_contact_app_space"])
    radius, speed = report["radius_m"], report["speed_m_s"]
    for segment in (0, 1):
        for step in range(2 * (last_frame - first_frame) + 1):
            frame = first_frame + step / 2
            points = sample(frame)
            if segment == 1:
                points = place(points)
            seconds = segment * duration + (frame - first_frame) / fps
            angle = speed * seconds / radius
            expected = initial + Gf.Vec3d(radius * (math.cos(angle) - 1), 0, radius * math.sin(angle))
            contact, inside = points[landmarks["outside"]], points[landmarks["inside"]]
            support_height = max(abs(contact[1]), abs(min(points[index][1] for index in report["left_blade_indices"])))
            free_clearance = min(points[index][1] for index in report["right_blade_indices"])
            minimum = min(point[1] for point in points)
            path_error = distance(contact, expected)
            tangent_error = distance(blade_heading(points, landmarks), (-math.sin(angle), 0, math.cos(angle)))
            require(support_height < CHECKS["TOLERANCE"], "Repeated support blade lost floor contact")
            require(inside[1] > contact[1], "Repeated support lost its outside-edge bank")
            require(free_clearance > 0.1, "Repeated free blade lost clearance")
            require(minimum >= -CHECKS["TOLERANCE"], "Repeated mesh penetrates the ice")
            require(path_error < CHECKS["PATH_TOLERANCE"], "Repeated support contact left the continuing arc")
            require(tangent_error < CHECKS["HEADING_TOLERANCE"], "Repeated blade is not tangent to the continuing arc")
            maximum_path_error = max(maximum_path_error, path_error)
            maximum_support_height = max(maximum_support_height, support_height)
            minimum_free_clearance = min(minimum_free_clearance, free_clearance)
            maximum_penetration = max(maximum_penetration, -minimum)
            maximum_heading_error = max(maximum_heading_error, tangent_error)
            captures += 1
    velocities = []
    for frame_step in (1 / 16, 1 / 64):
        seconds_step = frame_step / fps
        before, after = sample(last_frame - frame_step), place(sample(first_frame + frame_step))
        incoming = [(end - previous) / seconds_step for previous, end in zip(before, last)]
        outgoing = [(following - start) / seconds_step for start, following in zip(next_first, after)]
        contact_index = landmarks["outside"]
        velocities.append({
            "one_sided_step_s": seconds_step,
            "support_incoming_velocity_m_s": list(incoming[contact_index]),
            "support_outgoing_velocity_m_s": list(outgoing[contact_index]),
            "support_velocity_jump_m_s": distance(incoming[contact_index], outgoing[contact_index]),
            "maximum_vertex_velocity_jump_m_s": max(distance(left, right) for left, right in zip(incoming, outgoing)),
        })
    return {
        "status": "Sampled position/contact repeat only; velocity continuity and skating approval are separate gates",
        "seconds": 2 * duration,
        "sampled_copy_frames_including_both_seam_sides": captures,
        "maximum_seam_vertex_gap_m": seam_error,
        "seam_heading_vector_gap": heading_error,
        "maximum_support_height_error_m": maximum_support_height,
        "minimum_free_blade_clearance_m": minimum_free_clearance,
        "maximum_ice_penetration_m": maximum_penetration,
        "maximum_continuing_arc_error_m": maximum_path_error,
        "maximum_heading_vector_error": maximum_heading_error,
        "one_sided_seam_velocities": velocities,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", type=Path, required=True)
    parser.add_argument("--source-report", type=Path, required=True)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    validation = CHECKS["validate"](arguments.asset, arguments.source_report)
    report = json.loads(arguments.source_report.read_text())
    stage = Usd.Stage.Open(str(arguments.asset))
    root = next(UsdSkel.Root(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Root))
    skeleton = next(UsdSkel.Skeleton(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Skeleton))
    mesh = next(UsdGeom.Mesh(prim) for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh))
    cache = UsdSkel.Cache()
    cache.Populate(root, Usd.PrimDefaultPredicate)
    query = cache.GetSkelQuery(skeleton)
    skin = cache.GetSkinningQuery(mesh.GetPrim())
    world = UsdGeom.XformCache(1).GetLocalToWorldTransform(skeleton.GetPrim())

    def sample(frame):
        points = mesh.GetPointsAttr().Get()
        require(skin.ComputeSkinnedPoints(query.ComputeSkinningTransforms(frame), points, frame), "Skin evaluation failed")
        return [world.Transform(Gf.Vec3d(*point)) for point in points]

    place = repeat_placement(sample(1), sample(report["last_frame"]), report["landmark_indices"])
    audit = audit_repeat(sample, report, place)
    pelvis_index = list(skeleton.GetJointsAttr().Get()).index("pelvis")
    root_positions = {
        frame: world.Transform(query.ComputeJointSkelTransforms(frame)[pelvis_index].ExtractTranslation())
        for frame in (1, 2, report["last_frame"] - 1, report["last_frame"])
    }
    incoming = (root_positions[report["last_frame"]] - root_positions[report["last_frame"] - 1]) * report["fps"]
    next_first, next_second = place([root_positions[1], root_positions[2]])
    outgoing = (next_second - next_first) * report["fps"]
    audit["pelvis_key_segment_velocities"] = {
        "incoming_m_s": list(incoming),
        "outgoing_m_s": list(outgoing),
        "jump_m_s": distance(incoming, outgoing),
        "interpolation": str(stage.GetInterpolationType()),
    }
    print(json.dumps({"candidate_validation": validation, "repeat_audit": audit}, indent=2))


if __name__ == "__main__":
    main()
