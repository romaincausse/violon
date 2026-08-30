#!/usr/bin/env node
/**
 * Grave les partitions hors application.
 *
 * MusicXML  ->  un SVG par systeme  +  un timemap JSON
 *
 * Le timemap donne l'onset en millisecondes de chaque note, et chaque glyphe
 * du SVG porte un identifiant. On obtient donc gratuitement la
 * correspondance note / temps / position a l'ecran, qui est exactement ce
 * qu'il faut pour le curseur, la selection de boucle et la heatmap.
 *
 * Prerequis :  npm install verovio
 * Usage     :  node tool/build_scores.mjs
 *
 * Entree  : tool/sources/<id>.musicxml   (non versionne : droits d'auteur)
 * Sortie  : assets/scores/<id>/system-000.svg, ..., timemap.json, meta.json
 */

import fs from "node:fs/promises";
import path from "node:path";

const SOURCES = "tool/sources";
const OUTPUT = "assets/scores";

/**
 * Systemes courts et portee haute : l'application tourne sur un telephone
 * pose sur un pupitre, a environ 70 cm des yeux. Il faut une portee d'environ
 * 10 mm de haut pour rester aussi lisible qu'une partition papier, ce qui
 * impose 2 mesures par ligne. Aucun moteur en reflow ne ferait ce choix.
 */
const VEROVIO_OPTIONS = {
  scale: 40,
  pageWidth: 1200,
  pageHeight: 400,
  adjustPageHeight: true,
  breaks: "auto",
  systemMaxPerPage: 1,
  footer: "none",
  header: "none",
  spacingStaff: 8,
};

async function main() {
  const { default: createVerovioModule } = await import("verovio/wasm");
  const { VerovioToolkit } = await import("verovio/esm");

  const VerovioModule = await createVerovioModule();
  const toolkit = new VerovioToolkit(VerovioModule);
  toolkit.setOptions(VEROVIO_OPTIONS);

  const files = (await fs.readdir(SOURCES)).filter((f) =>
    f.endsWith(".musicxml") || f.endsWith(".mxl")
  );

  if (files.length === 0) {
    console.log(`Aucune partition dans ${SOURCES}/`);
    return;
  }

  for (const file of files) {
    const id = path.basename(file, path.extname(file));
    const target = path.join(OUTPUT, id);
    await fs.mkdir(target, { recursive: true });

    const data = await fs.readFile(path.join(SOURCES, file), "utf8");
    toolkit.loadData(data);

    const pageCount = toolkit.getPageCount();
    for (let page = 1; page <= pageCount; page++) {
      const svg = toolkit.renderToSVG(page);
      const name = `system-${String(page - 1).padStart(3, "0")}.svg`;
      await fs.writeFile(path.join(target, name), svg);
    }

    const timemap = toolkit.renderToTimemap({ includeMeasures: true });
    await fs.writeFile(
      path.join(target, "timemap.json"),
      JSON.stringify(timemap, null, 2),
    );

    await fs.writeFile(
      path.join(target, "meta.json"),
      JSON.stringify({ id, systemCount: pageCount, source: file }, null, 2),
    );

    console.log(`${id} : ${pageCount} systemes`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
