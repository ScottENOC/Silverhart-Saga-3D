#!/usr/bin/env node
/**
 * Run Ara's original bikini top + bottom source locally against Wren's exact
 * Ara morph profile. Input data is built by build-fitting-data.ts from CC0
 * MakeHuman source data. No Ara CLI, API, or hosted generator is called.
 *
 * Output is an OBJ + MTL + generated PNG textures in a standalone folder.
 * Ara coordinates are decimetres; OBJ coordinates are converted to metres.
 * Body skin is never hidden: the downstream Blender attachment must ignore
 * Ara's optional hides masks and retain the accepted Wren skin and rig.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { AssetLibrary } from "./vendor/src/core/assets.ts";
import { applyTargets, targetWeights } from "./vendor/src/core/morph.ts";
import { DEFAULT_PARAMS, yearsToAge } from "./vendor/src/core/params.ts";
import { vertexNormals } from "./vendor/src/core/geometry.ts";
import { makeBody } from "./vendor/src/core/garments/body.ts";
import { SWIMWEAR } from "./vendor/src/core/garments/swimwear.ts";
import type { GCtx, GarmentStyle, GPart } from "./vendor/src/core/garments/kit.ts";

const root = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
function arg(name: string, fallback?: string): string {
  const i = args.indexOf(name);
  if (i < 0) { if (fallback !== undefined) return fallback; throw new Error("Missing " + name); }
  return args[i + 1];
}
const profilePath = resolve(arg("--profile", join(root, "../../character-preview/wren-ara.json")));
const dataDir = resolve(arg("--data", join(root, "build/fitting-data")));
const outDir = resolve(arg("--out", join(root, "build/wren-garments")));
mkdirSync(outDir, { recursive: true });
const profile = JSON.parse(readFileSync(profilePath, "utf8"));
if (profile.kind !== "ara-character" || profile.params?.name !== "Wren") throw new Error("Expected Wren Ara profile");
const sourceCommit = "b60b5bece6d383d2cbb7067fd50e7c8e68b5a395";

const source = {
  async read(path: string) { return new Uint8Array(readFileSync(join(dataDir, path))); },
};
const lib = await new AssetLibrary(source).init();
const params = {
  ...DEFAULT_PARAMS,
  ...profile.params,
  age: yearsToAge(Number(profile.params.ageYears ?? 25)),
  modifiers: profile.params.modifiers ?? {},
  garmentStyles: {},
};
const sliders = new Map(lib.catalog.sliders.flatMap((g: any) => g.sliders.map((s: any) => [s.id, s] as const)));
const weights = targetWeights(params, sliders);
const coords = applyTargets(lib, weights);
const faceVerts = lib.base.arrays.faceVerts as Uint32Array;
const faceSizes = new Uint8Array(faceVerts.length / 4).fill(4);
const normals = vertexNormals({ positions: coords, faceSizes, faceVerts, faceUVs: lib.base.arrays.faceUVs as Uint32Array, uvs: lib.base.arrays.uvs as Float32Array });
const regions = lib.base.arrays.regions as Uint8Array;
const body = makeBody(coords, normals, regions, lib.base.meta.joints);
const generatedTextures = new Map<string, Uint8Array>();
const g: GCtx = {
  body, faceVerts, layered: { top: false, bottom: false }, underwear: false, outfits: {},
  texture(key, make) {
    const existing = generatedTextures.get(key);
    if (existing) return { map: key + ".png", alpha: false };
    const tex = make();
    generatedTextures.set(key, tex.color);
    writeFileSync(join(outDir, key + ".png"), tex.color);
    if (tex.normal) writeFileSync(join(outDir, key + "_n.png"), tex.normal);
    return { map: key + ".png", normalMap: tex.normal ? key + "_n.png" : undefined, alpha: tex.alpha };
  },
};
const style: GarmentStyle = { pattern: "foil", color: "#09090B", color2: "#09090B" };
const bottomDef = SWIMWEAR.find(x => x.id === "bikini_bottom");
const topDef = SWIMWEAR.find(x => x.id === "bikini_top");
if (!bottomDef || !topDef) throw new Error("Pinned Ara source is missing bikini_top or bikini_bottom");
const parts = [
  ...topDef.build(g, style).map((p: GPart) => ({ ...p, sourceGarment: "bikini_top" })),
  ...bottomDef.build(g, style).map((p: GPart) => ({ ...p, sourceGarment: "bikini_bottom" })),
];
if (parts.length < 3) throw new Error("Ara returned too few garment parts; expected top, panels, gusset and strings");
const materials = new Map<string, any>();
const obj: string[] = ["# Ara 3D Gen bikini source port", "mtllib Wren_Ara_Bikini.mtl"];
const mtl: string[] = [];
const minY = Math.min(...Array.from({ length: coords.length / 3 }, (_, i) => coords[i * 3 + 1]));\nlet vertexOffset = 0, uvOffset = 0;
const partReport: any[] = [];
for (let pi = 0; pi < parts.length; pi++) {
  const part: any = parts[pi], mesh = part.mesh, mat = part.material;
  if (!mesh?.positions?.length || !mesh.faceSizes?.length || !mesh.faceVerts?.length) throw new Error("Ara produced an empty garment mesh at part " + pi);
  const materialName = String(mat.name || "AraGarment").replace(/[^A-Za-z0-9_]/g, "_") + "_" + pi;
  obj.push("o " + part.sourceGarment + "_" + pi, "usemtl " + materialName);
  for (let i = 0; i < mesh.positions.length; i += 3)
    obj.push("v " + (mesh.positions[i] * 0.1) + " " + ((mesh.positions[i + 1] - minY) * 0.1) + " " + (mesh.positions[i + 2] * 0.1));
  for (let i = 0; i < mesh.uvs.length; i += 2) obj.push("vt " + mesh.uvs[i] + " " + (1 - mesh.uvs[i + 1]));
  let corner = 0;
  for (const size of mesh.faceSizes) {
    const face: string[] = [];
    for (let k = 0; k < size; k++) {
      const vi = vertexOffset + mesh.faceVerts[corner + k] + 1;
      const ti = uvOffset + (mesh.faceUVs?.[corner + k] ?? 0) + 1;
      face.push(vi + "/" + ti);
    }
    obj.push("f " + face.join(" "));
    corner += size;
  }
  vertexOffset += mesh.positions.length / 3;
  uvOffset += mesh.uvs.length / 2;
  if (!materials.has(materialName)) {
    materials.set(materialName, mat);
    const colour = String(mat.color ?? "#ffffff").replace("#", "");
    const rgb = [0,2,4].map(i => parseInt(colour.slice(i,i+2),16)/255);
    mtl.push("newmtl " + materialName, "Kd " + rgb.join(" "), "Pr " + Number(mat.roughness ?? 0.4), "Pm " + Number(mat.metalness ?? 0.5), "d " + (mat.opacity ?? 1));
    if (mat.map) mtl.push("map_Kd " + mat.map);
    mtl.push("");
  }
  partReport.push({ garment: part.sourceGarment, part: pi, vertices: mesh.positions.length / 3, faces: mesh.faceSizes.length, hasSkinHideMask: !!part.hides });
}
writeFileSync(join(outDir, "Wren_Ara_Bikini.obj"), obj.join("\n") + "\n");
writeFileSync(join(outDir, "Wren_Ara_Bikini.mtl"), mtl.join("\n") + "\n");
const report = {
  schema: 1, generator: "Ara 3D Gen native swimwear source", sourceCommit,
  profile: profilePath, ageYears: profile.params.ageYears,
  morphTargetCount: weights.size, bodyVertexCount: coords.length / 3,
  bodyFaceCount: faceSizes.length, semanticRegionVertexCount: regions.length,
  garmentPartCount: parts.length, garments: partReport,
  textures: [...generatedTextures.keys()],
  bodySkinPreserved: true,
  araHidesMasksApplied: false,
};
if (!partReport.some(x => x.garment === "bikini_bottom") || !partReport.some(x => x.garment === "bikini_top"))
  throw new Error("Generated output did not contain both Ara bikini pieces");
writeFileSync(join(outDir, "generation-report.json"), JSON.stringify(report, null, 2) + "\n");
console.log("ARA_NATIVE_WREN_BIKINI_OK", JSON.stringify(report));
