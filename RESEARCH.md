# RESEARCH (2026-10-04 22:50 MDT)

## Source
Roblox Charts, pulled from `apis.roblox.com/explore-api/v1/get-sorts` in the owner's logged-in Chrome (country=all, device=computer). The numbers are live player counts at the time I checked.

**Top Trending (top 40, condensed):** Huss Valley 66.8k, 99 Nights in the Forest 148k, DOORS, Dandy's World, Ball VS Ball, Sniper Arena, Volleyball Legends, Steal a Brainrot, Search For The Needle 16k, **[BOSS]+1 Loot To Forge 47k**, THRESHOLD, **Break and Steal an Egg 63k**, **Build the Pyramid! 13.8k**, 7 Days Cat-Sitting, Grapple Cart Obby, **+1 Stone Skipping 21k**, **Build An Ant Empire 21k**, **Paint to Get Rich 10.8k**, Rocket Rush, Guess The Real Size.

**Up-and-Coming (top 32):** Huss Valley, Break and Steal an Egg, 7 Days Cat-Sitting, +1 Stone Skipping, **Peel THE Potato 7.2k**, Steal Animal Egg 18k, Drill for Eggs 14.6k, Rocket Rush, Pet Store Tycoon, Steal ASMR, Fishing Master 11.7k, **Peel a Potato**, **+1 Wings For Eggs 13.4k**, Crack the Egg, Tower Incremental, **Melt All The Ice!**.

## Patterns
1. **One satisfying verb + numbers going up**: Peel the Potato (×2), Melt All The Ice, Paint to Get Rich, Drill for Eggs, Crack the Egg. They're simple, readable at a glance and fit a short session.
2. **"+1 X" incrementals** are still charting (+1 Stone Skipping, +1 Wings For Eggs, +1 Loot To Forge).
3. **Egg/steal games** are crowded (5+ near-identical titles in Up-and-Coming).
4. **Seasonal timing**: it's early October. Halloween/autumn themes appear in titles (Grand Piece "HALLOWEEN PT 1", Rake v10 🎃).

Search check (omni-search) for overlap:
- "rake leaves" / "leaf pile": **[TEAMS] Clean all the Leaves at 9.6k players**, so there's demand for an autumn leaf-cleaning loop. All other leaf games have 0–7 players (abandoned clones).
- "bubble wrap pop": several dead clones (0–439).
- "+1 bounce": small (≤188).

## Candidates (score 1–5 each; weights: fun ×3, buildability ×3, monetization ×2, difference ×2; max 50)
| Concept | Core loop | Fun | Build in one run | Monetization fit | Different from hits | Total |
|---|---|---|---|---|---|---|
| **A. Leaf Pile Dive**: rake autumn leaves, climb towers and dive into your pile; higher dive = bigger payout | rake → bag fills → climb → dive cash-in → upgrade rake/bag/tower | 5 | 4 | 4 | 4 | **43** |
| B. +1 Bounce trampoline climb: every bounce +1 height, reach sky islands | bounce → height → islands → upgrades | 3 | 4 | 4 | 2 (close to my own +1 Speed and the +1 Jump games) | 34 |
| C. Bubble Wrap Pop: giant sheets, pop for coins, chain reactions | pop → coins → bigger popper → new sheets | 4 | 3 (thousands of bubbles = part budget) | 3 | 3 | 34 |
| D. Kick the Pumpkin: kick-power distance launcher, Halloween | train power → kick → distance → coins | 4 | 3 (projectile physics tuning) | 4 | 3 (Kick-a-X games exist) | 35 |
| E. Guess the Real Size quiz | guess → score | 3 | 2 (content heavy, image rights) | 2 | 2 (it's on the charts already) | 23 |

## Winner: A, "Leaf Pile Dive"
- **Proven demand, empty field**: Clean all the Leaves has 9.6k players, every other leaf game is dead, and autumn is the current season.
- **Real twist**: the existing leaf game is team cleaning. Here, raking is only half the loop. **Diving cashes in your bag, and the height you dive from multiplies the payout.** That gives a vertical "climb higher" goal on top of the satisfying collect verb, and a big visible, audible moment (leaf explosion + bounce) every 30–60 s.
- **Fits a solo build**: leaves are cheap flat non-colliding parts; yards, towers, fences and the landmark are generated from Config the same way as the reference game. Collection is validated on the server by distance, so there's no physics risk.
- **Monetization fits the genre** (fixed results only): 2x Leaves, Big Bag, VIP, Auto-Rake; products for an instant bag fill and acorn packs.
- **Original**: own name, own art (Blender + synthesized audio), no copied mechanics beyond the generic collect/sell/upgrade simulator loop.
