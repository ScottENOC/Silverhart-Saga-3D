#!/usr/bin/env node
/**
 * Execute the original Campaign 2 scene builder in a deterministic headless
 * compatibility sandbox and export its resolved geometry. This is an
 * inventory capture, not a claim that every generated terrain cell was
 * manually authored.
 */
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

function parseArgs(argv) {
  const result = {};
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--source") result.source = argv[++i];
    else if (argv[i] === "--out") result.out = argv[++i];
    else if (argv[i] === "--world-map-source") result.worldMapSource = argv[++i];
    else throw new Error("Unknown argument: " + argv[i]);
  }
  if (!result.source || !result.out) {
    throw new Error("Usage: node extract_campaign2_source_geometry.mjs --source FILE --out FILE");
  }
  return result;
}

const args = parseArgs(process.argv);
const sourceText = fs.readFileSync(args.source, "utf8");
const worldMapSourceText = args.worldMapSource ? fs.readFileSync(args.worldMapSource, "utf8") : "";
const overrideTerrain = {};
const terrainCellsByBuilder = {};
const terrainWriteCallsByBuilder = {};
const terrainCellsByWriter = {};
const terrainWriteCallsByWriter = {};
const windowState = {
  currentCampaign: "2",
  overrideTerrain,
  tileObjects: {},
  entities: [],
  party: [{ name: "Audit Player", race: "human", attributes: { agility: 10 }, inventory: [] }],
  exploredHexes: new Set(),
  lastSeenTimeMap: {},
  mapItems: {},
  musicPOIs: {},
  interiorRegions: [],
  multiStoryBuildings: [],
  campaign2Npcs: [],
  campaign2ArcherCompanion: { name: "Audit Archer", color: "#999999", race: "human", gender: "female", title: "Companion", dialogueId: "audit_archer" },
  campaign2WizardCompanion: { name: "Audit Wizard", color: "#999999", race: "human", gender: "female", title: "Companion", dialogueId: "audit_wizard" },
  campaign2DruidCompanion: { name: "Audit Druid", color: "#999999", race: "human", gender: "female", title: "Companion", dialogueId: "audit_druid" },
  campaign2BackgroundPatrons: [],
  campaign2FortSoldiers: [],
  regionalNPCs: {},
  regions: { hollowmere: { prosperity: 50 } },
  skills: {},
  factions: {},
  _campaign2NpcBaseline: {},
  _campaign2TerrainBaseline: {},
  _campaign2TileObjectsBaseline: {},
  worldMapData: Array.from({ length: 16 }, () =>
    Array.from({ length: 16 }, () => ({ n: "" }))),
  setTerrainAt(q, r, name) {
    const stack = new Error().stack || "";
    const frames = stack.split("\n").slice(1).map(line => {
      const match = line.match(/at (?:Object\.)?([A-Za-z_$][\w$]*)/);
      return match ? match[1] : "";
    }).filter(Boolean);
    const writer = frames.find(name => name !== "setTerrainAt" && name !== "campaign2World") || "unclassified";
    const helperNames = new Set([
      "setTerrainAt", "carveFlatRoom", "carveBuilding", "carveStarFort",
      "carveHexKeep", "carvePolygonRoom"
    ]);
    const builder = frames.find(name => /^(?:build[A-Z]|paint[A-Z]|setupVillageScene|openWallGap)/.test(name) && !helperNames.has(name)) || writer;
    const key = q + "," + r;
    this.overrideTerrain[key] = { name };
    if (!terrainCellsByBuilder[builder]) terrainCellsByBuilder[builder] = new Set();
    if (!terrainCellsByWriter[writer]) terrainCellsByWriter[writer] = new Set();
    terrainCellsByBuilder[builder].add(key);
    terrainCellsByWriter[writer].add(key);
    terrainWriteCallsByBuilder[builder] = (terrainWriteCallsByBuilder[builder] || 0) + 1;
    terrainWriteCallsByWriter[writer] = (terrainWriteCallsByWriter[writer] || 0) + 1;
  },
  setTerrainAtFloor() {},
  getTerrainAt(q, r) { return this.overrideTerrain[q + "," + r] || { name: "Grass" }; },
  getNeighbors(q, r) {
    return [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]]
      .map(([dq, dr]) => ({ q: q + dq, r: r + dr }));
  },
  pseudoRandom(x, y) {
    const value = Math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return value - Math.floor(value);
  },
  distance(a, b) {
    return Math.max(Math.abs(a.q - b.q), Math.abs(a.r - b.r),
      Math.abs((a.q + a.r) - (b.q + b.r)));
  },
  hexRound(q, r) { return { q: Math.round(q), r: Math.round(r) }; },
  isPlayerGreenskin() { return false; },
  seedFactionStandings() {},
  wireSharedInventory() {},
  placeSecretStash() {},
  placeSecretDoor() {},
  buildNPC(spec) { return { ...spec, alive: true, inventory: [], side: spec.side || "neutral" }; },
  createCharacterData(race, characterClass, name, gender) {
    return { race, class: characterClass, name, gender,
      attributes: { agility: 10, wildcard: 3 }, skills: {}, hp: 10, maxHp: 10 };
  },
  serializeEntity(entity) { return { ...entity }; },
  pickHairPreset() { return { hue: 0, lightMult: 1, satMult: 1 }; },
  pickClothingHue() { return 0; },
  pickNaturalSkinTone() { return "#c99"; },
  drawMap() {},
  renderEntities() {},
  showCharacter() {},
  updatePartyTabs() {},
  snapVisuals() {},
  centerCameraOn() {},
  showMessage() {},
  showDialogue() {},
  createMonster(kind, hex) { return { kind, hex, alive: true, inventory: [] }; },
  Entity: class {
    constructor(name, color, hex) { this.name = name; this.color = color; this.hex = hex; }
  },
};
const sandbox = {
  window: windowState,
  document: {
    getElementById() { return null; },
    querySelector() { return null; },
    createElement() { return { style: {}, classList: { add() {}, remove() {} } }; },
  },
  console, Math, JSON, Set, Map, Array, Object, Number, String, Boolean, Date,
  setTimeout() { return 0; },
  clearTimeout() {},
};
vm.createContext(sandbox);
if (worldMapSourceText) {
  try {
    vm.runInContext(worldMapSourceText, sandbox, {
      filename: path.basename(args.worldMapSource),
      timeout: 10000,
    });
    if (typeof windowState.loadWorldMap !== "function") {
      throw new Error("worldMap.js did not expose loadWorldMap");
    }
    windowState.loadWorldMap();
  } catch (error) {
    process.stderr.write("Strategic map extraction failed: " + error.stack + "\n");
    process.exit(1);
  }
}
const captureCode = [
  "setupVillageScene(true);",
  "JSON.stringify({",
  "terrain: window.overrideTerrain,",
  "tileObjects: window.tileObjects,",
  "worldMapData: window.worldMapData,",
  "worldRiverPath: window.worldRiverPath || [],",
  "interiors: window.interiorRegions,",
  "multiStoryBuildings: window.multiStoryBuildings,",
  "terrainBaseline: window._campaign2TerrainBaseline,",
  "tileObjectBaseline: window._campaign2TileObjectsBaseline,",
  "patrolPath: window.campaign2UnicornPatrolPath || [],",
  "landmarks: {",
  "farmstead: window.campaign2FarmHouseCenter || null,",
  "millbrook: window.campaign2MillbrookCenter || null,",
  "emberlode: window.campaign2EmberlodeCenter || null,",
  "reddale: window.campaign2ReddaleGuardhouseCenter || null,",
  "northwatch: window.campaign2NorthwatchCenter || null,",
  "ridgehold: window.campaign2RidgeholdCenter || null,",
  "greenskinCamp: window.campaign2GoblinCampCenter || null,",
  "greenskinHold: window.campaign2OrcStrongholdCenter || null,",
  "druidGrove: window.campaign2DruidGroveCenter || null,",
  "wolfDen: window.campaign2DruidGroveDenHex || null",
  "}",
  "})",
].join("\n");
let encoded;
try {
  encoded = vm.runInContext(sourceText + "\n" + captureCode, sandbox, {
    filename: path.basename(args.source),
    timeout: 30000,
  });
} catch (error) {
  process.stderr.write("Source scene extraction failed: " + error.stack + "\n");
  process.exit(1);
}
const captured = JSON.parse(encoded);
captured.terrainCellsByBuilder = Object.fromEntries(
  Object.entries(terrainCellsByBuilder).map(([name, cells]) => [name, Array.from(cells)])
);
captured.terrainWriteCallsByBuilder = terrainWriteCallsByBuilder;
captured.terrainCellsByWriter = Object.fromEntries(
  Object.entries(terrainCellsByWriter).map(([name, cells]) => [name, Array.from(cells)])
);
captured.terrainWriteCallsByWriter = terrainWriteCallsByWriter;
const terrainCounts = {};
for (const value of Object.values(captured.terrain)) {
  const name = value && value.name ? value.name : "UNNAMED";
  terrainCounts[name] = (terrainCounts[name] || 0) + 1;
}
const output = {
  schemaVersion: 1,
  source: {
    repository: "ScottENOC/Hex-crpg",
    commit: process.env.HEX_CRPG_SOURCE_COMMIT || "unspecified",
    file: path.basename(args.source),
    strategicMapFile: args.worldMapSource ? path.basename(args.worldMapSource) : null,
    builder: "setupVillageScene(true)",
  },
  classification: {
    warning: "Runtime-resolved source scene geometry. Terrain entries may include generated terrain; do not treat every terrain cell as a manually authored hex.",
    terrain: "unclassified_source_scene_terrain",
    tileObjects: "source_scene_physical_object_placements",
    interiors: "source_scene_interior_regions",
    multiStoryBuildings: "source_scene_multistory_definitions",
    worldMapData: "source_strategic_map_cells_after_campaign2_bootstrap",
    worldRiverPath: "source_strategic_river_waypoints",
  },
  counts: {
    terrainCells: Object.keys(captured.terrain).length,
    terrainByName: terrainCounts,
    terrainCellsByBuilder: Object.fromEntries(
      Object.entries(captured.terrainCellsByBuilder).map(([name, cells]) => [name, cells.length])
    ),
    terrainWriteCallsByBuilder: captured.terrainWriteCallsByBuilder,
    terrainCellsByWriter: Object.fromEntries(
      Object.entries(captured.terrainCellsByWriter).map(([name, cells]) => [name, cells.length])
    ),
    tileObjectPlacements: Object.keys(captured.tileObjects).length,
    interiorRegions: captured.interiors.length,
    multiStoryBuildings: captured.multiStoryBuildings.length,
    unicornPatrolWaypoints: captured.patrolPath.length,
    strategicMapRows: Array.isArray(captured.worldMapData) ? captured.worldMapData.length : 0,
    strategicMapColumns: Array.isArray(captured.worldMapData) && captured.worldMapData.length ? captured.worldMapData[0].length : 0,
    strategicMapCells: Array.isArray(captured.worldMapData) ? captured.worldMapData.reduce((sum, row) => sum + row.length, 0) : 0,
    strategicRiverWaypoints: Array.isArray(captured.worldRiverPath) ? captured.worldRiverPath.length : 0,
    strategicMapMarkers: Array.isArray(captured.worldMapData) ? captured.worldMapData.flat().filter(cell => cell && cell.n).length : 0,
  },
  ...captured,
};
fs.mkdirSync(path.dirname(args.out), { recursive: true });
fs.writeFileSync(args.out, JSON.stringify(output, null, 2) + "\n");
process.stdout.write(JSON.stringify(output.counts, null, 2) + "\n");
