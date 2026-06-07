# Planet Tile Extract Comparison

This note compares `osmium extract` on the same `planet-latest.osm.pbf` with two strategies:

- `complete_ways`
- `simple`

The purpose was to evaluate whether tiled preprocessing for parallel `osmium tags-filter` should use `complete_ways` or `simple`.

## Result Summary

| Strategy | Command shape | Elapsed | CPU | Max RSS | Total tile bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| `complete_ways` | 16-tile z2 extract | `51:36.24` | `357%` | `55.5 GB` | `91,059,883,299` |
| `simple` | 16-tile z2 extract | `31:27.09` | `437%` | `32.9 GB` | `91,003,745,462` |

- `simple` reduced wall-clock time by about `39.1%`.
- `complete_ways / simple` elapsed ratio was about `1.64x`.
- Output size difference was only `56,137,837` bytes, about `0.062%` of the `complete_ways` total.

## Interpretation

- `complete_ways` is materially slower because it is not just a faster/smaller variant of the same work. Its later phase becomes much more CPU and write heavy.
- `simple` produced nearly the same total tile size for this global z2 split.
- For the current experiment goal, `simple` is the better default for tiled preprocessing before parallel `osmium tags-filter`.

## Runtime Behavior

### `complete_ways`

Observed in two phases:

- Early phase:
  - `osmium` CPU usage was around `158%`
  - reads were around `44 MB/s`
  - `iowait` was near `0%`
  - storage `%util` was low
- Later phase:
  - `osmium` CPU usage rose to about `585%`
  - reads were about `76 MB/s`
  - writes were about `65 MB/s`
  - `md0` hit `100% util`
  - system `iowait` rose to about `5%`

This matches the intuition that `complete_ways` has a more expensive later phase for way/relation completion and output writing.

### `simple`

- The run stayed closer to a straightforward one-pass scan.
- It still took over 30 minutes on the current planet, so extract is not "cheap", but it is much more acceptable as a preprocessing step than `complete_ways`.

## Tile Size Distribution

Both strategies produced very skewed tile sizes with the equal z2 split:

- Largest tile: `tile_32.osm.pbf`
  - `complete_ways`: `29,259,384,048`
  - `simple`: `29,244,088,985`
- Smallest tile: `tile_00.osm.pbf`
  - `complete_ways`: `2,735,116`
  - `simple`: `2,714,641`

This means the current `4x4` equal split is good enough for a first benchmark, but not ideal for load balancing. Any later optimization should consider non-uniform tile boundaries.

## Per-Tile Size Difference

All `simple` tiles were slightly smaller than `complete_ways`, but only by a small margin.

Largest absolute per-tile difference:

- `tile_32.osm.pbf`: `15,295,063` bytes smaller with `simple`

Largest relative per-tile difference:

- `tile_02.osm.pbf`: about `1.145%` smaller with `simple`

For the large populated tiles, the relative differences were mostly around `0.03%` to `0.10%`.

## Practical Conclusion

For the tiled preprocessing experiment:

1. Keep `admins` on the single-pass path.
2. Do not treat `simple` as a drop-in replacement without downstream validation.
3. Run `osmium tags-filter` in parallel on the persistent tile set.
4. Revisit tile boundaries later, because the current z2 split is heavily imbalanced.

## Downstream Check: `railways`

To check whether the two extract strategies are safe for the actual workflow, `wr/railway` was filtered in three ways:

| Variant | Elapsed | Output size | Nodes | Ways | Relations |
| --- | ---: | ---: | ---: | ---: | ---: |
| Single-pass on full planet | `13:54.57` | `567,891,340` | `38,524,371` | `4,132,842` | `28,295` |
| Tiled from `simple` + merge | `7:22.36` | `567,738,123` | `38,506,536` | `4,132,777` | `28,237` |
| Tiled from `complete_ways` + merge | `7:34.53` | `567,891,287` | `38,524,371` | `4,132,842` | `28,295` |

### What this means

- Both tiled variants were much faster than the single-pass filter.
  - `simple` path: about `47.0%` faster
  - `complete_ways` path: about `45.5%` faster
- But only the `complete_ways` tiled path preserved the same object counts as the single-pass baseline.
- The `simple` tiled path dropped:
  - `17,835` nodes
  - `65` ways
  - `58` relations

So for `railways`, the extract benchmark alone is not enough to choose the strategy. The faster `simple` extract is attractive, but it is not semantically equivalent in the downstream filtered output.

### Current decision

- Use `complete_ways` when exact equivalence to the full-planet `wr/railway` result matters.
- Keep `simple` as an experimental path only if a theme can tolerate this loss, or if later validation shows the missing objects do not affect Planetiler output in practice.

## Notes

- The first `complete_ways` run was produced before the directory layout was normalized and is stored under `data/planet_tiles_z2/`.
- The `simple` run is stored under `data/planet_tiles/simple/`.
- The next cleanup step should move strategy-specific tile outputs under `data/planet_tiles/<strategy>/`.
