#!/usr/bin/env node
/**
 * Build only Ara's fitting data packs from the CC0 MakeHuman source tree.
 * This is a focused port of buildBase/buildSliders/buildTargets from Ara
 * 3D Gen at b60b5bece6d383d2cbb7067fd50e7c8e68b5a395.
 *
 * It intentionally does not download or build skins, hair, proxies, or call
 * Ara's CLI/service. The output is exactly the metadata the garment source
 * needs: morphed base coordinates, quad topology, semantic regions, joints,
 * and morph target deltas.
 */
import { readFileSync, readdirSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { encodePack } from "./vendor/src/core/pack.ts";
import { REGION } from "./vendor/src/core/garments/body.ts";

type Face = { v: number[]; t: number[]; group: string };
type Slider = { id: string; label: string; targets: [string | null, string | null][]; bipolar: boolean };
const root = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const arg = (name: string, fallback?: string) => {
  const i = args.indexOf(name);
  if (i < 0) { if (fallback !== undefined) return fallback; throw new Error("Missing " + name); }
  return args[i + 1];
};
const MH = resolve(arg("--mh-dir"));
const OUT = resolve(arg("--out", join(root, "build", "fitting-data")));
mkdirSync(OUT, { recursive: true });

function parseObj(path: string) {
  const v: number[] = [], vt: number[] = [], faces: Face[] = [];
  let group = "";
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const p = line.trim().split(/\s+/);
    if (p[0] === "v") v.push(+p[1], +p[2], +p[3]);
    else if (p[0] === "vt") vt.push(+p[1], +p[2]);
    else if (p[0] === "g") group = p[1] ?? "";
    else if (p[0] === "f") {
      const fv: number[] = [], ft: number[] = [];
      for (const c of p.slice(1)) {
        const [a, b] = c.split("/");
        fv.push(+a - 1); ft.push(b ? +b - 1 : +a - 1);
      }
      faces.push({ v: fv, t: ft, group });
    }
  }
  return { v, vt, faces };
}
function walk(dir: string, out: string[] = []): string[] {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
function buildBase() {
  const obj = parseObj(join(MH, "3dobjs/base.obj"));
  const body = obj.faces.filter(f => f.group === "body");
  if (body.some(f => f.v.length !== 4)) throw new Error("Ara base body must consist of quads");
  const skel = JSON.parse(readFileSync(join(MH, "rigs/default.mhskel"), "utf8"));
  const meta = {
    vertexCount: obj.v.length / 3, faceCount: body.length, joints: skel.joints,
    bones: Object.entries(skel.bones as Record<string, { parent: string | null; head: string; tail: string }>)
      .map(([name, b]) => ({ name, parent: b.parent, head: b.head, tail: b.tail })),
  };
  const regionOf = (bone: string) =>
    /^neck/.test(bone) ? REGION.neck
    : /^(spine|breast|clavicle)/.test(bone) ? REGION.torso
    : /^(root|pelvis)/.test(bone) ? REGION.hips
    : /^(shoulder|upperarm)/.test(bone) ? REGION.upperarm
    : /^lowerarm/.test(bone) ? REGION.lowerarm
    : /^(wrist|finger|metacarpal)/.test(bone) ? REGION.hand
    : /^upperleg/.test(bone) ? REGION.upperleg
    : /^lowerleg/.test(bone) ? REGION.lowerleg
    : /^(foot|toe)/.test(bone) ? REGION.foot
    : REGION.head;
  const weights = JSON.parse(readFileSync(join(MH, "rigs/default_weights.mhw"), "utf8")).weights as Record<string, [number, number][]>;
  const best = new Float32Array(meta.vertexCount);
  const regions = new Uint8Array(meta.vertexCount).fill(255);
  for (const [bone, list] of Object.entries(weights))
    for (const [v, w] of list) if (w > best[v]) { best[v] = w; regions[v] = regionOf(bone); }
  const used = new Uint8Array(meta.vertexCount);
  for (const f of body) for (const v of f.v) used[v] = 1;
  for (let v = 0; v < meta.vertexCount; v++) if (!used[v]) regions[v] = 255;
  const data = encodePack(meta, {
    regions, positions: Float32Array.from(obj.v),
    faceVerts: Uint32Array.from(body.flatMap(f => f.v)),
    faceUVs: Uint32Array.from(body.flatMap(f => f.t)),
    uvs: Float32Array.from(obj.vt),
  });
  writeFileSync(join(OUT, "base.pack"), data);
  return { vertexCount: meta.vertexCount, faceCount: meta.faceCount, jointCount: Object.keys(skel.joints).length };
}
function buildSliders(available: Set<string>) {
  const defs = JSON.parse(readFileSync(join(MH, "modifiers/modeling_sliders.json"), "utf8")) as Record<string, {
    sortOrder: number; modifiers: Record<string, { mod: string; label?: string }[]>
  }>;
  const groups: { category: string; group: string; sliders: Slider[] }[] = [];
  const emitted = new Set<string>();
  const pretty = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).replace(/-/g, " ");
  const SKIP = /genital|penis|bulge|testicle|nipple|pelvis-tone/i;
  for (const [category, cat] of Object.entries(defs).sort((a,b) => a[1].sortOrder-b[1].sortOrder)) {
    for (const [group, mods] of Object.entries(cat.modifiers)) {
      const sliders: Slider[] = [], seen = new Set<string>();
      for (const m of mods) {
        const [dir, spec] = m.mod.split("/");
        if (!spec || !spec.includes("-") || SKIP.test(spec) || dir === "macrodetails") continue;
        let name = spec, lo: string | null = null, hi: string | null = null;
        if (spec.includes("|")) {
          const [left, right] = spec.split("|"); const cut = left.lastIndexOf("-");
          name = left.slice(0, cut); lo = left.slice(cut + 1); hi = right;
        }
        const range = lo ? `${lo}|${hi}` : "";
        const key = (n: string, side: string | null) => side ? `${dir}/${n}-${side}` : `${dir}/${n}`;
        const pair = (n: string): [string | null, string | null] => range ? [key(n,lo),key(n,hi)] : [null,key(n,null)];
        const pairs: [string | null,string | null][] = [pair(name)];
        let id = name;
        let label = m.label ?? pretty(name.replace(new RegExp(`^${dir}-`), ""));
        const twin = name.startsWith("r-") ? "l-"+name.slice(2) : name.startsWith("l-") ? "r-"+name.slice(2) : null;
        if (twin) {
          const base = name.slice(2); if (seen.has(base)) continue;
          seen.add(base); id = base; pairs.push(pair(twin));
          label = (m.label ?? pretty(base.replace(new RegExp(`^${dir.replace(/s$/,"")}-?`), ""))).replace(/^(Right|Left) /i, "");
        }
        if (seen.has(id+range) && !twin) continue;
        seen.add(id+range);
        const flat = pairs.flat().filter((x): x is string => !!x);
        if (flat.some(t => !available.has(t))) continue;
        let sid = `${dir}/${id}`;
        if (emitted.has(sid) && range) sid = `${sid}:${range}`;
        if (emitted.has(sid)) continue;
        emitted.add(sid);
        sliders.push({ id:sid, label:label+(sid.includes(":") ? ` (${lo}/${hi})` : ""), targets:pairs, bipolar:!!range });
      }
      if (sliders.length) groups.push({ category, group, sliders });
    }
  }
  const targets = new Set(groups.flatMap(g => g.sliders.flatMap(s => s.targets.flat().filter((x): x is string => !!x))));
  return { groups, targets };
}
function buildTargets(extra: Set<string>) {
  const files = walk(join(MH, "targets")).filter(p => p.endsWith(".target"));
  const byKey = new Map(files.map(p => [relative(join(MH, "targets"), p).replace(/\.target$/, ""), p]));
  const wanted = [...byKey.keys()].filter(k =>
    ((k.startsWith("macrodetails/") || /^breast\/(fe)?male-/.test(k)) && !k.includes("-baby")) ||
    k.startsWith("expression/units/") || extra.has(k)
  );
  const meta: { format:number; targets:Record<string,[number,number,number]> } = { format:2, targets:{} };
  const idx:number[] = [], d:number[][] = [[],[],[]];
  for (const key of wanted.sort()) {
    const rows:number[][] = [];
    for (const line of readFileSync(byKey.get(key)!, "utf8").split("\n")) {
      if (!line || line[0] === "#") continue;
      const p = line.trim().split(/\s+/).map(Number);
      if (p.length >= 4) rows.push(p);
    }
    rows.sort((a,b)=>a[0]-b[0]);
    let max=0; for (const r of rows) max=Math.max(max,Math.abs(r[1]),Math.abs(r[2]),Math.abs(r[3]));
    const s=Math.max(0.001,max/32767), start=idx.length;
    let prev=0; const last=[0,0,0];
    for (const r of rows) {
      const q=[1,2,3].map(k=>Math.round(r[k]/s));
      if (!q[0]&&!q[1]&&!q[2]) continue;
      idx.push(r[0]-prev); prev=r[0];
      for(let k=0;k<3;k++){d[k].push((q[k]-last[k])&0xffff);last[k]=q[k];}
    }
    meta.targets[key]=[start,idx.length-start,s];
  }
  const planes=(a:number[],hi:boolean)=>Uint8Array.from(a,v=>hi?v>>8:v&255);
  const data=encodePack(meta,{idx:Uint16Array.from(idx),xlo:planes(d[0],false),xhi:planes(d[0],true),ylo:planes(d[1],false),yhi:planes(d[1],true),zlo:planes(d[2],false),zhi:planes(d[2],true)});
  writeFileSync(join(OUT,"targets.pack"),data);
  return { targetCount:wanted.length, deltaCount:idx.length };
}
const base = buildBase();
const available = new Set(walk(join(MH,"targets")).filter(p=>p.endsWith(".target")).map(p=>relative(join(MH,"targets"),p).replace(/\.target$/,"")));
const sliders = buildSliders(available);
const targets = buildTargets(sliders.targets);
writeFileSync(join(OUT,"catalog.json"),JSON.stringify({sliders:sliders.groups}));
writeFileSync(join(OUT,"build-report.json"),JSON.stringify({base,targets,sliderCount:sliders.groups.reduce((n,g)=>n+g.sliders.length,0),makehumanRoot:MH},null,2)+"\n");
console.log("ARA_FITTING_DATA_OK",JSON.stringify({base,targets,sliderGroups:sliders.groups.length}));
