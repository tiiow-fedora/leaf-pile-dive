"""Create the game passes and developer products through Open Cloud (idempotent:
skips names that already exist), upload their icons, and write the IDs to
tools/monetization_ids.json. Prices/descriptions come from DESIGN.md.
Never prints the API key."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rbx import req, multipart, U

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICONS = ROOT / "assets" / "icons"
OUT = ROOT / "tools" / "monetization_ids.json"

PASSES = {
    "Leaves2x": ("2x Leaves", 199, "Every leaf you rake is worth 2x, forever."),
    "BigBag": ("Big Bag", 149, "Your bag holds 2x as many leaves, forever."),
    "AutoRake": ("Auto Rake", 129, "Your rake swings by itself while you walk in a yard (toggle with the AUTO button)."),
    "VIP": ("VIP", 99, "1.25x Acorns from every dive, a gold leaf trail and a [VIP] chat tag."),
}
PRODUCTS = {
    "FillBag": ("Fill My Bag", 15, "Your bag is filled to the top right away. Then dive into the pile to cash it in."),
    "Potion2x": ("2x Acorns (10 min)", 39, "2x Acorns from dives for 10 minutes. Buying more adds time."),
    "AcornCrate": ("Acorn Crate", 49, "Acorns equal to 5 full bags at your current bag size (at least 500)."),
    "UnlockYard": ("Unlock Next Yard", 79, "Opens your next locked yard right away. If every yard is open, you get an Acorn Crate instead."),
}

def existing(kind):
    path = (f"/game-passes/v1/universes/{U}/game-passes/creator?pageSize=100" if kind == "pass"
            else f"/developer-products/v2/universes/{U}/developer-products/creator?pageSize=100")
    s, t = req("GET", path)
    j = json.loads(t)
    items = j.get("gamePasses") or j.get("developerProducts") or []
    return {i["name"]: i for i in items}

def create(kind, key, name, price, desc):
    fields = {"name": name, "description": desc, "price": str(price), "isForSale": "true"}
    files = {"imageFile": (f"{key}.png", "image/png", (ICONS / f"{key}.png").read_bytes())}
    body, h = multipart(fields, files)
    path = (f"/game-passes/v1/universes/{U}/game-passes" if kind == "pass"
            else f"/developer-products/v2/universes/{U}/developer-products")
    s, t = req("POST", path, body, h)
    print(kind, key, s, t[:300])
    return json.loads(t) if s in (200, 201) else None

out = json.loads(OUT.read_text()) if OUT.exists() else {"passes": {}, "products": {}}
have = existing("pass")
for key, (name, price, desc) in PASSES.items():
    out["passes"][key] = have.get(name) or create("pass", key, name, price, desc)
have = existing("product")
for key, (name, price, desc) in PRODUCTS.items():
    out["products"][key] = have.get(name) or create("product", key, name, price, desc)
OUT.write_text(json.dumps(out, indent=1))
for k, v in out["passes"].items():
    print("PASS", k, v and v.get("gamePassId"))
for k, v in out["products"].items():
    print("PRODUCT", k, v and v.get("productId"))
