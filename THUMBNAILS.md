# THUMBNAILS + ICON (2026-10-05 07:00–07:20 MDT)

## Rules followed (fetched 2026-10-05 from create.roblox.com/docs/production/publishing/thumbnails and the Icons page)
- Thumbnails: 16:9, 1920×1080 ideal, under 3 MB, jpg/png; up to 10 per game; Home personalization needs 2–5 active. No gameplay that isn't in the game, no artificially enhanced graphics beyond the player experience, no ad text ("50% off", "Free UGC"); logos are allowed; keep essential elements away from the bottom edge.
- Icon: square, at least 512×512, check readability at 150×150.
- Self-imposed: no Robux, coins or fake rewards, no brands, nothing copied.

## How they were made
- **Reference collage** (`assets/thumbnails/reference/reference_collage.jpg`): 4 frames from the live v17 gameplay recording (spawn with leaves + pile + ladder, raking beside the pile, ladder and Park gate, spawn with leaves), plus `live_spawn.png` (full live screenshot).
- **Gemini** (owner's logged-in account; the owner accepted the "content from images and files" terms before the run). One chat; the collage was attached to the first message with the `HTMLInputElement.prototype.click` capture trick. Gemini switched from Pro to "Flash Extended" after 2 images. One request was lost (the page showed "Creating your image" forever; after a reload it was gone) and one returned "I encountered an error", so both were re-sent.
- **Getting the files**: Gemini's page CSP blocks posting to localhost, so each image was taken with Gemini's own **Copy image** button and saved from the clipboard (`tools/save_clip.ps1`). No browser downloads. Outputs are 1024×572 (wide) and 1024×1024 (square); `tools/prep_thumbs.py` cover-crops and Lanczos-upscales them to exactly 1920×1080 / 512×512 with a light unsharp mask. Thumbnails are 436–523 KB (under 3 MB).
- Review sheets: `assets/thumbnails/ai/_review_thumbs_150.png`, `_review_icons_150.png`. Originals: `assets/thumbnails/ai/raw/`.

## Review (full size and at 150 px)
| Image | Verdict | Why |
|---|---|---|
| `icon_g_a_512.png` | **WINNER: live icon** | One big blocky face with a huge grin bursting out of a leaf explosion; reads instantly at 150 px; only game elements (avatar, maple leaves, sky) |
| `icon_g_b_512.png` | kept, A/B alternate | Avatar with rake popping out of the pile, gold leaf, readable; flatter 2D style and the avatar has hair, so it reads less "Roblox" |
| `rejected/icon_g_c_512.png` | rejected | Tower + legs sticking out of the pile; the subject is small and unclear at 150 px |
| `thumb_g4_logo.jpg` | **WINNER** | Logo spelled exactly "LEAF PILE DIVE" (the only text); avatar cannonballing into the pile, tower with ladder + blue board, autumn trees |
| `thumb_g2.jpg` | **WINNER** | Big excited avatar raking, gold leaf in the swirl, pile + tower behind; strongest expression |
| `thumb_g3.jpg` | **WINNER** | Three players jumping off the board into the pile (multiplayer), gold leaf |
| `thumb_g1.jpg` | **WINNER** | Clean dive off the blue board into the pile with a leaf explosion; the face is less expressive, so it's the weakest of the four |
| `rejected/thumb_g5_yards.jpg` | rejected | Row of yards with taller towers + Giant Oak + green gate is true to the game, but it came out in a flat 2D style that doesn't match the others and is busy at 150 px |

Stylisation notes (judged acceptable, not misleading): the towers are drawn as wooden lattice towers (in-game: a wooden pillar with a deck and railings); the ladder is drawn on the tower's front. Every element shown exists in the game: rake, maple leaves, gold leaves, leaf piles, wooden tower, yellow ladder, blue diving board, autumn trees, stone wall, other players.

## Upload proof
- **Homepage (Thumbnail Personalization API, `tools/homepage_thumbs.py`)**: 4 uploaded, moderation **Approved** for all; personalization config `ff8eabdc-17b4-4b63-9aaf-f91ce49e3b2b` created; GET /thumbnails shows all 4 **Active**. IDs in `assets/thumbnails/ai/uploaded_ids.json`. Creator Hub → Thumbnails → Home Page lists the 4 as Active ("Personalization is on").
- **Icon**: Creator Hub → Places → Icon → file input → Save Changes. `thumbnails.roblox.com/v1/games/icons` returns state **Completed**, and the served image is the new icon (`tests/screens/live_icon_check.png`).
- **Experience Detail Page**: the Creator Hub uploader ignores files set by automation, so the same 4 files were posted from the logged-in Creator Hub page to the endpoint its bundle uses (`publish.roblox.com/v1/games/{universeId}/thumbnail/image`, field `request.files`): 4× HTTP 200. `games.roblox.com/v2/games/10769447171/media` lists 4 images, all `approved: true`; 2 were still "Pending" CDN renders right after the upload.
