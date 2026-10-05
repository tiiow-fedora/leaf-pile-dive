"""Upload audio/out/*.wav as Audio assets (skips ones already in tools/audio_ids.json)."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from upload_asset import upload
ROOT = pathlib.Path(__file__).resolve().parent.parent
IDS = ROOT / "tools" / "audio_ids.json"
ids = json.loads(IDS.read_text()) if IDS.exists() else {}
for f in sorted((ROOT / "audio" / "out").glob("*.wav")):
    if f.stem in ids:
        continue
    aid, info = upload(str(f), "Audio", "LeafPileDive_" + f.stem, "audio/wav")
    print(f.stem, aid, info)
    if aid:
        ids[f.stem] = {"id": int(aid), "moderation": info}
    IDS.write_text(json.dumps(ids, indent=1))
