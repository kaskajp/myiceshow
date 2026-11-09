import argparse
import json
import math
from pathlib import Path
import runpy
import sys

import bpy
from mathutils import Quaternion, Vector


FIXTURE = runpy.run_path(str(Path(__file__).resolve().parents[1] / "generate-skater-fixture.py"))
JOINTS = FIXTURE["JOINTS"]
START, MIDDLE, END = 1, 25, 49


def blender_position(position):
    horizontal, height, forward = position
    return Vector((horizontal, -forward, height))


def app_position(position):
    horizontal, backward, height = position
    return (horizontal, height, -backward)


def build_rig():
    armature = bpy.data.armatures.new("SkaterSkeleton")
    rig = bpy.data.objects.new("SkaterRig", armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    positions = dict(JOINTS)
    successors = {
        "pelvis": "pelvis/spine",
        "pelvis/spine": "pelvis/spine/head",
    }
    for side in ("left", "right"):
        hip = f"pelvis/{side}Hip"
        shoulder = f"pelvis/spine/{side}Shoulder"
        successors.update({
            hip: f"{hip}/{side}Knee",
            f"{hip}/{side}Knee": f"{hip}/{side}Knee/{side}Ankle",
            shoulder: f"{shoulder}/{side}Elbow",
            f"{shoulder}/{side}Elbow": f"{shoulder}/{side}Elbow/{side}Wrist",
        })
    for path, position in JOINTS:
        name = path.rsplit("/", 1)[-1]
        bone = armature.edit_bones.new(name)
        bone.head = blender_position(position)
        target = successors.get(path)
        bone.tail = blender_position(positions[target]) if target else bone.head + Vector((0, 0, 0.1))
        parent_path = path.rpartition("/")[0]
        if parent_path:
            bone.parent = armature.edit_bones[parent_path.rsplit("/", 1)[-1]]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def runner(mesh, center, joint):
    first = len(mesh.points)
    samples = sorted({0.0} | {-0.14 + 0.32 * step / 24 for step in range(25)})
    for forward in samples:
        bottom = forward * forward / (2 * 2.0)
        for horizontal, height in ((-0.002, bottom), (0.002, bottom), (0.002, bottom + 0.024), (-0.002, bottom + 0.024)):
            mesh.vertex((center + horizontal, height, forward), (0, 1, 0), FIXTURE["rigid"](joint))
    for step in range(len(samples) - 1):
        for edge in range(4):
            lower = first + step * 4 + edge
            upper = first + step * 4 + (edge + 1) % 4
            mesh.faces.extend(((lower, upper, upper + 4), (lower, upper + 4, lower + 4)))
    mesh.faces.extend(((first, first + 2, first + 1), (first, first + 3, first + 2)))
    last = first + (len(samples) - 1) * 4
    mesh.faces.extend(((last, last + 1, last + 2), (last, last + 2, last + 3)))
    for forward in (-0.075, 0.095):
        mesh.ellipsoid((center, 0.034, forward), (0.018, 0.018, 0.024), joint)


def body_meshes():
    meshes = {name: FIXTURE["Mesh"](name) for name in FIXTURE["MATERIALS"]}
    rigid, influences = FIXTURE["rigid"], FIXTURE["influences"]
    meshes["Costume"].tube([
        ((0, 0.99, 0), 0.19, rigid("pelvis")),
        ((0, 1.13, 0), 0.17, influences("pelvis", "spine", 0.1)),
        ((0, 1.28, 0), 0.14, influences("pelvis", "spine", 0.45)),
        ((0, 1.43, 0), 0.19, influences("pelvis", "spine", 0.85)),
        ((0, 1.56, 0), 0.23, rigid("spine")),
    ], "y")
    for side, direction in (("left", -1), ("right", 1)):
        FIXTURE["leg"](meshes["Leggings"], side, direction)
        FIXTURE["arm"](meshes["Skin"], side, direction)
        ankle = f"{side}Ankle"
        meshes["Boots"].ellipsoid((direction * 0.13, 0.08, 0.025), (0.075, 0.06, 0.16), ankle)
        runner(meshes["Blades"], direction * 0.13, ankle)
    meshes["Skin"].ellipsoid((0, 1.65, 0), (0.055, 0.09, 0.055), "spine")
    meshes["Skin"].ellipsoid((0, 1.78, 0), (0.15, 0.17, 0.14), "head")
    meshes["Hair"].ellipsoid((0, 1.86, -0.025), (0.145, 0.11, 0.13), "head")
    return meshes


def build_skin(rig):
    vertices, faces, weights, material_indices = [], [], [], []
    meshes = body_meshes()
    for material_index, mesh in enumerate(meshes.values()):
        offset = len(vertices)
        vertices.extend(blender_position(point) for point in mesh.points)
        faces.extend(tuple(index + offset for index in face) for face in mesh.faces)
        material_indices.extend([material_index] * len(mesh.faces))
        for vertex in range(len(mesh.points)):
            combined = {}
            for influence in range(2):
                slot = vertex * 2 + influence
                name = JOINTS[mesh.indices[slot]][0].rsplit("/", 1)[-1]
                combined[name] = combined.get(name, 0) + mesh.weights[slot]
            weights.append(combined)
    mesh_data = bpy.data.meshes.new("SkaterBody")
    mesh_data.from_pydata(vertices, [], faces)
    mesh_data.update()
    skin = bpy.data.objects.new("SkaterBody", mesh_data)
    bpy.context.collection.objects.link(skin)
    for name, color in FIXTURE["MATERIALS"].items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = (*color, 1)
        material.use_nodes = True
        surface = material.node_tree.nodes.get("Principled BSDF")
        surface.inputs["Base Color"].default_value = (*color, 1)
        surface.inputs["Metallic"].default_value = 0.65 if name == "Blades" else 0
        surface.inputs["Roughness"].default_value = 0.35 if name == "Blades" else 0.7
        mesh_data.materials.append(material)
    for polygon, material_index in zip(mesh_data.polygons, material_indices):
        polygon.material_index = material_index
        polygon.use_smooth = list(meshes)[material_index] != "Blades"
    for path, _ in JOINTS:
        skin.vertex_groups.new(name=path.rsplit("/", 1)[-1])
    for vertex, influences in enumerate(weights):
        if abs(sum(influences.values()) - 1) > 0.00001:
            raise ValueError(f"Invalid skin weights at vertex {vertex}")
        for name, weight in influences.items():
            if weight > 0:
                skin.vertex_groups[name].add([vertex], weight, "REPLACE")
    skin.parent = rig
    modifier = skin.modifiers.new("SkaterSkin", "ARMATURE")
    modifier.object = rig
    bpy.context.view_layer.objects.active = skin
    rig.select_set(False)
    skin.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return skin


def animate(rig):
    rotations = {
        "leftShoulder": (0, 0, math.radians(45)),
        "rightShoulder": (0, 0, math.radians(-45)),
        "leftElbow": (math.radians(65), 0, 0),
        "rightElbow": (math.radians(-65), 0, 0),
        "spine": (math.radians(10), 0, 0),
    }
    for frame in (START, MIDDLE, END):
        for bone in rig.pose.bones:
            bone.rotation_mode = "QUATERNION"
            rotation = rotations.get(bone.name, (0, 0, 0)) if frame == MIDDLE else (0, 0, 0)
            bone.rotation_quaternion = (
                Quaternion((1, 0, 0), rotation[0])
                @ Quaternion((0, 1, 0), rotation[1])
                @ Quaternion((0, 0, 1), rotation[2])
            )
            for channel in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(data_path=channel, frame=frame, group=bone.name)
    rig.animation_data.action.name = "Calibration_NotSkating"


def capture(skin, frame):
    bpy.context.scene.frame_set(frame)
    evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [tuple(evaluated.matrix_world @ vertex.co) for vertex in evaluated.data.vertices]


def export_scene(path):
    if path.exists():
        raise FileExistsError(f"Refusing to overwrite export: {path}")
    result = bpy.ops.wm.usd_export(
        filepath=str(path),
        export_animation=True,
        export_armatures=True,
        only_deform_bones=True,
        export_shapekeys=False,
        export_materials=True,
        export_textures=False,
        export_lights=False,
        export_cameras=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        convert_scene_units="METERS",
        root_prim_path="/SkaterStudy",
        export_custom_properties=False,
    )
    if result != {"FINISHED"} or not path.is_file():
        raise RuntimeError("USD export did not finish")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    output = arguments.output.resolve()
    if output.exists():
        raise FileExistsError(f"Use a fresh output directory: {output}")
    if bpy.app.version[:2] != (4, 5):
        raise RuntimeError("This study targets Blender 4.5 LTS")
    output.mkdir(parents=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = START, END
    rig = build_rig()
    skin = build_skin(rig)
    animate(rig)
    neutral = capture(skin, START)
    bent = capture(skin, MIDDLE)
    returned = capture(skin, END)
    change = max((Vector(first) - Vector(second)).length for first, second in zip(neutral, bent))
    repeat_error = max((Vector(first) - Vector(second)).length for first, second in zip(neutral, returned))
    if change < 0.1 or repeat_error > 0.00001:
        raise ValueError("Native calibration deformation or return check failed")
    scene.frame_set(START)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "SkaterStudy.blend"))
    export_scene(output / "SkaterStudy.usdc")
    report = {
        "blender": bpy.app.version_string,
        "clip": "Calibration_NotSkating",
        "frames": [START, MIDDLE, END],
        "fps": scene.render.fps,
        "joints_app_space": dict(JOINTS),
        "vertices": len(skin.data.vertices),
        "triangles": len(skin.data.polygons),
        "native_max_vertex_change_m": change,
        "native_return_error_m": repeat_error,
        "blade": {"length_m": 0.32, "thickness_m": 0.004, "nominal_rocker_radius_m": 2.0},
        "rest_bone_matrices_blender": {
            bone.name: [list(row) for row in bone.matrix_local] for bone in rig.data.bones
        },
        "native_samples_app_space": {
            str(frame): [app_position(point) for point in capture(skin, frame)]
            for frame in (START, 13, MIDDLE, 37, END)
        },
    }
    (output / "source-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(output), "native_change_m": change, "native_return_error_m": repeat_error}))


if __name__ == "__main__":
    main()
