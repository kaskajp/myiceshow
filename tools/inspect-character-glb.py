import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


COMPONENTS = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    raw = path.read_bytes()
    if len(raw) < 20 or struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
        raise ValueError("Expected a GLB 2.0 file with a valid length")
    chunks = []
    offset = 12
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        end = offset + 8 + length
        if length % 4 or end > len(raw):
            raise ValueError("Invalid GLB chunk length")
        chunks.append((kind, raw[offset + 8:end]))
        offset = end
    if [kind for kind, _ in chunks] != [0x4E4F534A, 0x004E4942]:
        raise ValueError("This inspector requires one JSON and one BIN chunk")
    document = json.loads(chunks[0][1])
    if len(document["buffers"]) != 1 or "uri" in document["buffers"][0]:
        raise ValueError("This inspector requires a single embedded buffer")
    if document["buffers"][0]["byteLength"] > len(chunks[1][1]):
        raise ValueError("Embedded buffer is shorter than declared")
    return document, chunks[1][1]


def accessor_values(document, binary, index):
    accessor = document["accessors"][index]
    if "sparse" in accessor or accessor.get("normalized", False):
        raise ValueError("Sparse and normalized accessors are not supported")
    view = document["bufferViews"][accessor["bufferView"]]
    if view["buffer"] != 0:
        raise ValueError("Accessor references a non-embedded buffer")
    decoder = struct.Struct("<" + COMPONENTS[accessor["componentType"]] * WIDTHS[accessor["type"]])
    stride = view.get("byteStride", decoder.size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    view_end = view.get("byteOffset", 0) + view["byteLength"]
    end = start + max(0, accessor["count"] - 1) * stride + decoder.size
    if stride < decoder.size or end > view_end or view_end > len(binary):
        raise ValueError("Accessor extends beyond its buffer view")
    return [decoder.unpack_from(binary, start + row * stride) for row in range(accessor["count"])]


def inspect(document, binary):
    nodes = document["nodes"]
    meshes = []
    for node in nodes:
        if "skin" not in node:
            continue
        skin = document["skins"][node["skin"]]
        for primitive in document["meshes"][node["mesh"]]["primitives"]:
            attributes = primitive["attributes"]
            weights = accessor_values(document, binary, attributes["WEIGHTS_0"])
            joints = accessor_values(document, binary, attributes["JOINTS_0"])
            if len(weights) != len(joints):
                raise ValueError("Joint and weight accessor counts differ")
            if len(weights) != document["accessors"][attributes["POSITION"]]["count"]:
                raise ValueError("Skin and position accessor counts differ")
            if any(not math.isfinite(weight) or weight < 0 for row in weights for weight in row):
                raise ValueError("Skin contains non-finite or negative weights")
            if any(joint >= len(skin["joints"]) for row in joints for joint in row):
                raise ValueError("Skin references a joint outside its palette")
            index_count = document["accessors"][primitive["indices"]]["count"]
            if primitive.get("mode", 4) != 4 or index_count % 3:
                raise ValueError("This inspector requires indexed triangles")
            meshes.append({
                "node": node["name"],
                "vertices": len(weights),
                "triangles": index_count // 3,
                "max_weight_sum_error": max(abs(sum(row) - 1) for row in weights),
                "weighted_joints": sorted({
                    nodes[skin["joints"][joint]]["name"]
                    for joint_row, weight_row in zip(joints, weights)
                    for joint, weight in zip(joint_row, weight_row) if weight > 0
                }),
            })
    animations = []
    for animation in document.get("animations", []):
        times = [
            value[0] for sampler in animation["samplers"]
            for value in accessor_values(document, binary, sampler["input"])
        ]
        root_ranges = {}
        for channel in animation["channels"]:
            target = channel["target"]
            if nodes[target["node"]].get("name") != "root" or target["path"] != "translation":
                continue
            sampler = animation["samplers"][channel["sampler"]]
            values = accessor_values(document, binary, sampler["output"])
            root_ranges["translation_min"] = [min(row[axis] for row in values) for axis in range(3)]
            root_ranges["translation_max"] = [max(row[axis] for row in values) for axis in range(3)]
        animations.append({
            "name": animation["name"], "start": min(times), "end": max(times),
            "channels": len(animation["channels"]), "root": root_ranges,
        })
    return {
        "asset": document["asset"],
        "skins": [[nodes[index]["name"] for index in skin["joints"]] for skin in document["skins"]],
        "skinned_meshes": meshes,
        "unskinned_meshes": [node["name"] for node in nodes if "mesh" in node and "skin" not in node],
        "materials": [material.get("name") for material in document.get("materials", [])],
        "images": document.get("images", []),
        "animations": animations,
    }


def main():
    parser = argparse.ArgumentParser(description="Inspect uncompressed, embedded-buffer character GLBs without dependencies.")
    parser.add_argument("source", type=Path)
    parser.add_argument("--animation", help="Keep only this animation in a temporary study GLB")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    if bool(arguments.animation) != bool(arguments.output):
        parser.error("--animation and --output must be supplied together")
    if arguments.output and arguments.output.resolve() == arguments.source.resolve():
        parser.error("The study output must not overwrite the source")
    document, binary = read_glb(arguments.source)
    report = inspect(document, binary)
    report["source_sha256"] = hashlib.sha256(arguments.source.read_bytes()).hexdigest()
    if arguments.animation:
        selected = [animation for animation in document["animations"] if animation["name"] == arguments.animation]
        if len(selected) != 1:
            parser.error("Expected exactly one animation with the selected name")
        document["animations"] = selected
        encoded = json.dumps(document, separators=(",", ":")).encode()
        encoded += b" " * (-len(encoded) % 4)
        payload = struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
        payload += struct.pack("<II", len(binary), 0x004E4942) + binary
        with arguments.output.open("xb") as output:
            output.write(struct.pack("<4sII", b"glTF", 2, len(payload) + 12) + payload)
        report["study_animation"] = arguments.animation
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
