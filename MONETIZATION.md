# MONETIZATION

Created 2026-10-04 23:08 MDT via Open Cloud (`tools/create_monetization.py`: `POST /game-passes/v1/universes/{U}/game-passes`, `POST /developer-products/v2/universes/{U}/developer-products`, multipart with `imageFile`). IDs are wired into `src/shared/Config.luau`. **No paid randomness**: every item has a fixed, stated result, and the whole game can be finished free (balance sim).

## Game passes
| Key | Name | Price | Pass ID | Benefit | Code |
|---|---|---|---|---|---|
| Leaves2x | 2x Leaves | 199 R$ | 2006835426 | Every leaf you rake is worth 2x, forever. | `Gameplay.leafValue` |
| BigBag | Big Bag | 149 R$ | 2006535369 | Your bag holds 2x as many leaves, forever. | `State.bagCap` |
| AutoRake | Auto Rake | 129 R$ | 2006679404 | Your rake swings by itself while you walk in a yard (toggle with the AUTO button). | client auto-swing loop (server still rate-limits) |
| VIP | VIP | 99 R$ | 2006295483 | 1.25x Acorns from every dive, a gold leaf trail and a [VIP] chat tag. | `Gameplay.acornMult`, `applyTrail`, client chat tag |

## Developer products
| Key | Name | Price | Product ID | Grant |
|---|---|---|---|---|
| FillBag | Fill My Bag | 15 R$ | 3716623789 | Your bag is filled to the top right away. Then dive into the pile to cash it in. |
| Potion2x | 2x Acorns (10 min) | 39 R$ | 3716623793 | 2x Acorns from dives for 10 minutes. Buying more adds time. |
| AcornCrate | Acorn Crate | 49 R$ | 3716623799 | Acorns equal to 5 full bags at your current bag size (at least 500). |
| UnlockYard | Unlock Next Yard | 79 R$ | 3716623805 | Opens your next locked yard right away. If every yard is open, you get an Acorn Crate instead. |

## Purchase handling (`src/server/Monetization.luau`)
1. player not in server or profile not loaded → `NotProcessedYet`
2. `PurchaseId` already in the profile's `Receipts` → `PurchaseGranted` (no second grant)
3. apply the grant, record the `PurchaseId`, **save with UpdateAsync** (`DataService.save` returns true only if the write happened)
4. save failed → roll back the grant and the receipt, return `NotProcessedYet` (Roblox retries)
5. only after a successful save → `PurchaseGranted`

Passes: `UserOwnsGamePassAsync` on join (pcall) in `Passes.load`, plus `PromptGamePassPurchaseFinished` for in-session buys. Both go through `Passes.grant`, which resyncs bag capacity and the VIP trail.

DevTest covers: every handler, `ProcessReceipt` called twice with the same PurchaseId for all 4 products (grant once), and a forced save failure (rollback + NotProcessedYet).

## Prompt placement
- ⭐ STORE button → panel with the 4 passes and 4 products (icons, prices, OWNED state)
- 🤖 AUTO button prompts the Auto Rake pass if not owned
