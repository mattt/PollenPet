"""Export the pinned Reachy Mini visualization rig to an articulated USDZ.

Run from the repository root after cloning the source into
.cache/reachy_mini_blender:

    blender --background .cache/reachy_mini_blender/reachy_mini_link/assets/reachy_mini.blend \
      --python Scripts/import_reachy_mini.py

The source model is by Clement Plays for Pollen Robotics. See ThirdParty.
"""

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

import bpy
from mathutils import Matrix
from pxr import Sdf, Usd, UsdGeom, UsdUtils


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".cache/reachy_mini_blender"
REVISION = "bfa02cfee9fde8a1bcca7159921110b1a4a2368e"
BLEND = SOURCE / "reachy_mini_link/assets/reachy_mini.blend"
OUTPUT = ROOT / "Resources/Models/reachy-mini"


def main():
    revision = subprocess.check_output(
        ["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True
    ).strip()
    if revision != REVISION:
        raise ValueError(f"Expected Reachy Mini source revision {REVISION}, got {revision}")
    if bpy.data.filepath != str(BLEND):
        raise ValueError(f"Open {BLEND} before running this script")

    # Match the source repository's glTF exporter: use each viewport color
    # where USD cannot represent a procedural material node chain.
    for material in bpy.data.materials:
        if material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            base_color = node.inputs["Base Color"]
            if base_color.is_linked:
                for link in list(base_color.links):
                    material.node_tree.links.remove(link)
                color = material.diffuse_color
                base_color.default_value = (color[0], color[1], color[2], 1)
            for name in ("Metallic", "Roughness"):
                value = node.inputs.get(name)
                if value and value.is_linked:
                    for link in list(value.links):
                        material.node_tree.links.remove(link)
                    value.default_value = getattr(material, name.lower())

    collection = bpy.data.collections["MiniReachyRetopo"]
    head_objects = set(bpy.data.collections["HEAD retopo"].all_objects)
    meshes = [obj for obj in collection.all_objects if obj.type == "MESH"]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    scene = bpy.data.scenes.new("PollenPetExport")
    body = bpy.data.objects.new("Body", None)
    head = bpy.data.objects.new("Head", None)
    scene.collection.objects.link(body)
    scene.collection.objects.link(head)
    head.location = (0, 0, 0.41)
    head_matrix = Matrix.Translation(head.location)

    for source in meshes:
        evaluated = source.evaluated_get(depsgraph)
        mesh = bpy.data.meshes.new_from_object(
            evaluated, preserve_all_data_layers=True, depsgraph=depsgraph
        )
        obj = bpy.data.objects.new(source.name, mesh)
        scene.collection.objects.link(obj)
        obj.parent = head if source in head_objects else body
        obj.matrix_basis = (
            head_matrix.inverted() if source in head_objects else Matrix.Identity(4)
        ) @ evaluated.matrix_world

    bpy.context.window.scene = scene
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        layer = Path(temporary) / "reachy-mini.usdc"
        bpy.ops.wm.usd_export(
            filepath=str(layer),
            export_animation=False,
            export_armatures=False,
            export_shapekeys=False,
            export_materials=True,
            export_mesh_colors=False,
            export_uvmaps=False,
            convert_orientation=False,
            generate_preview_surface=True,
            triangulate_meshes=True,
        )
        stage = Usd.Stage.Open(str(layer))
        root = UsdGeom.Xformable(stage.GetDefaultPrim())
        root.ClearXformOpOrder()
        # Blender's Z-up, +Y-forward model becomes Y-up, +Z-forward.
        root.AddRotateYOp(UsdGeom.XformOp.PrecisionFloat).Set(180)
        root.AddRotateXOp(UsdGeom.XformOp.PrecisionFloat).Set(-90)
        UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
        UsdGeom.SetStageMetersPerUnit(stage, 1)
        bounds = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ["default"])
        box = bounds.ComputeWorldBound(stage.GetDefaultPrim()).ComputeAlignedRange()
        framing = {"min": list(box.GetMin()), "max": list(box.GetMax())}
        (OUTPUT / "framing.json").write_text(json.dumps(framing, indent=2) + "\n")
        stage.GetRootLayer().Save()
        model = OUTPUT / "model.usdz"
        if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(layer)), str(model)):
            raise RuntimeError("USDZ export failed")

    manifest = {
        "repository": "https://github.com/pollen-robotics/reachy_mini_blender",
        "revision": REVISION,
        "sourceSHA256": hashlib.sha256(BLEND.read_bytes()).hexdigest(),
        "outputSHA256": hashlib.sha256(model.read_bytes()).hexdigest(),
        "license": "Apache-2.0",
        "author": "Clément Plays for Pollen Robotics",
        "changes": [
            "Evaluated the visualization rig in its rest pose and exported its meshes to USDZ.",
            "Grouped head meshes under a pivot at 0.41 m for local animation.",
            "Changed coordinates from Blender Z-up, +Y-forward to Y-up, +Z-forward.",
            "Replaced procedural material colors with the source viewport colors.",
            "Omitted procedural textures and an unresolved decorative image reference.",
        ],
    }
    (ROOT / "ThirdParty/reachy-mini-sources.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    print(f"Exported {model} ({len(meshes)} source meshes)")


if __name__ == "__main__":
    main()
