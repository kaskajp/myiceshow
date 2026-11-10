import argparse
import json
import math
from pathlib import Path
import runpy
import sys

from pxr import Gf, Usd, UsdGeom, UsdSkel


CHECKS = runpy.run_path(str(Path(__file__).with_name("validate.py")))
require = CHECKS["require"]
distance = CHECKS["distance"]
TOLERANCE = 0.00001
PATH_TOLERANCE = 0.0001
HEADING_TOLERANCE = 0.0001


def require_static_placement(prim):
    while prim and not prim.IsPseudoRoot():
        transform = UsdGeom.Xformable(prim)
        if transform:
            require(not transform.TransformMightBeTimeVarying(),
                    f"Root travel must remain in the skeletal track: {prim.GetPath()}")
            if transform.GetResetXformStack():
                return
        prim = prim.GetParent()


def validate(asset, source_report):
    report = json.loads(source_report.read_text())
    require(bool(report["native_samples_app_space"]), "Native deformation baseline is empty")
    stage = Usd.Stage.Open(str(asset))
    require(stage is not None, "Glide stage failed to open")
    require(UsdGeom.GetStageUpAxis(stage) == "Y" and UsdGeom.GetStageMetersPerUnit(stage) == 1, "Wrong axes/units")
    require((stage.GetStartTimeCode(), stage.GetEndTimeCode(), stage.GetTimeCodesPerSecond()) ==
            (1, report["last_frame"], report["fps"]), "Wrong glide timeline")
    roots = [UsdSkel.Root(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Root)]
    skeletons = [UsdSkel.Skeleton(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Skeleton)]
    meshes = [UsdGeom.Mesh(prim) for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh)]
    require(len(roots) == len(skeletons) == len(meshes) == 1, "Expected one root, skeleton and mesh")
    skeleton, mesh = skeletons[0], meshes[0]
    joints = list(skeleton.GetJointsAttr().Get())
    require(len(joints) == len(report["joint_names"]) and set(joints) == set(report["joint_names"]), "Wrong joint schema")
    require(not mesh.GetPointsAttr().ValueMightBeTimeVarying(), "Glide must be skeletal, not baked vertex motion")
    for prim in (roots[0].GetPrim(), skeleton.GetPrim(), mesh.GetPrim()):
        require_static_placement(prim)
    require(len(mesh.GetPointsAttr().Get()) == report["vertices"], "Vertex count changed")
    require(len(mesh.GetFaceVertexCountsAttr().Get()) == report["triangles"], "Topology count changed")
    cache = UsdSkel.Cache()
    cache.Populate(roots[0], Usd.PrimDefaultPredicate)
    query = cache.GetSkelQuery(skeleton)
    skin = cache.GetSkinningQuery(mesh.GetPrim())
    require(bool(query) and bool(skin), "Missing skeleton/skin binding")
    world = UsdGeom.XformCache(1).GetLocalToWorldTransform(skeleton.GetPrim())
    landmarks = report["landmark_indices"]
    radius, speed = report["radius_m"], report["speed_m_s"]
    initial = report["initial_contact_app_space"]
    maximum_contact_height = 0
    minimum_free_clearance = math.inf
    maximum_path_error = 0
    maximum_heading_error = 0
    maximum_export_error = 0
    maximum_penetration = 0
    captures = 0
    compared_frames = set()
    for step in range(2 * (report["last_frame"] - 1) + 1):
        frame = 1 + step / 2
        seconds = (frame - 1) / report["fps"]
        points = mesh.GetPointsAttr().Get()
        require(skin.ComputeSkinnedPoints(query.ComputeSkinningTransforms(frame), points, frame), "Skin evaluation failed")
        points = [tuple(world.Transform(Gf.Vec3d(*point))) for point in points]
        require(all(math.isfinite(value) for point in points for value in point), "Non-finite skinned point")
        contact = points[landmarks["outside"]]
        inside = points[landmarks["inside"]]
        left_bottom = min(points[index][1] for index in report["left_blade_indices"])
        free_bottom = min(points[index][1] for index in report["right_blade_indices"])
        require(abs(left_bottom) < TOLERANCE and abs(contact[1]) < TOLERANCE, "Support blade lost floor contact")
        require(inside[1] > contact[1], "Left runner is not banked onto its outside edge")
        require(free_bottom > 0.1, "Free right blade lost its candidate clearance")
        minimum = min(point[1] for point in points)
        require(minimum >= -TOLERANCE, "Skinned geometry penetrates the ice")
        angle = speed * seconds / radius
        expected = (initial[0] + radius * (math.cos(angle) - 1), 0, initial[2] + radius * math.sin(angle))
        path_error = distance(contact, expected)
        require(path_error < PATH_TOLERANCE, "Support contact left the authored arc")
        forward, backward = points[landmarks["forward"]], points[landmarks["backward"]]
        direction = Gf.Vec3d(forward[0] - backward[0], 0, forward[2] - backward[2]).GetNormalized()
        heading_error = distance(direction, (-math.sin(angle), 0, math.cos(angle)))
        require(heading_error < HEADING_TOLERANCE, "Supporting blade heading is not tangent to its arc")
        key = str(int(frame)) if frame.is_integer() else str(frame)
        if key in report["native_samples_app_space"]:
            expected_points = report["native_samples_app_space"][key]
            require(len(points) == len(expected_points), "Native sample size changed")
            error = max(distance(first, second) for first, second in zip(points, expected_points))
            require(error < TOLERANCE, f"Export differs from native Blender deformation: {error}")
            maximum_export_error = max(maximum_export_error, error)
            compared_frames.add(key)
        maximum_contact_height = max(maximum_contact_height, abs(contact[1]), abs(left_bottom))
        minimum_free_clearance = min(minimum_free_clearance, free_bottom)
        maximum_path_error = max(maximum_path_error, path_error)
        maximum_heading_error = max(maximum_heading_error, heading_error)
        maximum_penetration = max(maximum_penetration, -minimum)
        captures += 1
    require(compared_frames == set(report["native_samples_app_space"]), "A native baseline frame was not compared")
    return {
        "status": "Geometric/export checks only; skating review pending",
        "sampled_integer_and_half_frames": captures,
        "native_compared_frames": sorted(compared_frames, key=float),
        "maximum_support_height_error_m": maximum_contact_height,
        "minimum_free_blade_clearance_m": minimum_free_clearance,
        "maximum_path_error_m": maximum_path_error,
        "maximum_heading_vector_error": maximum_heading_error,
        "maximum_native_export_vertex_error_m": maximum_export_error,
        "maximum_ice_penetration_m": maximum_penetration,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", type=Path, required=True)
    parser.add_argument("--source-report", type=Path, required=True)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    print(json.dumps(validate(arguments.asset, arguments.source_report), indent=2))


if __name__ == "__main__":
    main()
