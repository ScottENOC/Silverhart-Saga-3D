/**
 * Silverhart's split-hair exporter for the pinned Ara 3D Gen source.
 *
 * Exports one hairless base body per sex and standalone, skinned hairstyle GLBs.
 * Hair is selected by material group from the generator's MeshData, preserving
 * JOINTS_0/WEIGHTS_0 and the exact Ara skeleton. Hair colours remain runtime tints.
 */
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildHuman } from '../src/core/human';
import { pickGroups } from '../src/core/mesh';
import { DEFAULT_PARAMS, PRESETS, type HumanParams } from '../src/core/params';
import { exportCharacter } from '../src/export';
import { exportGLB } from '../src/export/glb';
import { nodeLibrary } from './node-assets';

const args = process.argv.slice(2);
const option = (name: string) => {
  const index = args.indexOf(`--${name}`);
  return index < 0 ? undefined : args[index + 1];
};
const output = option('out') ?? 'out/hair';
const curated = [
  'short01', 'short02', 'short03', 'short04',
  'afro01', 'bob01', 'bob02', 'braid01', 'long01', 'ponytail01',
  'buzz', 'mohawk', 'cornrows', 'box_braids',
];
const hairMaterial = /^(hair|hair spikes|braids|buzz cut)$/i;

const lib = await nodeLibrary();
mkdirSync(output, { recursive: true });
const manifest: Record<string, unknown> = {
  schema_version: 1,
  generator: 'Ara 3D Gen',
  generator_commit: 'b60b5bece6d383d2cbb7067fd50e7c8e68b5a395',
  coordinate_system: '+Y up; metres; character faces +Z',
  skinning: 'standalone hair mesh retains Ara skeleton JOINTS_0 and WEIGHTS_0',
  colour: 'runtime material tint; no per-colour geometry exports',
  characters: {},
};

for (const sex of ['female', 'male'] as const) {
  const presetName = sex === 'female' ? 'Athletic woman' : 'Athletic man';
  const base: HumanParams = {
    ...DEFAULT_PARAMS,
    ...PRESETS[presetName],
    name: `ara_${sex}_base`,
    hair: 'none',
    outfit: 'none',
    top: 'none',
    jacket: 'none',
    bottom: 'none',
    shoes: 'none',
    hat: 'none',
    weapon: 'none',
    animations: false,
    faceBones: false,
    faceShapes: false,
    speechShapes: false,
    detail: 'high',
  };
  const baseCharacter = await buildHuman(lib, base);
  if (!baseCharacter.rig) throw new Error(`${sex} base export has no rig`);
  const baseFile = await exportCharacter(lib, baseCharacter, 'glb');
  writeFileSync(join(output, `${sex}_base.glb`), baseFile.data);

  const genderTag = sex;
  const catalogHair = lib.catalog.hair
    .filter((item) => {
      const tags = item.tags.map((tag) => tag.toLowerCase());
      const genderTags = tags.filter((tag) => tag === 'male' || tag === 'female');
      return genderTags.length === 0 || genderTags.includes(genderTag);
    })
    .map((item) => item.id);
  const available = curated.filter((id) =>
    ['buzz', 'mohawk', 'cornrows', 'box_braids'].includes(id) || catalogHair.includes(id),
  );
  const assets: Record<string, unknown> = {};
  for (const style of available) {
    const params: HumanParams = { ...base, name: `ara_${sex}_${style}`, hair: style };
    const character = await buildHuman(lib, params);
    if (!character.rig) throw new Error(`${sex}/${style} has no rig`);
    const hairMesh = pickGroups(character.mesh, (group) => {
      const material = character.mesh.materials[character.mesh.groups[group].material];
      return hairMaterial.test(material.name.trim());
    });
    if (!hairMesh.groups.length || !hairMesh.joints || !hairMesh.weights) {
      console.warn(`Skipping ${sex}/${style}: no skinned hair groups were emitted`);
      continue;
    }
    const textureNames = [...new Set(hairMesh.materials.flatMap((material) =>
      [material.map, material.normalMap, material.roughnessMap].filter((name): name is string => !!name),
    ))];
    const textures = new Map<string, Uint8Array>();
    for (const name of textureNames) textures.set(name, await lib.texture(name));
    const data = exportGLB(hairMesh, `ara_${sex}_${style}`, textures, character.rig);
    const filename = `${sex}_${style}.glb`;
    writeFileSync(join(output, filename), data);
    assets[style] = {
      file: filename,
      size_bytes: data.byteLength,
      sha256: createHash('sha256').update(data).digest('hex'),
      vertices: hairMesh.positions.length / 3,
      triangles: hairMesh.groups.reduce((sum, group) => sum + group.indices.length / 3, 0),
      materials: hairMesh.materials.map((material) => material.name),
      bones: character.rig.bones.map((bone) => bone.name),
    };
    console.log(`Built ${sex}/${style}: ${hairMesh.positions.length / 3} vertices, ${hairMesh.groups.length} material groups`);
  }
  (manifest.characters as Record<string, unknown>)[sex] = {
    base: `${sex}_base.glb`,
    base_bones: baseCharacter.rig.bones.map((bone) => bone.name),
    hairstyles: assets,
  };
}
writeFileSync(join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Wrote Ara split-hair bundle to ${output}`);
