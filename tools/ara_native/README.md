# Native Ara garment generation

The original Ara bikini generator source is vendored at `vendor/src/core/garments/swimwear.ts`.

- Upstream: https://github.com/olatunde85/3d-gen
- Exact source revision: `b60b5bece6d383d2cbb7067fd50e7c8e68b5a395`
- Licence: MIT; see [vendor/LICENSE](vendor/LICENSE).
- The underlying MakeHuman character data used by Ara is separately CC0 1.0.

This source is the real Ara implementation (`bikiniBottom` and `bikiniTop`), not the earlier geometric reconstruction. It expects Ara's own semantic vertex-region labels, joint vertex sets, morphed base coordinates, normals and face topology.

**Not complete yet:** this commit only introduces the original generator source and its licence. It does not claim to generate a Wren garment. The remaining work is to vendor the required helper modules, build/load the CC0 MakeHuman fitting data locally, apply Wren's exact `wren-ara.json` morph profile, run the source locally, and transfer/validate the generated garment on the accepted Wren GLB. The existing Blender approximation must not be treated as a substitute.

The garment generator itself must not call Ara's hosted service or CLI.
