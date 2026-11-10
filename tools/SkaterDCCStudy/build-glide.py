import argparse
import json
import math
from pathlib import Path
import runpy
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector


AUTHORING = runpy.run_path(str(Path(__file__).with_name("build.py")))
FPS = 24
LAST_FRAME = 73
SPEED = 1.2
RADIUS = 4.0
BANK = math.atan(SPEED * SPEED / (9.81 * RADIUS))
APP_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
TOLERANCE = 0.00001


def solve_limb(start, end, pole, upper, lower):
    delta = end - start
    distance = delta.length
    if not abs(upper - lower) < distance < upper + lower:
        raise ValueError("Glide limb target is unreachable")
    axis = delta / distance
    bend = (pole - axis * pole.dot(axis)).normalized()
    along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    height = math.sqrt(upper * upper - along * along)
    return start + axis * along + bend * height


def local_stance():
    bank = Quaternion((0, 0, 1), BANK)
    identity = Quaternion((1, 0, 0), 0)
    left_ankle = Vector((-0.13, 0.08 * math.cos(BANK) + 0.002 * math.sin(BANK), 0))
    contact = left_ankle + bank @ Vector((-0.002, -0.08, 0))
    pelvis = contact + bank @ Vector((0, 0.98, 0))
    shoulders = pelvis + bank @ Vector((0, 0.5, 0))
    heads = {"pelvis": pelvis, "spine": shoulders, "head": shoulders + bank @ Vector((0, 0.22, 0))}
    rotations = {name: bank for name in heads}
    for side, direction in (("left", -1), ("right", 1)):
        hip = pelvis + bank @ Vector((direction * 0.13, 0, 0))
        ankle = left_ankle if side == "left" else pelvis + Vector((0.14, 0.28 - pelvis.y, -0.25))
        knee = solve_limb(hip, ankle, Vector((0, 0, 1)), 0.5, 0.48)
        shoulder = shoulders + bank @ Vector((direction * 0.23, 0, 0))
        wrist = shoulder + bank @ Vector((direction * 0.46, -0.12, 0.05))
        elbow = solve_limb(shoulder, wrist, Vector((0, -1, 0)), 0.27, 0.25)
        heads.update({f"{side}Hip": hip, f"{side}Knee": knee, f"{side}Ankle": ankle,
                      f"{side}Shoulder": shoulder, f"{side}Elbow": elbow, f"{side}Wrist": wrist})
        down = Vector((0, -1, 0))
        arm_axis = Vector((direction, 0, 0))
        rotations.update({
            f"{side}Hip": down.rotation_difference(knee - hip),
            f"{side}Knee": down.rotation_difference(ankle - knee),
            f"{side}Ankle": bank if side == "left" else identity,
            f"{side}Shoulder": arm_axis.rotation_difference(elbow - shoulder),
            f"{side}Elbow": arm_axis.rotation_difference(wrist - elbow),
            f"{side}Wrist": arm_axis.rotation_difference(wrist - elbow),
        })
    return {"heads": heads, "rotations": rotations, "contact": contact}


def pose_matrices(rig, stance, seconds):
    angle = SPEED * seconds / RADIUS
    heading = Quaternion((0, 1, 0), -angle)
    path = stance["contact"] + Vector((RADIUS * (math.cos(angle) - 1), 0, RADIUS * math.sin(angle)))
    offset = path - heading @ stance["contact"]
    matrices = {}
    for bone in rig.data.bones:
        rotation = APP_TO_BLENDER @ (heading @ stance["rotations"][bone.name]).to_matrix() @ APP_TO_BLENDER.transposed()
        matrix = (rotation @ bone.matrix_local.to_3x3()).to_4x4()
        matrix.translation = AUTHORING["blender_position"](offset + heading @ stance["heads"][bone.name])
        matrices[bone.name] = matrix
    return matrices


def animate(rig, stance):
    previous = {}
    maximum_head_error = 0
    for frame in range(1, LAST_FRAME + 1):
        bpy.context.scene.frame_set(frame)
        matrices = pose_matrices(rig, stance, (frame - 1) / FPS)
        for pose in rig.pose.bones:
            bone = pose.bone
            parent = {}
            if bone.parent:
                parent = {"parent_matrix": matrices[bone.parent.name], "parent_matrix_local": bone.parent.matrix_local}
            pose.rotation_mode = "QUATERNION"
            pose.matrix_basis = bone.convert_local_to_pose(matrices[bone.name], bone.matrix_local, invert=True, **parent)
            if max(abs(value - 1) for value in pose.scale) > TOLERANCE:
                raise ValueError("Glide pose stretches a bone")
            pose.scale = (1, 1, 1)
            if pose.name in previous and previous[pose.name].dot(pose.rotation_quaternion) < 0:
                pose.rotation_quaternion.negate()
            previous[pose.name] = pose.rotation_quaternion.copy()
            for channel in ("location", "rotation_quaternion", "scale"):
                pose.keyframe_insert(data_path=channel, frame=frame, group=pose.name)
        bpy.context.view_layer.update()
        maximum_head_error = max(maximum_head_error, max(
            (pose.matrix.translation - matrices[pose.name].translation).length for pose in rig.pose.bones
        ))
    if maximum_head_error > TOLERANCE:
        raise ValueError(f"Native rig missed authored joint targets: {maximum_head_error}")
    action = rig.animation_data.action
    action.name = "LFO_GlideCandidate_Unreviewed"
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = "LINEAR"
    return maximum_head_error


def capture(skin, frame):
    bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
    evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [AUTHORING["app_position"](evaluated.matrix_world @ vertex.co) for vertex in evaluated.data.vertices]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    output = arguments.output.resolve()
    if output.exists():
        raise FileExistsError(f"Use a fresh output directory: {output}")
    if bpy.app.version[:2] != (4, 5):
        raise RuntimeError("This candidate targets Blender 4.5 LTS")
    output.mkdir(parents=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, LAST_FRAME
    rig = AUTHORING["build_rig"]()
    skin = AUTHORING["build_skin"](rig)
    stance = local_stance()
    target_error = animate(rig, stance)
    blade_material = list(AUTHORING["FIXTURE"]["MATERIALS"]).index("Blades")
    blade_vertices = {index for face in skin.data.polygons if face.material_index == blade_material for index in face.vertices}
    rest = [AUTHORING["app_position"](vertex.co) for vertex in skin.data.vertices]
    left = sorted(index for index in blade_vertices if rest[index][0] < 0)
    right = sorted(blade_vertices - set(left))
    landmarks = {}
    for name, position in {"outside": (-0.132, 0, 0), "inside": (-0.128, 0, 0),
                           "forward": (-0.132, (1 / 150) ** 2 / 4, 1 / 150),
                           "backward": (-0.132, (1 / 150) ** 2 / 4, -1 / 150)}.items():
        nearest = min(left, key=lambda index: (Vector(rest[index]) - Vector(position)).length)
        if (Vector(rest[nearest]) - Vector(position)).length > TOLERANCE:
            raise ValueError(f"Missing runner landmark: {name}")
        landmarks[name] = nearest
    samples = {str(frame): capture(skin, frame) for frame in (1, 19, 19.5, 37, 55, 55.5, 73)}
    report = {
        "status": "Unreviewed intended LFO sustained-glide candidate; not approved skating",
        "blender": bpy.app.version_string, "fps": FPS, "last_frame": LAST_FRAME,
        "speed_m_s": SPEED, "radius_m": RADIUS, "bank_radians": BANK,
        "initial_contact_app_space": list(stance["contact"]),
        "landmark_indices": landmarks, "left_blade_indices": left, "right_blade_indices": right,
        "vertices": len(rest), "triangles": len(skin.data.polygons),
        "native_joint_target_error_m": target_error,
        "native_samples_app_space": samples,
        "joint_names": [path for path, _ in AUTHORING["JOINTS"]],
    }
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "GlideCandidate.blend"))
    AUTHORING["export_scene"](output / "GlideCandidate.usdc")
    (output / "source-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(output), "native_joint_target_error_m": target_error}))


if __name__ == "__main__":
    main()
