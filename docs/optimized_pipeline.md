# Optimized Pipeline

Date: 2026-04-25

## Goal

このリポジトリの前提は、「テーマ特化のカスタムスキーマを作り、Planetiler を地球惑星全体の規模で何度も回す」ことです。

やりたいことは単発のタイル生成ではなく、次の反復をできるだけ短い時間で回すことです。

1. 自然言語からテーマ案を作る
2. `schema.yml` を新規作成または修正する
3. Planetiler でベクトルタイルを生成する
4. 表示を確認する
5. また `schema.yml` を修正する
6. 再び生成して確認する

つまり最適化対象は「1回の最速ベンチ」ではなく、「planet 規模のデータを相手にした開発イテレーション全体」です。

このドキュメントは、その観点から、

- どこがボトルネックだったか
- なぜ pre-filter を入れたのか
- なぜ `simple` ではなく `complete_ways` になったのか
- なぜ `MBTiles` ではなく `PMTiles` を優先するのか
- JVM 最適化をどこまで一般化できるのか

を整理し、`planet-latest.osm.pbf` をそのまま Planetiler に投入していた初期構成から、現在の最適化後パイプラインに至るまでの判断と、既存ベンチで確認できた改善量をまとめたものです。

注意:

- この文書に新規計測は含まない。
- 数値は既存のベンチ結果のみを再構成した。
- 「full planet をそのまま Planetiler に投入していた時期は数時間かかっていた」という点は運用上の記憶であり、初期開発当時の厳密なベンチログはこのリポジトリ内に残っていない。
- ただし 2026-04-25 に、full planet をそのまま Planetiler に投入する `railways` baseline を再実行し、`64g container / 32g heap / MBTiles` で `53:09.41` の完走結果を取得した。
- 同日、より古い `20g container / 8g heap` 相当の legacy 設定も再実行し、`44:34.39` 時点の `archive` で `Java heap space` により失敗することを確認した。

## Before

最初の構成は概ね次の形だった。

1. `planet-latest.osm.pbf` をそのまま Planetiler に渡す。
2. 各テーマに無関係な地物も含め、Planetiler 側で全部読む。
3. 出力は主に `MBTiles`。

この構成では、Planetiler が full planet 規模の parse、sort、archive を毎回抱えるため、反復開発には重すぎた。

## After

現在の最適化後パイプラインは次の形に整理できる。

1. テーマごとに `osmium tags-filter` で入力 `pbf` を先に細らせる。
2. `railways` や `rivers` のような relation 依存が比較的弱いテーマは、planet を 16 分割したタイルに対して並列 `tags-filter` をかける。
3. `admins` のような relation-heavy なテーマは、従来どおり single-pass を維持する。
4. Planetiler に渡す入力は full planet ではなく、テーマ専用の軽量 `pbf` にする。
5. Planetiler の出力は `MBTiles` ではなく `PMTiles` を第一候補にする。

## Current Flow

### 1. One-time preprocessing

planet を `z2` 相当の 16 タイルに分割して永続保存する。

- 保存先: `data/planet_tiles/complete_ways/` など
- 目的:
  - 毎回 60GB 級 planet を single-pass で読み直さない
  - 以後の `tags-filter` をタイル単位で並列化する
  - 一度温まったページキャッシュを反復利用する

### 2. Theme pre-filter

各テーマで必要なタグだけを `osmium tags-filter` で抽出する。

- 安全にタイル並列化しやすいテーマ:
  - `railways`
  - `rivers`
  - `disaster_prevention`
  - `global_connectivity`
  - `global_seismic_alerts`
- single-pass 維持テーマ:
  - `admins`
- 理由:
  - `admins` は `boundary=administrative` の大きな relation が主体で、タイル分割と相性が悪い

### 3. Planetiler

Planetiler は pre-filter 後の小さな `pbf` のみを読む。

- full planet を直接処理しない
- 出力は `PMTiles` を優先する
- JVM 設定はテーマ依存の差があるため、一律に固定しない

### 4. Optional compatibility path

もし downstream が `MBTiles` を要求する場合は、必要に応じて `PMTiles -> MBTiles` 変換を行う。

- 変換例:
  - `tile-join -pk -f -o output.mbtiles input.pmtiles`

## Why We Chose This Design

### Decision 1: pre-filter を先に行う

一番大きな改善はここです。

- Planetiler は input `pbf` が大きいほど重くなる
- したがって、Planetiler に入る前に `osmium tags-filter` でテーマ無関係なオブジェクトを削るほど有利
- これは実運用でも、full planet 直投入の「数時間」から、テーマ別の十数分級まで落ちた体感と一致する

### Decision 2: `simple` ではなく `complete_ways`

途中で `osmium extract --strategy=simple` も試したが、最終判断は `complete_ways` になった。

extract 単体のベンチでは `simple` が速かった。

| Strategy | Elapsed | Total tile bytes |
| --- | ---: | ---: |
| `complete_ways` | `51:36.24` | `91,059,883,299` |
| `simple` | `31:27.09` | `91,003,745,462` |

しかし downstream の `railways` 比較では `simple` が欠落を出した。

| Variant | Elapsed | Nodes | Ways | Relations |
| --- | ---: | ---: | ---: | ---: |
| Single-pass on full planet | `13:54.57` | `38,524,371` | `4,132,842` | `28,295` |
| Tiled from `simple` + merge | `7:22.36` | `38,506,536` | `4,132,777` | `28,237` |
| Tiled from `complete_ways` + merge | `7:34.53` | `38,524,371` | `4,132,842` | `28,295` |

`simple` は次を落とした。

- `17,835` nodes
- `65` ways
- `58` relations

つまり、

- `simple` は速い
- しかし `railways` では single-pass と同等でなかった
- `complete_ways` は single-pass と object count が一致した

このため、初回 extract コストは重くても、実運用では `complete_ways` を採用する判断になった。

### Decision 3: `admins` は例外扱い

`admins` は巨大な行政 boundary relation を扱うため、他テーマと同じ「16 分割 + 並列 tags-filter」には乗せない。

この例外扱いにより、

- 安全なテーマだけを高速 path に乗せる
- relation-heavy テーマは correctness を優先する

という切り分けになった。

### Decision 4: archive の主戦場は `MBTiles` ではなく `PMTiles`

`railways-pre-filter` の archive フェーズを調べた結果、`PMTiles` 化が最も効いた。

比較ベースライン:

- `ZGC 32g + 64g container + MBTiles`: `9:04.00`

結果:

| Variant | Elapsed | Delta vs baseline | Size | Archive phase |
| --- | ---: | ---: | ---: | ---: |
| Baseline MBTiles | `9:04.00` | `0s` | `7.7G` | `4m40s` |
| `PMTiles` | `7:12.70` | `-1m51.30s` | `1.4G` | `1m57s` |
| `PMTiles + ZGC tuned` | `7:06.75` | `-1m57.25s` | `1.4G` | `2m` |

確認できたこと:

- `PMTiles` 単独で約 `20.5%` 改善
- 出力サイズは `7.7G -> 1.4G`
- 総タイル数は `357,913,941` で一致
- 改善の本体は `PMTiles` 化で、`ZGC tuned` の上積みは `5.95s` と小さい

よって、archive の観点では `PMTiles` を第一候補にするのが自然だった。

### Decision 5: JVM は一律最適化しない

JVM については、テーマごとに結果が逆転した。

| Theme | G1 32g / 40g | ZGC 32g / 64g | Outcome |
| --- | ---: | ---: | --- |
| `railways` | `9:57.22` | `9:04.00` | `ZGC 64g` が `53s` 速い |
| `rivers` | `11:19.44` | `13:24.64` | `G1` の方が `2m05s` 速い |

このため、

- `ZGC` は universal win ではない
- JVM の最適値はテーマ依存
- パイプラインの中核改善は JVM ではなく pre-filter と `PMTiles`

という整理になった。

## Measured Before/After

厳密に比較できる範囲の before/after を並べるとこうなる。

### Full-planet direct baseline

2026-04-25 に、最適化前に近い設定として次を再実行した。

- 基準にした commit: `762e0ca` (`2026-01-30`)
- 入力: full `planet-latest.osm.pbf`
- Theme: `railways`
- Container memory: `64g`
- Heap: `-Xms32g -Xmx32g`
- Output: `MBTiles`
- JFR: `data/benchmarks/railways-full-baseline-jfr-32g-64g.jfr`

結果:

| Variant | Result | Elapsed | Notes |
| --- | --- | ---: | --- |
| Full-planet direct baseline | completed | `53:09.41` | `MBTiles 7.7G`, JFR `241M`, tiles `357,913,941` |

補足:

- `overall`: `53m1s`, `gc: 10m16s`
- `osm_pass1`: `24m19s`, `gc: 9m5s`
- `osm_pass2`: `19m13s`, `gc: 20s`
- `sort`: `2m14s`
- `archive`: `5m19s`, `gc: 39s`
- `archive` phase 内では write が `76%` を占めていた
- ただし full-planet direct 全体では、`osm_pass1` と `osm_pass2` の方が大きく、input `pbf` を直接読ませる構成そのものが主要な重さになっている

これは「古い full-planet パイプラインでも動くようにメモリを積めば完走する」ことを示す一方で、現在の最適化後パイプラインより大幅に遅い。

参考として、同日に実行したより古いメモリ設定は次の通り失敗した。

| Variant | Result | Elapsed | Notes |
| --- | --- | ---: | --- |
| Legacy low-memory full-planet baseline | failed | `44:34.39` | `20g container / 8g heap`, `archive` で `Java heap space` |

この失敗 run では:

- `archive` は `0:43:28` に開始
- `0:43:53` 時点で `gc: 98%`
- `0:44:31` 時点で `gc: 100%`
- 失敗地点は `TileArchiveWriter` / `decodeVectorTileFeature`
- partial 出力 `data/benchmarks/railways-full-baseline-legacy.mbtiles` は `20K` のみ

### `railways` pre-filter step

| Step | Before | After | Improvement |
| --- | ---: | ---: | ---: |
| `osmium tags-filter` | `13:54.57` | `7:34.53` | `-6m20.04s` |

ここでの before は full planet single-pass、after は `complete_ways` タイル + 並列 `tags-filter` + merge。

### `railways` Planetiler archive step

| Step | Before | After | Improvement |
| --- | ---: | ---: | ---: |
| Planetiler archive-inclusive run | `9:04.00` | `7:12.70` | `-1m51.30s` |

ここでの before は `MBTiles`、after は `PMTiles`。

### `railways` end-to-end iteration

同じ `railways` について、full-planet direct baseline と現在の optimized pipeline を並べると次の通り。

| Pipeline | Pre-filter | Planetiler | Total |
| --- | ---: | ---: | ---: |
| Full-planet direct baseline | `N/A` | `53:09.41` | `53:09.41` |
| Optimized pipeline | `7:34.53` | `7:12.70` | `14:47.23` |

差分:

- `53:09.41 -> 14:47.23`
- `-38m22.18s`
- 約 `72.2%` 短縮

### `railways` iterative pipeline subtotal

`railways` の「pre-filter + Planetiler」の合計を、計測済みの最良な組み合わせで並べると次のとおり。

| Variant | Pre-filter | Planetiler | Total |
| --- | ---: | ---: | ---: |
| Earlier measured path | `13:54.57` | `9:04.00` | `22:58.57` |
| Optimized measured path | `7:34.53` | `7:12.70` | `14:47.23` |

差分は `-8m11.34s`、約 `35.6%` 短縮です。

なお `PMTiles + ZGC tuned` を採用すると `14:41.28` まで縮むが、`PMTiles` 単独との差は小さい。

## Recommended Pipeline

現時点での推奨は次のとおり。

1. 一回だけ `complete_ways` で planet をタイル分割して永続化する。
2. `railways` や `rivers` のような安全なテーマは、タイル並列 `tags-filter` を使う。
3. `admins` は single-pass のままにする。
4. Planetiler には pre-filter 後のテーマ別 `pbf` だけを渡す。
5. 出力は `PMTiles` を標準にする。
6. JVM はテーマ別に最適化する。未検証テーマに一律設定を押し付けない。

## What Remains Open

- すべてのテーマで「タイル並列 path が安全か」の検証は終わっていない
- `rivers` を含め、JVM 設定の最適値はテーマ別にまだ揺れる
- style / tileserver 側は、`PMTiles` 前提に完全移行するための整理余地がある
- 初期開発当時の full planet 直投入ベンチログは残っていない
- ただし、2026-04-25 に `railways` の full planet direct baseline を再取得し、比較可能な基準値として `53:09.41` を得た

## Related Notes

- [planet-tile-extract-comparison.md](/everything/src/github.com/yuiseki/planetiler-ai/docs/planet-tile-extract-comparison.md:1)
- [planetiler-jvm-comparison.md](/everything/src/github.com/yuiseki/planetiler-ai/docs/planetiler-jvm-comparison.md:1)
- [railways-archive-optimization-comparison.md](/everything/src/github.com/yuiseki/planetiler-ai/docs/railways-archive-optimization-comparison.md:1)
