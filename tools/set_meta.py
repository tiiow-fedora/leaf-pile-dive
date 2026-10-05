"""Set the experience name, description, visibility and server size via Open Cloud."""
import json, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from rbx import req, U, P
NAME = "Leaf Pile Dive 🍂"
DESC = ("Rake autumn leaves, climb the tower and DIVE into the giant leaf pile! The higher you jump from, the more Acorns you earn. 🍂\n\n"
        "• Upgrade your rake (bigger reach) and your bag (holds more)\n"
        "• Unlock 6 yards: Backyard, Park, Orchard, Pumpkin Patch, Maple Woods and the Giant Oak, each with a taller tower\n"
        "• Find golden leaves worth 10x\n"
        "• Start a New Season for a permanent leaf bonus\n"
        "• Daily rewards, 3 daily quests, a new event every week, and +10% leaves for each friend in your server (up to +30%)\n\n"
        "Controls: click / tap RAKE (or press E) to rake. Walk into the pile to cash in your bag.")
vis = sys.argv[1] if len(sys.argv) > 1 else "PUBLIC"
s, t = req("PATCH", f"/cloud/v2/universes/{U}?updateMask=displayName,description,visibility",
           {"displayName": NAME, "description": DESC, "visibility": vis})
print("universe", s, t[:400])
s, t = req("PATCH", f"/cloud/v2/universes/{U}/places/{P}?updateMask=displayName,description,serverSize",
           {"displayName": NAME, "description": DESC, "serverSize": 20})
print("place", s, t[:400])
