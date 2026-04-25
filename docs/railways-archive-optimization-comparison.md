# Railways Archive Optimization Comparison

Date: 2026-04-25

## Goal

`railways-pre-filter` の `archive` フェーズを高速化するため、次の条件を比較した。

- Baseline: `ZGC 32g + 64g container + MBTiles`
- 1. `PMTiles` 出力
- 2. `ZGC` 追加フラグ
- 3. `PMTiles + ZGC` 追加フラグ

## Baseline

- Target: `railways-pre-filter-zgc-32g-container-64g`
- Elapsed: `9:04.00`
- Output: `data/benchmarks/railways-pre-filter-zgc-32g-container-64g.mbtiles`
- Size: `7.7G`
- Tile count (`sqlite3 ... select count(*) from tiles_shallow`): `357,913,941`
- Planetiler summary:
  - `overall 8m46s ... gc:4m10s`
  - `archive 4m40s ... gc:1m59s`

## Results

| Variant | Elapsed | Delta vs baseline | Output | Size | Archive phase |
| --- | ---: | ---: | --- | ---: | ---: |
| Baseline MBTiles | `9:04.00` | `0s` | `mbtiles` | `7.7G` | `4m40s` |
| 1. PMTiles | `7:12.70` | `-1m51.30s` | `pmtiles` | `1.4G` | `1m57s` |
| 2. ZGC tuned | `10:15.35` | `+1m11.35s` | `mbtiles` | `7.7G` | `5m24s` |
| 3. PMTiles + ZGC tuned | `7:06.75` | `-1m57.25s` | `pmtiles` | `1.4G` | `2m` |

## Variant 1: PMTiles

- Target: `railways-pre-filter-pmtiles-zgc-64g`
- Output: `data/benchmarks/railways-pre-filter-pmtiles-zgc-64g.pmtiles`
- JFR: `data/benchmarks/railways-pre-filter-pmtiles-zgc-64g.jfr`
- Elapsed: `7:12.70`
- Size: `1.4G`
- Planetiler summary:
  - `overall 6m56s ... gc:6m3s`
  - `archive 1m57s ... gc:2m35s`
- Tile count check:
  - MBTiles baseline: `357,913,941`
  - PMTiles addressed tiles: `357,913,941`
  - Result: match

Note:
- `PMTiles` では Planetiler ログに `# addressed tiles: 357913941` が出る。
- `pmtiles show --header-json` は今回の CLI では tile count を返さなかったため、総タイル数は Planetiler のログ値を採用した。

## Variant 2: ZGC tuned

- Target: `railways-pre-filter-zgc-tuned-64g`
- JVM flags:
  - `-XX:+UseZGC`
  - `-XX:ZCollectionInterval=0.5`
  - `-XX:ZUncommitDelay=0`
  - `-Xms32g -Xmx32g`
- Output: `data/benchmarks/railways-pre-filter-zgc-tuned-64g.mbtiles`
- JFR: `data/benchmarks/railways-pre-filter-zgc-tuned-64g.jfr`
- Elapsed: `10:15.35`
- Size: `7.7G`
- Planetiler summary:
  - `overall 9m58s ... gc:9m16s`
  - `archive 5m24s ... gc:5m23s`

## Variant 3: PMTiles + ZGC tuned

- Target: `railways-pre-filter-pmtiles-zgc-tuned-64g`
- JVM flags:
  - `-XX:+UseZGC`
  - `-XX:ZCollectionInterval=0.5`
  - `-XX:ZUncommitDelay=0`
  - `-Xms32g -Xmx32g`
- Output: `data/benchmarks/railways-pre-filter-pmtiles-zgc-tuned-64g.pmtiles`
- JFR: `data/benchmarks/railways-pre-filter-pmtiles-zgc-tuned-64g.jfr`
- Elapsed: `7:06.75`
- Size: `1.4G`
- Planetiler summary:
  - `overall 6m49s ... gc:7m`
  - `archive 2m ... gc:2m48s`
- Tile count check:
  - MBTiles baseline: `357,913,941`
  - PMTiles addressed tiles: `357,913,941`
  - Result: match

## Conclusion

- 一番効いたのは `PMTiles` 化で、baseline 比 `1m51.30s` 短縮、約 `20.5%` 改善だった。
- `archive` 単体でも `4m40s` から `1m57s` に大きく短縮した。
- `ZGC` の追加フラグは逆効果で、baseline より `1m11.35s` 遅くなった。
- `PMTiles + ZGC tuned` は最速で、baseline 比 `1m57.25s` 短縮、約 `21.6%` 改善だった。
- ただし `PMTiles` 単独との差は `5.95s` しかなく、改善の本体は `PMTiles` 化で、`ZGC tuned` の上積みは小さい。
- 実運用の第一候補は `PMTiles` 出力。`ZGC tuned` を重ねるかは、JFR の再確認と再現性を見て決めるのが妥当。

## Note

- `PMTiles -> MBTiles` が必要になった場合は、`felt/tippecanoe` の `tile-join` で `tile-join -pk -f -o output.mbtiles input.pmtiles` のように変換できる。
