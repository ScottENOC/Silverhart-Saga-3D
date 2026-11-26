#!/usr/bin/env python3
"""Read-only audit of the Ara character GLBs. Standard library only.

Reports, per GLB: skeleton size, animation clip count, and how many bones the runtime retargeter
(scripts/presentation/ara_skeleton_retargeter.gd) would map onto it, using the same rule: a bone maps
when the carrier skeleton has a bone of the same name with the same parent name.
Also lists clips present in the player bodies but absent from the carrier.

Usage: python3 tools/review/audit_ara_animations.py [repo_root]
Import-time properties such as clip loop mode cannot be read from a GLB; see tools/review/ara_layering_probe.
"""
import glob
import json
import os
import struct
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
CARRIER = "art/characters/ara_runtime/ara_person_benchmark.glb"
PATTERNS = [
	"art/characters/companions/*.glb",
	"art/characters/hollowmere/*.glb",
	"art/characters/ara_runtime/*.glb",
]
RETARGET_THRESHOLD = 20  # AraCharacterActor.configure(): fewer mapped bones leaves the native rig unmodified


def load_gltf_json(path):
	with open(path, "rb") as handle:
		handle.read(12)
		chunk_length, _ = struct.unpack("<I4s", handle.read(8))
		return json.loads(handle.read(chunk_length))


def skeleton(gltf):
	if not gltf.get("skins"):
		return None
	nodes = gltf["nodes"]
	parent = {}
	for index, node in enumerate(nodes):
		for child in node.get("children", []):
			parent[child] = index
	return {nodes[j]["name"]: (nodes[parent[j]]["name"] if j in parent else "") for j in gltf["skins"][0]["joints"]}


def clip_names(gltf):
	return [a["name"] for a in gltf.get("animations", [])]


def main():
	carrier_gltf = load_gltf_json(os.path.join(ROOT, CARRIER))
	carrier = skeleton(carrier_gltf)
	carrier_clips = set(clip_names(carrier_gltf))
	print("%-60s %5s %6s %5s  %s" % ("file", "bones", "mapped", "clips", "runtime result"))
	player_clips = set()
	for pattern in PATTERNS:
		for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
			gltf = load_gltf_json(path)
			bones = skeleton(gltf)
			relative = os.path.relpath(path, ROOT)
			if bones is None:
				print("%-60s %5s %6s %5d  no skin" % (relative, "-", "-", len(clip_names(gltf))))
				continue
			mapped = sum(1 for name, parent in bones.items() if carrier.get(name) == parent and name in carrier)
			result = "retargets onto carrier" if mapped >= RETARGET_THRESHOLD else "falls back to native rig"
			print("%-60s %5d %6d %5d  %s" % (relative, len(bones), mapped, len(clip_names(gltf)), result))
			if "ara_player_" in relative:
				player_clips |= set(clip_names(gltf))
	extra = sorted(player_clips - carrier_clips)
	print("\nCarrier clips: %d. Clips in the player bodies but not in the carrier: %d (unreachable through AraCharacterActor)." % (len(carrier_clips), len(extra)))
	for name in extra:
		print("  " + name)


if __name__ == "__main__":
	main()
