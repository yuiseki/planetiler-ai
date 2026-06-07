# Planetiler JVM Comparison

Date: 2026-04-25

## Setup

- Heap: `32g`
- Compared configurations:
  - `G1`: `-Xms32g -Xmx32g` with `40g` container memory
  - `ZGC (40g)`: `-XX:+UseZGC -Xms32g -Xmx32g` with `40g` container memory
  - `ZGC (64g)`: `-XX:+UseZGC -Xms32g -Xmx32g` with `64g` container memory

## Summary

| Theme | G1 32g / 40g | ZGC 32g / 40g | ZGC 32g / 64g | Outcome |
| --- | ---: | --- | ---: | --- |
| `railways` | `9:57.22` | failed (`137`) | `9:04.00` | `ZGC 64g` is faster by `53s` (`8.9%`) |
| `rivers` | `11:19.44` | not run | `13:24.64` | `ZGC 64g` is slower by `2m05s` (`18.4%`) |

## Railways

Input: `data/planet-railways.osm.pbf`

### Results

| JVM options | Container memory | Result | Elapsed | Planetiler overall GC |
| --- | --- | --- | ---: | ---: |
| `-Xms32g -Xmx32g` | `40g` | Success | `9:57.22` | `1m4s` |
| `-XX:+UseZGC -Xms32g -Xmx32g` | `40g` | Failed (`137`) | `9:43.69` | n/a |
| `-XX:+UseZGC -Xms32g -Xmx32g` | `64g` | Success | `9:04.00` | `4m10s` |

### Notes

- `G1` output: `data/benchmarks/railways-pre-filter-g1-32g.mbtiles` (`7.7G`)
- `ZGC 40g` partial output: `data/benchmarks/railways-pre-filter-zgc-32g.mbtiles` (`3.7G`)
- `ZGC 40g` failed during `archive z14`
- `ZGC 64g` output: `data/benchmarks/railways-pre-filter-zgc-32g-container-64g.mbtiles` (`7.7G`)
- Planetiler summary:
  - `G1`: `overall 9m53s ... gc:1m4s`
  - `ZGC 64g`: `overall 8m46s ... gc:4m10s`

## Rivers

Input: `data/planet-rivers.osm.pbf`

### Results

| JVM options | Container memory | Result | Elapsed | Planetiler overall GC |
| --- | --- | --- | ---: | ---: |
| `-Xms32g -Xmx32g` | `40g` | Success | `11:19.44` | `1m36s` |
| `-XX:+UseZGC -Xms32g -Xmx32g` | `64g` | Success | `13:24.64` | `6m59s` |

### Notes

- `G1` output: `data/benchmarks/rivers-pre-filter-g1-32g.mbtiles` (`11G`)
- `ZGC 64g` output: `data/benchmarks/rivers-pre-filter-zgc-32g-container-64g.mbtiles` (`11G`)
- Planetiler summary:
  - `G1`: `overall 11m15s ... gc:1m36s`
  - `ZGC 64g`: `overall 13m7s ... gc:6m59s`

## Conclusion

`ZGC` is not a universal win.

- For `railways`, `ZGC + 64g container` is a real improvement.
- For `rivers`, the same setting is clearly worse than `G1`.
- `ZGC + 40g container` is not safe for `railways` because it can die late in archive.
- The current evidence supports theme-specific tuning rather than switching every theme to `ZGC + 64g`.
