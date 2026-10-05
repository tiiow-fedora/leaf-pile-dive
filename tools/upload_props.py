"""Upload blender/out/*.fbx as Model assets (skips ones already in tools/prop_ids.json)."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from upload_asset import upload
ROOT = pathlib.Path(__file__).resolve().parent.parent
IDS = ROOT / "tools" / "prop_ids.json"
ids = json.loads(IDS.read_text()) if IDS.exists() else {}
for f in sorted((ROOT / "blender" / "out").glob("*.fbx")):
    if f.stem in ids and "--force" not in sys.argv:
        continue
    aid, info = upload(str(f), "Model", f.stem, "model/fbx")
    print(f.stem, aid, info)
    if aid:
        ids[f.stem] = {"id": int(aid), "moderation": info}
    IDS.write_text(json.dumps(ids, indent=1))
