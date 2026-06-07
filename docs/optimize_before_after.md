# Optimize Before / After

Date: 2026-04-26

## Goal

この文書は、`railways` を例にして、このリポジトリのパイプライン最適化が `before` と `after` でどれだけ効いたかを短く整理するためのものです。

対象は、theme-specific schema を何度も修正しながら回す開発ループです。

## Before

最初の構成は次の形だった。

1. `planet-latest.osm.pbf` をそのまま Planetiler に入力する
2. pre-filter しない
3. 出力は `MBTiles`

この構成の `railways` baseline は、2026-04-25 の再計測で次の結果になった。

| Variant | Elapsed | Output |
| --- | ---: | --- |
| Full-planet direct baseline | `53:09.41` | `MBTiles 7.7G` |

補足:

- JFR: [railways-full-baseline-jfr-32g-64g.jfr](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-full-baseline-jfr-32g-64g.jfr:1)
- time log: [railways-full-baseline-jfr-32g-64g.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-full-baseline-jfr-32g-64g.time.txt:1)
- この baseline は `64g container / 32g heap` でようやく完走した
- `20g container / 8g heap` の古い相当設定では `44:34.39` 時点の `archive` で OOM した

## After

現在の最適化後パイプラインは次の形です。

1. `osmium tags-filter` でテーマ専用 `pbf` を作る
2. `complete_ways` で 16 タイルに分割して並列 `tags-filter` を回す
3. Planetiler には pre-filter 後の `pbf` だけを渡す
4. 出力は `PMTiles`
5. `railways` では `ZGC + 64g container` を使う

## Main Result

### Steady-state iteration

普段の開発ループでは、one-time の tile extract を除いた反復時間が重要です。

| Pipeline | Pre-filter | Planetiler | Total |
| --- | ---: | ---: | ---: |
| Before: full planet direct | `N/A` | `53:09.41` | `53:09.41` |
| After: optimized pipeline | `7:34.53` | `7:12.70` | `14:47.23` |

改善量:

- `53:09.41 -> 14:47.23`
- `-38:22.18`
- 約 `72.2%` 短縮
- 約 `3.60x` 高速化

### One-time full pipeline with best osmium

`osmium` の fork build `/home/yuiseki/Workspaces/repos/_yuiseki/_fork/osmium-tool/build/osmium` を使って、tile extract から Planetiler まで全部込みでも比較した。

| Pipeline | Extract | Filter | Merge | Planetiler | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before: full planet direct | `N/A` | `N/A` | `N/A` | `53:09.41` | `53:09.41` |
| After: optimized one-shot with best osmium | `32:44.88` | `7:07.87` | `0:08.66` | `7:44.35` | `47:45.76` |

改善量:

- `53:09.41 -> 47:45.76`
- `-5:23.65`
- 約 `10.2%` 短縮
- 約 `1.11x` 高速化

ここでの Planetiler は、比較条件を揃えるため `--bounds=planet` を付けた run の `7:44.35` を採用している。
`bounds` を付けないと addressed tiles が減ってしまい、full-planet baseline と正しく比較できないためです。

## What Actually Mattered

効いた順に並べると、主因は次の通り。

1. pre-filter 導入
2. `complete_ways` タイル化による `tags-filter` 並列化
3. `PMTiles` 化
4. `railways` 向け JVM 調整

特に大きかったのは、Planetiler に full planet を直接読ませるのをやめたことです。

## What Did Not Change Much

`best osmium` は one-shot 全体では効いたが、steady-state の反復ループでは劇的ではなかった。

- 既存 optimized baseline: `14:47.23`
- `best osmium` steady-state 相当: `15:00.88`

つまり、

- `extract` を毎回やる比較では意味がある
- tile cache を使う普段の反復では、主役はやはり pre-filter と `PMTiles`

## Files

- [optimized_pipeline.md](/everything/src/github.com/yuiseki/planetiler-ai/docs/optimized_pipeline.md:1)
- [railways-archive-optimization-comparison.md](/everything/src/github.com/yuiseki/planetiler-ai/docs/railways-archive-optimization-comparison.md:1)
- [railways-full-baseline-jfr-32g-64g.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-full-baseline-jfr-32g-64g.time.txt:1)
- [railways-optimized-pipeline-best-extract.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-optimized-pipeline-best-extract.time.txt:1)
- [railways-optimized-pipeline-best-filter.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-optimized-pipeline-best-filter.time.txt:1)
- [railways-optimized-pipeline-best-merge.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-optimized-pipeline-best-merge.time.txt:1)
- [railways-optimized-pipeline-best-planetbounds.time.txt](/everything/src/github.com/yuiseki/planetiler-ai/data/benchmarks/railways-optimized-pipeline-best-planetbounds.time.txt:1)
