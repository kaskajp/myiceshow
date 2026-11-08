import math
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "MyIceShow" / "Assets" / "SkaterFixture.usdz"
SIDES = 12
JOINTS = [
    ("pelvis", (0, 1.06, 0)),
    ("pelvis/spine", (0, 1.56, 0)),
    ("pelvis/spine/head", (0, 1.78, 0)),
    ("pelvis/leftHip", (-0.13, 1.06, 0)),
    ("pelvis/leftHip/leftKnee", (-0.13, 0.56, 0)),
    ("pelvis/leftHip/leftKnee/leftAnkle", (-0.13, 0.08, 0)),
    ("pelvis/rightHip", (0.13, 1.06, 0)),
    ("pelvis/rightHip/rightKnee", (0.13, 0.56, 0)),
    ("pelvis/rightHip/rightKnee/rightAnkle", (0.13, 0.08, 0)),
    ("pelvis/spine/leftShoulder", (-0.23, 1.56, 0)),
    ("pelvis/spine/leftShoulder/leftElbow", (-0.5, 1.56, 0)),
    ("pelvis/spine/leftShoulder/leftElbow/leftWrist", (-0.75, 1.56, 0)),
    ("pelvis/spine/rightShoulder", (0.23, 1.56, 0)),
    ("pelvis/spine/rightShoulder/rightElbow", (0.5, 1.56, 0)),
    ("pelvis/spine/rightShoulder/rightElbow/rightWrist", (0.75, 1.56, 0)),
]
JOINT_INDEX = {name.rsplit("/", 1)[-1]: index for index, (name, _) in enumerate(JOINTS)}
MATERIALS = {
    "Costume": (0.58, 0.4, 0.83),
    "Leggings": (0.2, 0.22, 0.34),
    "Skin": (0.77, 0.53, 0.39),
    "Boots": (0.95, 0.95, 0.98),
    "Blades": (0.42, 0.45, 0.5),
    "Hair": (0.1, 0.09, 0.12),
}


def scalar(value):
    return f"{value:.8g}"


def vector(values):
    return "(" + ", ".join(scalar(value) for value in values) + ")"


def array(values):
    return "[" + ", ".join(values) + "]"


def translation_matrix(position):
    return "((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), " + vector((*position, 1)) + ")"


def influences(first, second, weight):
    return (JOINT_INDEX[first], JOINT_INDEX[second]), (1 - weight, weight)


def rigid(joint):
    return influences(joint, joint, 0)


class Mesh:
    def __init__(self, name):
        self.name = name
        self.points = []
        self.normals = []
        self.faces = []
        self.indices = []
        self.weights = []

    def vertex(self, point, normal, skin):
        self.points.append(point)
        self.normals.append(normal)
        self.indices.extend(skin[0])
        self.weights.extend(skin[1])
        return len(self.points) - 1

    def tube(self, rings, axis):
        first_vertex = len(self.points)
        for center, radius, skin in rings:
            for side in range(SIDES):
                angle = 2 * math.pi * side / SIDES
                normal = (math.cos(angle), 0, math.sin(angle))
                if axis == "x":
                    normal = (0, math.cos(angle), math.sin(angle))
                point = tuple(center[index] + radius * normal[index] for index in range(3))
                self.vertex(point, normal, skin)
        for ring in range(len(rings) - 1):
            for side in range(SIDES):
                lower = first_vertex + ring * SIDES + side
                next_lower = first_vertex + ring * SIDES + (side + 1) % SIDES
                upper = lower + SIDES
                next_upper = next_lower + SIDES
                self.faces.extend([(lower, upper, next_upper), (lower, next_upper, next_lower)])
        self.cap(first_vertex, rings[0], axis, -1)
        self.cap(first_vertex + (len(rings) - 1) * SIDES, rings[-1], axis, 1)

    def cap(self, offset, ring, axis, direction):
        center, _, skin = ring
        normal = (0, direction, 0) if axis == "y" else (direction, 0, 0)
        center_index = self.vertex(center, normal, skin)
        for side in range(SIDES):
            face = (center_index, offset + side, offset + (side + 1) % SIDES)
            self.faces.append(face if direction > 0 else tuple(reversed(face)))

    def ellipsoid(self, center, radii, joint):
        first_vertex = len(self.points)
        latitude_count = 8
        for latitude in range(latitude_count + 1):
            angle = math.pi * latitude / latitude_count
            for side in range(SIDES):
                longitude = 2 * math.pi * side / SIDES
                unit = (math.sin(angle) * math.cos(longitude), math.cos(angle), math.sin(angle) * math.sin(longitude))
                normal = tuple(unit[index] / radii[index] for index in range(3))
                length = math.sqrt(sum(value * value for value in normal))
                point = tuple(center[index] + unit[index] * radii[index] for index in range(3))
                self.vertex(point, tuple(value / length for value in normal), rigid(joint))
        for latitude in range(latitude_count):
            for side in range(SIDES):
                upper = first_vertex + latitude * SIDES + side
                next_upper = first_vertex + latitude * SIDES + (side + 1) % SIDES
                lower = upper + SIDES
                next_lower = next_upper + SIDES
                if latitude > 0:
                    self.faces.append((upper, lower, next_upper))
                if latitude < latitude_count - 1:
                    self.faces.append((next_upper, lower, next_lower))

    def usd(self):
        assert len(self.indices) == len(self.points) * 2
        assert len(self.weights) == len(self.points) * 2
        assert all(abs(sum(self.weights[index:index + 2]) - 1) < 1e-6 for index in range(0, len(self.weights), 2))
        minimum = tuple(min(point[axis] for point in self.points) for axis in range(3))
        maximum = tuple(max(point[axis] for point in self.points) for axis in range(3))
        faces = [self.outward(face) for face in self.faces]
        return f'''    def Mesh "{self.name}" (
        prepend apiSchemas = ["SkelBindingAPI", "MaterialBindingAPI"]
    ) {{
        rel skel:skeleton = </Skater/Skeleton>
        rel material:binding = </Skater/Materials/{self.name}>
        uniform token subdivisionScheme = "none"
        point3f[] extent = [{vector(minimum)}, {vector(maximum)}]
        point3f[] points = {array(map(vector, self.points))}
        normal3f[] normals = {array(map(vector, self.normals))} (interpolation = "vertex")
        int[] faceVertexCounts = {array("3" for _ in self.faces)}
        int[] faceVertexIndices = {array(str(index) for face in faces for index in face)}
        matrix4d primvars:skel:geomBindTransform = {translation_matrix((0, 0, 0))}
        int[] primvars:skel:jointIndices = {array(map(str, self.indices))} (
            interpolation = "vertex"
            elementSize = 2
        )
        float[] primvars:skel:jointWeights = {array(map(scalar, self.weights))} (
            interpolation = "vertex"
            elementSize = 2
        )
    }}'''

    def outward(self, face):
        origin, second, third = (self.points[index] for index in face)
        first_edge = tuple(second[axis] - origin[axis] for axis in range(3))
        second_edge = tuple(third[axis] - origin[axis] for axis in range(3))
        normal = (
            first_edge[1] * second_edge[2] - first_edge[2] * second_edge[1],
            first_edge[2] * second_edge[0] - first_edge[0] * second_edge[2],
            first_edge[0] * second_edge[1] - first_edge[1] * second_edge[0],
        )
        expected = tuple(sum(self.normals[index][axis] for index in face) for axis in range(3))
        return face if sum(normal[axis] * expected[axis] for axis in range(3)) > 0 else tuple(reversed(face))


def leg(mesh, side, direction):
    hip, knee, ankle = (f"{side}{joint}" for joint in ["Hip", "Knee", "Ankle"])
    rings = []
    for height, radius, weight in [(0.08, 0.05, 1), (0.16, 0.055, 0), (0.46, 0.063, 0), (0.52, 0.068, 0.2), (0.56, 0.07, 0.5), (0.60, 0.073, 0.8), (0.66, 0.077, 1), (1.06, 0.09, 1)]:
        skin = influences(knee, ankle, weight) if height <= 0.46 else influences(knee, hip, weight)
        rings.append(((direction * 0.13, height, 0), radius, skin))
    mesh.tube(rings, "y")


def arm(mesh, side, direction):
    shoulder, elbow, wrist = (f"{side}{joint}" for joint in ["Shoulder", "Elbow", "Wrist"])
    rings = []
    for distance, radius, weight in [(0.23, 0.065, 0), (0.43, 0.05, 0), (0.48, 0.048, 0.3), (0.50, 0.047, 0.5), (0.52, 0.046, 0.7), (0.57, 0.043, 1), (0.70, 0.035, 1), (0.75, 0.035, 1)]:
        skin = influences(shoulder, elbow, weight)
        if distance > 0.70:
            skin = rigid(wrist)
        rings.append(((direction * distance, 1.56, 0), radius, skin))
    mesh.tube(rings if direction > 0 else list(reversed(rings)), "x")
    mesh.ellipsoid((direction * 0.77, 1.56, 0), (0.065, 0.045, 0.045), wrist)


def material(name, color):
    return f'''        def Material "{name}" {{
            token outputs:surface.connect = </Skater/Materials/{name}/Surface.outputs:surface>
            def Shader "Surface" {{
                uniform token info:id = "UsdPreviewSurface"
                color3f inputs:diffuseColor = {vector(color)}
                float inputs:roughness = 0.7
                token outputs:surface
            }}
        }}'''


def main():
    meshes = {name: Mesh(name) for name in MATERIALS}
    meshes["Costume"].tube([
        ((0, 0.99, 0), 0.19, rigid("pelvis")),
        ((0, 1.13, 0), 0.17, influences("pelvis", "spine", 0.1)),
        ((0, 1.28, 0), 0.14, influences("pelvis", "spine", 0.45)),
        ((0, 1.43, 0), 0.19, influences("pelvis", "spine", 0.85)),
        ((0, 1.56, 0), 0.23, rigid("spine")),
    ], "y")
    for side, direction in [("left", -1), ("right", 1)]:
        leg(meshes["Leggings"], side, direction)
        arm(meshes["Skin"], side, direction)
        meshes["Boots"].ellipsoid((direction * 0.13, 0.08, 0.025), (0.075, 0.06, 0.16), f"{side}Ankle")
        meshes["Blades"].ellipsoid((direction * 0.13, 0.0125, 0.02), (0.0125, 0.0125, 0.18), f"{side}Ankle")
    meshes["Skin"].ellipsoid((0, 1.65, 0), (0.055, 0.09, 0.055), "spine")
    meshes["Skin"].ellipsoid((0, 1.78, 0), (0.15, 0.17, 0.14), "head")
    meshes["Hair"].ellipsoid((0, 1.86, -0.025), (0.145, 0.11, 0.13), "head")
    meshes["Hair"].ellipsoid((0, 1.86, -0.14), (0.075, 0.075, 0.075), "head")
    positions = dict(JOINTS)
    local_positions = [tuple(position[axis] - positions.get(name.rpartition("/")[0], (0, 0, 0))[axis] for axis in range(3)) for name, position in JOINTS]
    joint_names = array(f'"{name}"' for name, _ in JOINTS)
    source = f'''#usda 1.0
(
    defaultPrim = "Skater"
    metersPerUnit = 1
    upAxis = "Y"
)
def SkelRoot "Skater" {{
    def Skeleton "Skeleton" (
        prepend apiSchemas = ["SkelBindingAPI"]
    ) {{
        uniform token[] joints = {joint_names}
        matrix4d[] bindTransforms = {array(translation_matrix(position) for _, position in JOINTS)}
        matrix4d[] restTransforms = {array(map(translation_matrix, local_positions))}
        rel skel:animationSource = </Skater/Rest>
    }}
    def SkelAnimation "Rest" {{
        uniform token[] joints = {joint_names}
        float3[] translations = {array(map(vector, local_positions))}
        quatf[] rotations = {array("(1, 0, 0, 0)" for _ in JOINTS)}
        half3[] scales = {array("(1, 1, 1)" for _ in JOINTS)}
    }}
    def Scope "Materials" {{
{chr(10).join(material(name, color) for name, color in MATERIALS.items())}
    }}
{chr(10).join(mesh.usd() for mesh in meshes.values())}
}}
'''
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="myiceshow-rig-") as directory:
        stage = Path(directory) / "SkaterFixture.usda"
        stage.write_text(source)
        subprocess.run(["usdchecker", "--arkit", str(stage)], check=True)
        package = Path(directory) / "SkaterFixture.usdz"
        subprocess.run(["usdzip", "--arkitAsset", str(stage), str(package)], check=True)
        subprocess.run(["usdchecker", "--arkit", str(package)], check=True)
        OUTPUT.write_bytes(package.read_bytes())
    print(f"Generated {OUTPUT.relative_to(ROOT)}: {len(JOINTS)} joints, {sum(len(mesh.points) for mesh in meshes.values())} vertices, {sum(len(mesh.faces) for mesh in meshes.values())} triangles")


if __name__ == "__main__":
    main()
