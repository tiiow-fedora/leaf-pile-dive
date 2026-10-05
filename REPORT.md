# REPORT: Leaf Pile Dive 🍂

**Live:** https://www.roblox.com/games/117902305686664/ (universe 10769447171), **place version 17**, public. Git tag `live-v17`; exact build in `backup/last-known-good.rbxl`.

**What it is:** an autumn collect-and-cash-in simulator. You rake leaves into your bag (the server decides which leaves are inside your rake's reach), then dive into the yard's leaf pile to turn them into Acorns. **The height you dive from multiplies the payout** (ground ×1; Backyard tower ×1.8; Giant Oak tower ×4.6). Acorns buy 7 rakes (reach + leaf value), 7 bags (capacity) and 6 yards (more valuable leaves, taller towers), up to the Giant Oak; New Season gives +50% leaf value. Golden leaves are worth 10×. Plus: daily 7-day streak, 3 daily quests, weekly events by UTC week, friend boost + invite, 2 global boards, welcome gift, 4 passes + 4 products (no paid randomness, finishable free). Research, scoring and why this concept: `RESEARCH.md`. Design and balance sim: `DESIGN.md`, `tools/balance_sim.py`.

**Timing:** started 22:45 MDT. The session sat paused from 00:37 to 06:57 (no activity until you typed "Resume"), so about 2 h 35 min of actual work in total. See DECISIONS.md.

## Verified, and how
| What | How | Evidence |
|---|---|---|
| Whole loop + every system | DevTest inside the running server (`DevRun:Invoke()`): raking rules, golden leaves, real falls into the pile (×1, ×1.8, height cap, empty bag), shop tiers + bad args, yards, Season, daily, quests, products, receipt de-dupe ×4, forced save failure rollback, migration v0→v1, weekly events, anti-cheat, falling. **64/64** solo and in a 2-client server | `tests/devtest_solo_and_savetest.log`, `tests/devtest_2client.log` |
| Hand play | Raked, climbed the ladder, walked off the board → "x1.8 DIVE! +45" (= 20 × 1.8 × 1.25 VIP); live: rake → golden leaf → walk-in dive | TESTING.md |
| Saving | Save → stop (BindToClose) → rejoin: all 7 values identical | `tests/devtest_solo_and_savetest.log` (SAVETEST lines) |
| Multiplayer | Server + 2 clients: DevTest drove Player1 through everything; Player2's state was identical before and after | `tests/devtest_2client.log` (MP/MP2) |
| Layouts | iPhone 7 667×375, iPad 1024×768, desktop; 4 layout bugs found and fixed | `tests/screens/phone_*.png`, `tablet_*.png` |
| Clean session | 11 min, server + 2 clients, 0 errors / 0 warnings | `tests/clean_session.md` |
| Live game (v14/v17) | Joined in the Roblox app: loads with saved data, raking, golden leaf, dives (ground + tower ×1.9), live server console 0 errors / 0 warnings; **all 4 products show the real Buy prompt** (closed without buying) | `tests/screens/live_v14_prompt_*.png` |
| Monetization | 4 passes + 4 products created via Open Cloud with icons; ProcessReceipt dedupe/rollback/save-before-grant | MONETIZATION.md |
| Store page | Name, description (lists only real features), Public, Simulation → Incremental Simulator, 20 players, questionnaire → **Minimal** | public page text checked 07:21 |

## Skipped, approximated or unverified
- **Pass Buy prompts not seen**: your account owns its own passes, so the store shows OWNED and Roblox won't show their Buy dialog to you. The pass IDs and the PromptGamePassPurchase calls match the 4 products, which do show it. The passes still need a check from a non-owner account.
- **No real low-end/mobile device test**: only Studio's device simulator.
- **Promo footage is short (17 s + end card)**: automating the live climb meant using the F9 console, and its overlay couldn't be closed from automation, so those takes are unusable. The videos show raking, a golden leaf, running into the pile and a ground dive with the leaf burst. A tower dive isn't in the promo, though it happened live (take3, under the console overlay).
- **No phonk**: of ~200 Pixabay phonk pages, none showed "Content ID Registered: false". The two tracks used last time no longer show the field, and further scanning hit Cloudflare checks, so I stopped and downloaded nothing. The promos use the game's own synthesized music.
- **Test data on your account**: the Studio save test gave your profile +12,345 Acorns (Acorns only, not TotalAcorns, so the board isn't affected). Leave it or reset it.
- **Thumbnail art is 1024 px upscaled to 1920×1080** (Gemini's output size via Copy image); it looks fine at full size but isn't native 1080p.
- Rojo shows a "confirm sync" dialog for every change (setting "Always"). Changing the setting failed when Studio hit its HTTP limit; note for next time.

## Icon and thumbnails (THUMBNAILS.md)
- **Icon (live):** `assets/thumbnails/ai/icon_g_a_512.png`, a big excited blocky face bursting out of a leaf explosion, the clearest at 150 px. Alternate kept: `icon_g_b_512.png`.
- **Homepage thumbnails (4, all Approved + Active, personalization config `ff8eabdc…`):** `thumb_g4_logo.jpg` (logo spelled exactly, cannonball dive), `thumb_g2.jpg` (big raking avatar + gold leaf), `thumb_g3.jpg` (three players diving, multiplayer), `thumb_g1.jpg` (clean board dive). Rejected: `rejected/thumb_g5_yards.jpg` (flat style, busy) and `rejected/icon_g_c_512.png` (unclear at 150 px).
- **Detail page:** the same 4 images, all approved (posted from the logged-in Creator Hub page because its uploader ignores automated file input). Nothing left for you to do there.

## Promo
`promo/out/leafpiledive_{hype,calm}_{vertical,16x9}.mp4` (20.1 s each); scripts `promo/make_videos.py`; draft posts for X, TikTok/Shorts and r/robloxgamedev in `promo/POSTS.md`. **Nothing was posted.**

## What you need to do
1. **Posting**: review and post `promo/POSTS.md` yourself, if wanted.
2. **Music**: if you want phonk in the promo, pick a track whose Pixabay page you've checked for Content ID yourself, and run `add_music.py` after updating its paths/timings.
3. **Reach**: the page shows "Ages 16+". New experiences stay limited until they pass an engagement threshold or you pay the refundable publishing fee. That's your call; I paid nothing.
4. **API key**: the key in `3D Objects/.env` is broad (it can publish, create products, and write the universe). Restrict it to this universe and the needed scopes, or regenerate it.
5. **Optional**: test the 4 pass Buy prompts from a second account; decide whether to reset the test Acorns on your profile.

## 5 best next improvements (ranked)
1. **Record a clean tower-dive clip and re-cut the promo.** The height multiplier is the hook, and the current videos only show a ground dive. Use a Studio-recorded camera path or a second account, avoiding the console.
2. **Ladder → stairs ramp or launch pad.** The truss ladder works but is slow and fiddly on touch; faster climbing makes the dive loop (and the hook) more fun in every session.
3. **A visible height meter while falling** ("x2.4!" growing as you climb/fall). It teaches the multiplier without text and makes each dive feel earned.
4. **Pets/companions or a pile-size cosmetic, sold for Acorns.** A second long-term spend after yards; the sim tops out around 70 min to the Giant Oak.
5. **Check analytics after 7 days** (impressions → plays per thumbnail, D1 retention, where players quit) before adding content. The game has 0 visits so far, so every current priority is a guess from genre research.
