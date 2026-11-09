import argparse
import json
import math
from pathlib import Path
import sys

from pxr import Gf, Usd, UsdGeom, UsdShade, UsdSkel


TOLERANCE = 0.00001


def require(condition, message):
    if not condition:
        raise ValueError(message)


def distance(first, second):
    require(all(math.isfinite(value) for value in (*first, *second)), "Non-finite point")
    return (Gf.Vec3d(*first) - Gf.Vec3d(*second)).GetLength()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", type=Path, required=True)
    parser.add_argument("--source-report", type=Path, required=True)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    report = json.loads(arguments.source_report.read_text())
    stage = Usd.Stage.Open(str(arguments.asset))
    require(stage is not None, "USD stage failed to open")
    require(UsdGeom.GetStageUpAxis(stage) == "Y", "Expected Y-up")
    require(UsdGeom.GetStageMetersPerUnit(stage) == 1, "Expected meters")
    require((stage.GetStartTimeCode(), stage.GetEndTimeCode(), stage.GetTimeCodesPerSecond()) == (1, 49, 24), "Wrong calibration timeline")
    skeletons = [UsdSkel.Skeleton(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Skeleton)]
    meshes = [UsdGeom.Mesh(prim) for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh)]
    roots = [UsdSkel.Root(prim) for prim in stage.Traverse() if prim.IsA(UsdSkel.Root)]
    require(len(skeletons) == len(meshes) == len(roots) == 1, "Expected one root, skeleton and mesh")
    skeleton, mesh = skeletons[0], meshes[0]
    joints = list(skeleton.GetJointsAttr().Get())
    expected = report["joints_app_space"]
    require(len(joints) == len(expected) and set(joints) == set(expected), "Joint hierarchy mismatch")
    world = UsdGeom.XformCache(1).GetLocalToWorldTransform(skeleton.GetPrim())
    binds = skeleton.GetBindTransformsAttr().Get()
    require(len(binds) == len(joints), "Bind transform count mismatch")
    bind_position_error = max(distance(world.Transform(matrix.ExtractTranslation()), expected[name]) for name, matrix in zip(joints, binds))
    require(bind_position_error < TOLERANCE, f"Bind calibration mismatch: {bind_position_error}")
    bind_matrix_error = 0
    for name, matrix in zip(joints, binds):
        original = report["rest_bone_matrices_blender"][name.rsplit("/", 1)[-1]]
        bind_matrix_error = max(bind_matrix_error, max(abs(matrix[row][column] - original[column][row]) for row in range(4) for column in range(4)))
    require(bind_matrix_error < TOLERANCE, "Bind axes changed from Blender")
    cache = UsdSkel.Cache()
    cache.Populate(roots[0], Usd.PrimDefaultPredicate)
    query = cache.GetSkelQuery(skeleton)
    rest = query.ComputeJointSkelTransforms(Usd.TimeCode.Default(), True)
    require(len(rest) == len(binds), "Rest transform count mismatch")
    rest_error = max(abs(first[row][column] - second[row][column]) for first, second in zip(rest, binds) for row in range(4) for column in range(4))
    require(rest_error < TOLERANCE, "Rest and bind matrices disagree")
    skin = cache.GetSkinningQuery(mesh.GetPrim())
    require(bool(skin), "Missing skin binding")
    indices, weights = skin.ComputeJointInfluences(1)
    influences = skin.GetNumInfluencesPerComponent()
    points = mesh.GetPointsAttr().Get()
    require(len(points) == report["vertices"], "Vertex count changed")
    require(len(indices) == len(weights) == len(points) * influences, "Invalid vertex influence layout")
    require(all(0 <= index < len(joints) for index in indices), "Invalid skin palette index")
    require(all(math.isfinite(weight) and weight >= 0 for weight in weights), "Invalid skin weight")
    weight_error = max(abs(sum(weights[offset:offset + influences]) - 1) for offset in range(0, len(weights), influences))
    require(weight_error < TOLERANCE, "Skin weights do not sum to one")
    require(not mesh.GetPointsAttr().ValueMightBeTimeVarying(), "Expected skeleton animation, not baked mesh points")
    bindings = UsdGeom.Subset.GetAllGeomSubsets(mesh)
    blade_vertices = set()
    counts = mesh.GetFaceVertexCountsAttr().Get()
    face_indices = mesh.GetFaceVertexIndicesAttr().Get()
    require(all(count == 3 for count in counts), "Expected triangles")
    require(len(counts) == report["triangles"], "Triangle count changed")
    for subset in bindings:
        material, _ = UsdShade.MaterialBindingAPI(subset).ComputeBoundMaterial()
        if material and material.GetPrim().GetName() == "Blades":
            for face in subset.GetIndicesAttr().Get():
                blade_vertices.update(face_indices[face * 3:face * 3 + 3])
    require(bool(blade_vertices), "Blade material subset missing")
    export_error = 0
    blade_drift = 0
    first_blades = None
    for frame, expected_points in report["native_samples_app_space"].items():
        sample = mesh.GetPointsAttr().Get()
        time = int(frame)
        require(skin.ComputeSkinnedPoints(query.ComputeSkinningTransforms(time), sample, time), "Skin evaluation failed")
        sample = [tuple(world.Transform(Gf.Vec3d(*point))) for point in sample]
        require(len(sample) == len(expected_points), "Native sample count mismatch")
        export_error = max(export_error, max(distance(first, second) for first, second in zip(sample, expected_points)))
        blades = [sample[index] for index in sorted(blade_vertices)]
        if first_blades is None:
            first_blades = blades
        blade_drift = max(blade_drift, max(distance(first, second) for first, second in zip(blades, first_blades)))
    require(export_error < TOLERANCE, f"Native/export deformation mismatch: {export_error}")
    require(blade_drift < TOLERANCE, "Calibration unexpectedly moves blades")
    for side in (-1, 1):
        sole = [point for point in first_blades if point[0] * side > 0]
        require(bool(sole), "Missing blade side")
        require(abs(min(point[1] for point in sole)) < TOLERANCE, "Blade does not meet floor zero")
        require(abs(max(point[2] for point in sole) - 0.18) < TOLERANCE, "Blade toe orientation changed")
        require(abs(min(point[2] for point in sole) + 0.14) < TOLERANCE, "Blade heel orientation changed")
    result = {
        "asset": str(arguments.asset),
        "joints": len(joints),
        "vertices": len(points),
        "triangles": len(counts),
        "bind_position_error_m": bind_position_error,
        "bind_matrix_error": bind_matrix_error,
        "rest_bind_error": rest_error,
        "weight_sum_error": weight_error,
        "native_export_vertex_error_m": export_error,
        "sampled_blade_drift_m": blade_drift,
        "sampled_frames": list(report["native_samples_app_space"]),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
