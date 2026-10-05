# /// script
# requires-python = ">=3.11"
# dependencies = ["usd-core==25.11"]
# ///
"""Convert the pinned Microduck MJCF/STL assembly to an articulated USDZ.

Run with `uv run Scripts/import_microduck.py` from any directory.
The hardware assets carry upstream's noncommercial license; see ThirdParty.
"""

import hashlib
import json
import os
import struct
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils, Vt

ROOT = Path(__file__).resolve().parents[1]
REVISION = "1e79c29c97d8b38aee9eefde77a545860ba7658e"
BASE = f"https://raw.githubusercontent.com/pollen-robotics/microduck_rl/{REVISION}/"
MODEL_PATH = "src/mjlab_microduck/robot/microduck/"
CACHE = ROOT / ".cache/microduck-source" / REVISION
OUTPUT = ROOT / "Resources/Models/microduck"
# Center of the jaw bearing, in the head_roll frame (X up, Y across the head).
MOUTH_PIVOT = Gf.Vec3d(0.0032, 0, -0.018)


def fetch(path):
    target = CACHE / path
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(BASE + path, timeout=60) as response:
            target.write_bytes(response.read())
    return target


def numbers(value):
    return [float(v) for v in value.split()]


def transform(node, element, origin=None):
    if origin is None:
        origin = Gf.Vec3d(0)
    node.AddTranslateOp().Set(Gf.Vec3d(*numbers(element.get("pos", "0 0 0"))) - origin)
    w, x, y, z = numbers(element.get("quat", "1 0 0 0"))
    node.AddOrientOp(UsdGeom.XformOp.PrecisionDouble).Set(
        Gf.Quatd(w, Gf.Vec3d(x, y, z)).GetNormalized()
    )


def read_stl(path):
    data = path.read_bytes()
    count = struct.unpack_from("<I", data, 80)[0]
    if len(data) != 84 + count * 50:
        raise ValueError(f"Expected binary STL: {path}")
    points, normals = [], []
    for i in range(count):
        values = struct.unpack_from("<12fH", data, 84 + i * 50)
        normals.append(Gf.Vec3f(*values[:3]))
        points.extend(Gf.Vec3f(*values[j : j + 3]) for j in (3, 6, 9))
    return points, normals


def main():
    robot = ET.parse(fetch(MODEL_PATH + "robot_allcollisions.xml")).getroot()
    scene = ET.parse(fetch(MODEL_PATH + "scene.xml")).getroot()
    assets = robot.find("asset")
    files = sorted(
        {MODEL_PATH + "assets/" + mesh.get("file") for mesh in assets.findall("mesh")}
    )
    files += [
        MODEL_PATH + "robot_allcollisions.xml",
        MODEL_PATH + "scene.xml",
        "README.md",
        "LICENSE",
    ]
    with ThreadPoolExecutor(max_workers=8) as executor:
        list(executor.map(fetch, files))
    joints = robot.findall(".//worldbody//joint")
    stand = numbers(scene.find(".//key[@name='STAND']").get("qpos"))[7:]
    if len(joints) != len(stand):
        raise ValueError("Standing pose does not match the joint count")
    home = dict(zip((joint.get("name") for joint in joints), stand))
    geometry = {
        Path(mesh.get("file")).stem: read_stl(
            fetch(MODEL_PATH + "assets/" + mesh.get("file"))
        )
        for mesh in assets.findall("mesh")
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        layer = Path(temporary) / "microduck.usdc"
        stage = Usd.Stage.CreateNew(str(layer))
        UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
        UsdGeom.SetStageMetersPerUnit(stage, 1)
        root = UsdGeom.Xform.Define(stage, "/Microduck")
        stage.SetDefaultPrim(root.GetPrim())
        # MuJoCo: X forward, Z up. RealityKit: Z forward, Y up.
        root.AddOrientOp(UsdGeom.XformOp.PrecisionDouble).Set(
            Gf.Rotation(Gf.Vec3d(1, 1, 1), -120).GetQuat()
        )
        materials = {}
        for source in assets.findall("material"):
            name = source.get("name")
            material = UsdShade.Material.Define(stage, f"/Microduck/Materials/{name}")
            shader = UsdShade.Shader.Define(
                stage, material.GetPath().AppendChild("Surface")
            )
            shader.CreateIdAttr("UsdPreviewSurface")
            color = numbers(source.get("rgba"))[:3]
            # Treat CAD swatches as sRGB; USD surface inputs are linear.
            color = [
                v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                for v in color
            ]
            shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(
                Gf.Vec3f(*color)
            )
            shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(0.48)
            shader.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(0)
            material.CreateSurfaceOutput().ConnectToSource(
                shader.ConnectableAPI(), "surface"
            )
            materials[name] = material

        def body(source, parent):
            joint = source.find("joint")
            node = UsdGeom.Xform.Define(
                stage, parent.AppendChild("body_" + source.get("name"))
            )
            transform(node, source)
            parent = node.GetPath()
            if joint is not None:
                if joint.get("axis") != "0 0 1" or joint.get("pos", "0 0 0") != "0 0 0":
                    raise ValueError("Unexpected joint axis or pivot")
                pivot = UsdGeom.Xform.Define(
                    stage, parent.AppendChild(joint.get("name"))
                )
                pivot.AddOrientOp(UsdGeom.XformOp.PrecisionDouble).Set(
                    Gf.Rotation(
                        Gf.Vec3d(0, 0, 1),
                        home[joint.get("name")] * 180 / 3.141592653589793,
                    ).GetQuat()
                )
                parent = pivot.GetPath()
            mouth = None
            if source.get("name") == "jaw_soft":
                # The source fixes the jaw to the head. Add a visual hinge around
                # its bearing and retain both lower-jaw parts in their rest pose.
                mouth = UsdGeom.Xform.Define(stage, parent.AppendChild("mouth_hinge"))
                mouth.AddTranslateOp().Set(MOUTH_PIVOT)
                mouth.AddOrientOp(UsdGeom.XformOp.PrecisionDouble).Set(Gf.Quatd(1))
            for index, geom in enumerate(source.findall("geom")):
                if geom.get("class") != "visual":
                    continue
                name = geom.get("mesh")
                lower_jaw = mouth is not None and name in {"jaw", "jaw_soft"}
                mesh_parent = mouth.GetPath() if lower_jaw else parent
                mesh = UsdGeom.Mesh.Define(
                    stage, mesh_parent.AppendChild(f"{name}_{index}")
                )
                transform(mesh, geom, MOUTH_PIVOT if lower_jaw else Gf.Vec3d(0))
                points, normals = geometry[name]
                mesh.CreatePointsAttr(Vt.Vec3fArray(points))
                mesh.CreateFaceVertexCountsAttr([3] * len(normals))
                mesh.CreateFaceVertexIndicesAttr(list(range(len(points))))
                mesh.CreateNormalsAttr(Vt.Vec3fArray(normals))
                mesh.SetNormalsInterpolation(UsdGeom.Tokens.uniform)
                mesh.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
                mesh.CreateExtentAttr(UsdGeom.PointBased.ComputeExtent(points))
                UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(
                    materials[geom.get("material")]
                )
            for child in source.findall("body"):
                body(child, parent)

        body(robot.find("worldbody/body"), root.GetPath())
        bounds = (
            UsdGeom.BBoxCache(Usd.TimeCode.Default(), ["default"])
            .ComputeWorldBound(root.GetPrim())
            .ComputeAlignedRange()
        )
        framing = {"min": list(bounds.GetMin()), "max": list(bounds.GetMax())}
        (OUTPUT / "framing.json").write_text(json.dumps(framing, indent=2) + "\n")
        stage.GetRootLayer().Save()
        # The package stores the layer's modification time. Fix it so that
        # repeated imports produce the same bytes and output hash.
        os.utime(layer, (946684800, 946684800))
        if not UsdUtils.CreateNewUsdzPackage(
            Sdf.AssetPath(str(layer)), str(OUTPUT / "model.usdz")
        ):
            raise RuntimeError("USDZ export failed")

    manifest = {
        "repository": "https://github.com/pollen-robotics/microduck_rl",
        "revision": REVISION,
        "hardwareLicense": "Creative Commons BY-SA-NC (version not specified upstream)",
        "softwareLicense": "Apache-2.0",
        "changes": [
            "Converted visual STL meshes and MJCF body hierarchy to USDZ.",
            "Applied the upstream STAND pose and changed coordinates to Y-up.",
            "Added a visual mouth hinge at the jaw bearing for the jaw and lower mouth pad; preserved their closed positions.",
            "Omitted physics, collision meshes, sensors, and controllers.",
            "Interpreted CAD colors as sRGB and converted them to linear USD colors; set roughness to 0.48.",
        ],
        "sources": [
            {
                "path": path,
                "sha256": hashlib.sha256(fetch(path).read_bytes()).hexdigest(),
            }
            for path in files
        ],
        "outputSHA256": hashlib.sha256(
            (OUTPUT / "model.usdz").read_bytes()
        ).hexdigest(),
    }
    (ROOT / "ThirdParty/microduck-sources.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    (ROOT / "ThirdParty/microduck-LICENSE.txt").write_bytes(
        fetch("LICENSE").read_bytes()
    )
    print(f"Exported {OUTPUT / 'model.usdz'} ({len(joints)} articulated joints)")


if __name__ == "__main__":
    main()
