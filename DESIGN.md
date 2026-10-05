# DESIGN: "Leaf Pile Dive 🍂"

## Pitch
Rake autumn leaves into your bag, climb the tower and **dive into the giant leaf pile**. The higher you dive from, the more Acorns you get. Spend Acorns on bigger rakes, bigger bags and new yards, up to the Giant Oak.

## Core loop (minute to minute)
1. **Rake** (click / tap / RAKE button / E). Each swing collects every leaf within your rake's radius. Leaves fly into you with a pop and a "+N" number, and the bag bar fills. Leaves are per player (no stealing), are validated by the server and regrow after 7 s.
2. **Bag full** ("Bag full! Dive in the pile!"). Walk to the yard's big leaf pile, or climb the yard's tower first.
3. **Dive**: landing in the pile cashes the bag in as Acorns × the **height multiplier** (1 + height/25). Ground level is ×1, the Backyard tower top (20 studs) is ×1.8, the Giant Oak tower top (90 studs) is ×4.6. The landing is a leaf explosion, a boom and a bounce, plus a "×2.6 DIVE! +1,234 🌰" popup.
4. **Upgrade** in the SHOP: Rakes (radius + leaf multiplier), Bags (capacity), Yards (more valuable leaves and taller towers).
5. **Golden leaves** (4%, 10× value, sparkle + bling) are instant progress pickups and appear in every yard.
6. **New Season** (rebirth): needs all 6 yards + the Storm Rake + 20M Acorns (doubles each season). It resets Acorns, rake and bag (yards are kept) and gives a permanent +50% leaf value.

## Progression math (from `tools/balance_sim.py`, free player)
- Leaf value = yard value × rake mult × (1 + 0.5 × seasons) × passes/potions/events/friends.
- Dive mult = 1 + min(height, yardTower + 10) / 25; height = peak Y in the last 6 s − pile top.
- Yards: Backyard (1, free, tower 20), Park (3, 1.5K, 30), Orchard (8, 20K, 40), Pumpkin Patch (20, 144K, 55), Maple Woods (50, 960K, 70), Giant Oak (120, 6M, 90).
- Rakes (cost, radius, mult): Old 0/7/1, Garden 600/8.5/2, Wide 4.8K/10/4, Steel 32K/11.5/8, Golden 200K/13/16, Maple 1.2M/14.5/32, Storm 7.2M/16/64.
- Bags (cost, cap): Paper 0/40, Sack 150/150, Wheelbarrow 3.6K/600, Leaf Cart 24K/2.5K, Trailer 160K/12K, Leaf Silo 1.04M/60K, Mega Silo 6.4M/300K.
- Sim milestones (free): first bag ~10 s, Sack ~1 min, Garden Rake ~3.5 min, **Park ~5 min**, Orchard ~15 min, Pumpkin ~28 min, Maple ~46 min, **Giant Oak ~70 min**, **first Season ~90 min**, Season 2 ~2.5 h. With 2x Leaves: Park ~4 min, Giant Oak ~60 min. Paying speeds things up but is never required.

## Session length targets
- First session: 8–15 min (Park + Orchard).
- Typical session: 15–25 min (one yard or a couple of upgrades).
- Full first season: ~1.5 h across 4–6 sessions.

## First 60 seconds (second by second)
- 0 s: spawn in the Backyard facing the pile, with the tower beside it and the Giant Oak glowing orange in the distance. Hint: **"Click to rake leaves!"** (touch: **"Tap RAKE to rake leaves!"**). The rake is already in hand. Next goal: "Next: Fill your bag".
- 1–8 s: every swing sucks in leaves with a pop and a "+1". The bag bar fills. One golden leaf is guaranteed near spawn (+10, bling).
- ~8 s: bag full (40). Hint **"Bag full! Dive in the pile!"**. The pile pulses and a ⬇ marker floats over it.
- ~12 s: walk-in dive: leaf explosion, boom, bounce, "+40 🌰". Hint: **"Climb the tower: higher = more!"**. The marker moves to the tower stairs.
- ~25 s: second bag; climb (~6 s) and dive from 20 studs: "×1.8 DIVE! +72 🌰". Next goal: "Next: Sack (150 🌰)".
- ~50–60 s: SHOP pulses; buy the Sack (bigger bag) and see the bag bar max jump. Welcome gift toast: "Welcome! 2x Acorns for 3 minutes".

## Systems (build order)
1. `Config`: yards, rakes, bags, leaf spots (seeded), passes/products, quests, events.
2. `MapBuilder`: yards, ground, fences + gates, piles, towers (stairs + platform + diving board), trees, decor, landmark Giant Oak, spawn. Deterministic, rebuilt every server start.
3. `Gameplay`: rake validation, leaf state per player, dive detection (zone + peak height), yard access validation, anti-cheat movement check, friend boost, welcome gift.
4. `DataService`: DataStore with pcall + retries + UpdateAsync + session lock + 60 s autosave + PlayerRemoving + BindToClose; versioned save (`Version`) with migration.
5. Client: leaves rendering (local parts), rake tool + swing, dive FX, HUD (acorns, bag bar, next goal, hints), shop, store, quests, daily, season; layouts for phone, tablet and desktop.
6. Monetization (Open Cloud created): passes + products, ProcessReceipt dedupe.
7. Retention: daily streak, 3 daily quests, yard progress strip, friend boost + invite, boards (Total Acorns, Highest Dive), weekly events, welcome gift.
8. Look: Blender props (leaf, pile, oak, pumpkin, rake), particles, warm-on-cool palette.
9. Audio: synthesized SFX + music.

## Monetization (no paid randomness, fixed stated results)
| Game pass | Price | Benefit |
|---|---|---|
| 2x Leaves | 199 R$ | Every leaf is worth 2x, forever |
| Big Bag | 149 R$ | Bag capacity x2, forever |
| Auto Rake | 129 R$ | Rake swings automatically while you walk in a yard (toggle) |
| VIP | 99 R$ | 1.25x Acorns from dives, gold leaf trail, [VIP] chat tag |

| Developer product | Price | Grant |
|---|---|---|
| Fill My Bag | 15 R$ | Bag filled to capacity with your current yard's leaves (counted at your rake's value) |
| 2x Acorns (10 min) | 39 R$ | Acorns from dives x2 for 10 min (more add time) |
| Acorn Crate | 49 R$ | + Acorns equal to 5 full bags at your current yard, ground-dive value (min 500) |
| Unlock Next Yard | 79 R$ | Unlocks the next locked yard (if all are unlocked: an Acorn Crate instead) |

## Name, description
- Name: **Leaf Pile Dive 🍂**
- Description (only features that exist): "Rake autumn leaves, climb the tower and DIVE into the giant leaf pile! The higher you jump from, the more Acorns you earn. 🍂 Upgrade your rake and bag, unlock 6 yards up to the Giant Oak, find golden leaves, and start a New Season for a permanent bonus. Daily rewards, daily quests, weekly events and a friend boost."

## Cut list (cut in this order)
1. VIP chat tag
2. Highest Dive board (keep Total Acorns board)
3. Blender props (primitives instead)
4. Music (keep SFX)
5. Auto Rake pass
6. Weekly events
7. Friend boost (keep the invite button)

Never cut: core loop, saving, correct purchase handling, onboarding, mobile UI.
