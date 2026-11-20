// Brainrot Bay: hands the game in. Copies the place, the scripts, the
// screenshots and the play link beside this file into the output
// directory, then writes the dossier the grader checks, built from that
// same output directory with the kit's library. Node 22, standard
// library only. Deterministic: two runs write identical bytes.

import { copyFileSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = process.env.MAKEFUN_OUTPUT_DIR || "/output";

function copyTree(from: string, to: string): number {
  let copied = 0;
  mkdirSync(to, { recursive: true });
  for (const entry of readdirSync(from)) {
    if (entry.startsWith(".")) {
      continue;
    }
    const src = join(from, entry);
    const dst = join(to, entry);
    if (statSync(src).isDirectory()) {
      copied += copyTree(src, dst);
    } else {
      copyFileSync(src, dst);
      copied += 1;
    }
  }
  return copied;
}

function main(): void {
  // Fail fast with a clear message when the place has not been built yet.
  const placePath = join(HERE, "game.rbxl");
  if (!statSync(placePath, { throwIfNoEntry: false })) {
    throw new Error("brainrot-bay: game.rbxl is missing; run rojo build first");
  }

  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });

  copyFileSync(join(HERE, "game.rbxl"), join(OUT, "game.rbxl"));

  // The play link must name a real place and universe before it is copied.
  const playLink = JSON.parse(readFileSync(join(HERE, "PLAY.json"), "utf8")) as {
    url?: unknown;
    place_id?: unknown;
    universe_id?: unknown;
  };
  if (
    typeof playLink.url !== "string" ||
    !Number.isSafeInteger(playLink.place_id) ||
    !Number.isSafeInteger(playLink.universe_id) ||
    (playLink.place_id as number) <= 0 ||
    (playLink.universe_id as number) <= 0
  ) {
    throw new Error("brainrot-bay: PLAY.json must name a url, place_id and universe_id");
  }
  copyFileSync(join(HERE, "PLAY.json"), join(OUT, "PLAY.json"));
  const srcFiles = copyTree(join(HERE, "src"), join(OUT, "src"));
  const shotFiles = copyTree(join(HERE, "screenshots"), join(OUT, "screenshots"));

  const dossier = buildDossier(OUT, { text_max_bytes: 65536 });
  writeFileSync(join(OUT, "dossier.json"), dossier);

  const placeBytes = statSync(join(OUT, "game.rbxl")).size;
  const dossierBytes = statSync(join(OUT, "dossier.json")).size;
  console.log(
    `brainrot-bay: place ${placeBytes} bytes, ${srcFiles} script files, ${shotFiles} screenshots, dossier ${dossierBytes} bytes`
  );
}

main();
