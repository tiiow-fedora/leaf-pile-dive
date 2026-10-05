# TESTING

All Studio tests ran against the real place (universe 10769447171) with code synced by Rojo, 2026-10-04 23:05 → 2026-10-05. Studio Output is also written to `%LOCALAPPDATA%\Roblox\logs\*_Studio_*_last.log`; the lines quoted here come from those logs (copies in `tests/`).

**DevTest** (`src/server/DevTest.luau`) runs inside the live server through a Studio-only BindableFunction: `game.ServerScriptService.DevRun:Invoke()`. Requiring the module from the command bar gives a separate module cache with no players, so that route doesn't work. It drives player 1 through raking (radius, regrow, height limit, full bag, locked yard), golden leaves, **real falls into the pile** (ground ×1, 20 studs ≈ ×1.8, the cap from 150 studs, empty bag), shop tiers (poor/skip/bad args), yards, New Season, daily reward (day 1, double claim, day 7 potion, streak reset), quests, every product handler, **ProcessReceipt twice with the same PurchaseId for all 4 products**, a **forced save failure** (rollback + NotProcessedYet), save migration v0→v1, weekly events, anti-cheat and falling. It then restores the player's original data.

## Checklist (release v2)
- [x] **DevTest 64/64**: Play solo 23:21 and 23:49; 2-client local server 23:54 (`tests/devtest_2client.log`).
- [x] **Core loop by hand** (23:11): raked with clicks/E (bag 0→50/80, golden leaf toast), climbed the ladder, walked off the diving board into the pile → "x1.8 DIVE! +45" (20 leaves × 1.8 × 1.25 VIP, as calculated). Live v9 (23:31): raked to 50/80 + golden leaf, walk-in dive 107 → 184 Acorns.
- [x] **Saving** (23:50): `SAVETEST BEFORE 23:50:06 12529 80 1 1 1 3 20` → Stop (BindToClose) → Play → `SAVETEST AFTER 23:50:41 12529 80 1 1 1 3 20 true` (Acorns, Bag, BagTier, Rake, Yards, Dives, BestDive identical; DataSaving=true).
- [x] **Multiplayer** (23:54, Server + 2 clients): both load independent profiles; DevTest drove Player1 through every system while Player2's Acorns/Bag/tiers/yards/dives/quests stayed identical (`MP` vs `MP2` lines). Leaves are per player by design (server state per player, client renders its own).
- [x] **Fresh player**: the local-server test accounts start at 0 Acorns, bag 0/40, hint "Click to rake leaves!" (screens in `tests/screens/`).
- [x] **Layouts**: iPhone 7 667×375 (`tests/screens/phone_iphone7_667x375.png`, `phone_iphone7_shop.png`), iPad 6th gen 1024×768 (`tablet_ipad6_1024x768.png`), desktop. Bugs found and fixed: the RAKE button overlapped the touch jump button (the simulator reports a keyboard, so touch layout now keys off TouchEnabled); the Shop title ran under its tabs; on desktop the new chat window (with tabs) covers the top 37% of the left side, so the left column starts at 42%.
- [x] **Clean session**: 23:55 → 00:06 (11 min), server + 2 clients, 0 errors / 0 warnings (`tests/clean_session.md`).

## Bugs found by testing (all fixed)
| Found | Bug | Fix |
|---|---|---|
| playtest | Ladder under the deck overhang trapped the climber's head | Ladder outside the deck edge |
| playtest | E (rake) also triggered the gate unlock prompt | Prompt key F |
| playtest | World signs covered the HUD | Smaller billboards, shorter MaxDistance |
| live v9 | Desktop: chat window hid SHOP/STORE | Left column at 42% height |
| live v9 | First leaves 9–11 studs from the spawn, out of rake reach | Guaranteed row placed 4–6 studs ahead |
| Studio | First player spawned on the back fence when props took time to load (no SpawnLocation yet) | Respawn existing characters after the map is built |
| Studio | Camera sometimes started facing the character | Client holds the framing for 2.5 s after spawn, only turns the character once it's on a spawn point |
| Studio | "DataStore request was added to queue" on shutdown (PlayerRemoving and BindToClose both saving) | `releasing` set before any yield; BindToClose skips players already leaving |

## Remote audit
| Remote | Client sends | Server validation | Rate limit |
|---|---|---|---|
| Rake | nothing | server HRP position: inside an unlocked yard, ≤ 13 studs above ground, bag not full; leaves taken only within rake radius + 1.5 of the server position, only if not already taken (per-player regrow timers) | 3/s, burst 4 |
| BuyRake | tier | integer, == owned + 1, Acorns ≥ Config cost | 3/s |
| BuyBag | tier | integer, == owned + 1, Acorns ≥ Config cost | 3/s |
| UnlockYard (+ gate ProximityPrompt) | yard | integer, == unlocked + 1, Acorns ≥ Config cost | 2/s |
| NewSeason | nothing | all yards + top rake + Acorns ≥ SeasonCost | 1/s |
| ClaimDaily | nothing | server clock ≥ 20 h since last claim | 1/s |
| ClaimQuest | index | integer 1..3, quest complete and unclaimed (progress only from server events) | 2/s |
| TutorialDone | nothing | sets a cosmetic flag | 1/s |
| Notify / LeafSync | server → client only | n/a | n/a |

Currency and progress never come from the client. **Dives** are detected by the server (10 Hz): HRP inside the pile radius and low, height = peak HRP Y over the last 6 s, **capped at the yard's tower + 10**, so flying or flinging can't pay more than the best legit dive. **Movement check**: 1-second windows, horizontal > 2×WalkSpeed+40 studs/s or upward > 70 studs/s → rubber-banded (DevTest: a 90-stud server-side jump is pulled back; a live raw PivotTo was caught: `[AntiCheat] tiiow moved 79 studs (up -1) in 1.1s; rubber-banded`). **Locked yards**: entering one teleports you back in front of its gate. Gates are solid on the server and only made passable locally for owners.
