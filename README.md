[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Razzshare102/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Razzshare102/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

# Brainrot Bay — a Steal-a-Brainrot game

A 3D Roblox game for the make.fun competition **roblox-brainrot-01**
("Make the best AI Roblox brainrot game", $1,000, top 50 paid).
Entries close **2026-11-20T14:30:00Z (20:30 Dhaka, 20 Nov 2026)**.

## The game

You spawn on a sunny island. A conveyor belt runs through the middle,
carrying absurd original brainrot characters past you. Walk up to one
and press **E** to buy it — it walks to your base and earns money per
second, shown on its label. Save up for rarer ones.

Then the fun starts: walk onto another player's base and press **E** on
their brainrot to steal it, then run home and press **E** to place it
on your own base. If they slap you (**Q**) you drop it. Lock your base
(**F**, 60s lock, 120s cooldown) so nobody can steal from you.

Every 3 minutes a **tsunami** sweeps the island — 30 seconds of warning,
then a wall of water. Your base platform is the only safe ground, so
run home. Spend cash in the **shop** (base slots, speed, slap power,
longer locks, 2x income) and **rebirth** for a permanent +25% income
multiplier each time.

## The cast (15 original brainrots, 6 rarities)

- **Common:** Tung Tung Sahur ($12/s), Brr Brr Patapim ($9/s)
- **Rare:** Tralalero Tralala ($48/s), Chimpanzini Bananini ($35/s)
- **Epic:** Cappuccino Assassino ($95/s), Lirili Larila ($120/s), Boneca Ambalabu ($140/s)
- **Legendary:** La Vaca Saturno ($260/s), Chimpanzini Bananini ($260/s), Frigo Camelo ($310/s)
- **Mythic:** Giraffa Celeste ($520/s), Los Tralaleritos ($640/s), Matteo ($780/s)
- **Brainrot God:** Graipuss Medussi ($1,500/s), Los Crocodillitos ($2,200/s)

Plus 5 mutations — Normal, Golden (x2), Diamond (x4), Rainbow (x8),
Galactic (x15) — that multiply a brainrot's income.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| Mouse | Camera |
| **E** | Buy a brainrot off the belt / grab one off a base / place a stolen one on your base / pick a dropped one up |
| **Q** | Slap (knocks the target back; they drop what they carry) |
| **F** | Lock your base for 60s |
| **G** | Drop what you are carrying |
| Shop / Rebirth buttons | Bottom-right on screen |

## How the code is organised

- `src/shared/BrainrotData.luau` — the 15 brainrots, rarities, mutations, shop list.
- `src/server/GameState.luau` — one source of truth per player: cash, income, brainrots, slots, lock, rebirths.
- `src/server/Spawner.luau` — the conveyor belt: weighted rarity/mutation rolls, brainrots walk the belt.
- `src/server/StealSystem.luau` — steal / pickup / carry / drop / slap / base assignment.
- `src/server/Tsunami.luau` — the 3-minute wave cycle (warning, sweep, safe bases).
- `src/server/Shop.luau` — the 5 shop items and their prices.
- `src/server/init.server.luau` — wires it all up: RemoteEvents, base claiming, signs, lock walls, income tick, sync.
- `src/client/HUD.luau` — cash / income / rebirth / lock / tsunami banner / shop panel.
- `src/client/Controls.luau` — E / Q / F / G and the context prompt.
- `src/client/Effects.luau` — buy / steal / slap / rebirth sounds and sparkles.
- `src/client/Game.client.luau` — client boot.
- `default.project.json` — the 3D world: ground, plaza, belt, 8 coloured bases in a ring, trees, rocks, statues. Built by hand (no Roblox Studio on Linux).
- `main.ts` — builds the entry dossier for the grader.
- `screenshots/` — 4 screenshots (1280x720). The first by name, `01-cover.png`, is the thumbnail.

## Publish it (Razz — this is your part)

Roblox Studio has no Linux build, so this was written and checked on
Linux but never opened in Studio. Publishing needs a Windows or Mac
computer with Roblox Studio installed.

1. **Install Roblox Studio** (create.roblox.com, free) and sign in with
   your Roblox account.
2. **Install the Rojo plugin** in Studio (Plugins > Plugin Marketplace,
   search "Rojo"), or build the place from the command line if you have
   Rojo installed (`rojo build default.project.json --output game.rbxl`).
3. Open this folder in Studio via the Rojo plugin (or open the built
   `game.rbxl` directly: File > Open).
4. Press **Play** (F5) and walk around. Check: brainrots walk the belt,
   pressing E near one buys it, money ticks up, F locks your base.
5. **Publish:** File > Publish to Roblox As... > create a new experience
   (or update an existing one). Set it to **Public** (Home > Settings >
   Privacy > Public, or the experience's Audience setting).
6. **Set the description:** in the experience settings, paste the play
   code `BRAINROT BAY` (or any line telling players how to play).
7. **Upload the thumbnail:** in Creator Dashboard > your experience >
   Thumbnails, upload `screenshots/01-cover.png` as the thumbnail, and
   upload it as the icon too. The thumbnail must match one of the
   entry's screenshots (01-cover.png is the first screenshot).
8. **Send me the numbers:** the experience's **place_id** and
   **universe_id** (find them in Creator Dashboard > your experience >
   the URL, or in Studio under Game Settings). I will fill them into
   `PLAY.json` and submit the entry.
9. **Replace the screenshots if you can:** the 4 screenshots in
   `screenshots/` are composed renders (drawn from the game's layout),
   not captures from Studio. The thumbnail is allowed to be composed,
   but the other three score better as real in-game captures — take
   fresh 1280x720 screenshots in Studio (Play mode) showing the belt,
   a steal, and the tsunami, and replace `02-`, `03-`, `04-` with them
   before I submit.

## Verification done on Linux (no Studio)

- All 11 `.luau` files parse cleanly (luau-web 1.5.1 `loadstring`,
  throw on compile error). One real syntax error was found and fixed
  (a line starting with `(` after a local, in StealSystem).
- `default.project.json` is valid JSON; Rojo 7.7.1 builds
  `game.rbxl` (37.8 KB, far under the 32 MiB gate) with 126 parts,
  8 bases, 48 slot pads.
- `main.ts` builds the dossier with the vendored make.fun library.
- Screenshots are 1280x720, each under 256 KiB.
