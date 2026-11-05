/**
 * Export one selected Ara material group as an independent skinned GLB.
 * All exports use the same body parameters and therefore the same rig layout.
 *
 * Usage:
 *   npx tsx scripts/export-modular-component.ts params.json output.glb "Skin,Skin details"
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { mkdirSync } from 'node:fs';
import { buildHuman, textureFiles } from '../src/core/human';
import { DEFAULT_PARAMS, type HumanParams } from '../src/core/params';
import { pickGroups } from '../src/core/mesh';
import { exportGLB } from '../src/export/glb';
import { nodeLibrary } from './node-assets';

const [paramsPath, outputPath, materialList] = process.argv.slice(2);
if (!paramsPath || !outputPath || !materialList) {
  throw new Error('Usage: export-modular-component.ts params.json output.glb "Material A,Material B"');
}
const wanted = new Set(materialList.split(',').map((s) => s.trim()).filter(Boolean));
const lib = await nodeLibrary();
const params = { ...DEFAULT_PARAMS, ...JSON.parse(readFileSync(paramsPath, 'utf8')) } as HumanParams;
const ch = await buildHuman(lib, params);
const selected = new Set<number>();
ch.mesh.groups.forEach((group, index) => {
  const name = ch.mesh.materials[group.material]?.name;
  if (name && wanted.has(name)) selected.add(index);
});
if (!selected.size) {
  throw new Error('No groups matched: ' + Array.from(wanted).join(', ') +
    '. Available: ' + ch.mesh.materials.map((m) => m.name).join(', '));
}
const mesh = pickGroups(ch.mesh, (index) => selected.has(index));
if (!ch.rig || !mesh.joints || !mesh.weights) {
  throw new Error('Component must be skinned to the canonical game rig: ' + outputPath);
}
const names = textureFiles(mesh);
const textures = new Map<string, Uint8Array>();
for (const name of names) textures.set(name, await lib.texture(name));
const bytes = exportGLB(mesh, params.name, textures, ch.rig, []);
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, bytes);
writeFileSync(outputPath.replace(/\.glb$/i, '.json'), JSON.stringify({
  name: params.name,
  height_metres: ch.height,
  rig_bones: ch.rig?.bones.map((b) => ({ name: b.name, parent: b.parent >= 0 ? ch.rig!.bones[b.parent].name : null })) ?? [],
  materials: [...wanted],
  groups: [...selected],
  vertices: mesh.positions.length / 3,
  triangles: mesh.groups.reduce((sum, group) => sum + group.indices.length / 3, 0),
}, null, 2));
console.log('Exported ' + outputPath + ': ' + (mesh.positions.length / 3) +
  ' vertices, ' + mesh.groups.length + ' primitives, ' + (ch.rig?.bones.length ?? 0) + ' bones.');
