# STATUS

Run start: 2026-10-04 22:45 MDT (05 Oct 04:45 UTC). Hour 6 = 04:45 MDT, hour 7.5 = 06:15 MDT.

## Tools (checked 22:47)
| Tool | Version |
|---|---|
| Rojo | 7.6.1 |
| Roblox Studio | version-76e1a02649ad4f35 |
| Roblox Player | version-02c37bc51a384b8f |
| Blender | 5.1.2 (`C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`) |
| Python | 3.13.7 with PIL 12.2.0, numpy 2.3.5, scipy 1.18.0, OpenCV 4.13.0 |
| ffmpeg | 9.0 full_build (gyan.dev) |

## Open Cloud key probe (22:48; universe 10769447171, place 117902305686664)
| Area | Request | Result | Meaning |
|---|---|---|---|
| Universe | GET /cloud/v2/universes/{U}; PATCH with empty mask | 200 / 200 | read + write OK |
| Place | GET + PATCH empty mask | 200 / 200 | OK |
| Place publishing | POST versions, empty and garbage body | 500 (not 401/403) | auth accepted; confirmed later by a real publish |
| Assets | POST /assets/v1/assets, empty | 400 "FileContent required" | auth OK |
| Game passes | GET list 200; POST empty → 400 "Name required" | | OK |
| Developer products | GET list 200; POST empty → 400 "Name required" | | OK |
| Thumbnail personalization | POST uploads, empty → 200 `{"fileToOperationIdDict":{}}`; GET /personalization → 500 (no config yet) | | upload OK |
| DataStores (Open Cloud) | GET list → 403 missing `universe-datastores.control:list` | | not needed (game uses in-game DataStoreService) |

## Progress
- 22:50 Step 0 done. Step 1 research done (RESEARCH.md): **Leaf Pile Dive**.
- 23:05 Step 2 design done (DESIGN.md, tools/balance_sim.py). Starting the build.
- 23:35 **Live v9 public.** Built: core loop (rake, bag, climb, height-multiplied dive), 6 yards + gates, shop (7 rakes, 7 bags, yards), New Season, saving (session lock, autosave, BindToClose, versioned + migration), daily streak, 3 daily quests, yard strip, friend boost + invite, 2 global boards, weekly events, welcome gift, 4 passes + 4 products (Open Cloud), anti-cheat, synth SFX + music, Blender meshes. DevTest 64/64 in Studio. Maturity questionnaire: Minimal. Genre Simulation/Incremental Simulator.
  - Live check v9: loads with saved data, raking + golden leaf + dive work, Fill My Bag shows the real Buy prompt (closed without buying).
  - Found live, fixing now: left buttons hidden by the new chat window on desktop; panels too short; first leaves out of reach of the spawn.
- 00:00 Release v2 checks in Studio: DevTest 64/64 (solo + 2-client server), save/rejoin identical, Player2 untouched by Player1's actions, phone/tablet layouts fixed + screenshotted. Clean 2-client session running since 23:55 (no game warnings/errors so far). Fixed: spawn race (first player spawned on the back fence while props loaded), camera framing, double save on shutdown (queue warning).
  - Music: scanned ~200 Pixabay phonk pages; none shows "Content ID Registered: false" (most true; the reference's two tracks no longer show the field; scanning more hit Cloudflare "Just a moment" pages, so I stopped). **No music downloaded**; the promo uses the game's own synthesized music.
  - Next: publish v2 (close Studio), live check of all products, gameplay recording, thumbnails/icon, promo.
- 07:25 **Final.** Live v17 public, icon + 4 homepage thumbnails + 4 detail-page images approved, promo videos + post drafts done, REPORT.md written. Work time used ~2 h 35 min (session was paused 00:37–06:57).
