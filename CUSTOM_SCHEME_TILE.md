# Planetiler カスタムスキーマでグローバルベクトルタイル作成ガイド

このガイドでは、Planetilerを使用してカスタムスキーマでグローバルスケールのベクトルタイルを作成し、tileserver-glで配信する方法について説明します。

## 概要

このプロジェクトでは、OpenStreetMapデータから世界規模の鉄道ネットワークを抽出し、zoom 0から14までの全ズームレベルで可視化可能なベクトルタイルを作成します。

## 必要な環境

- Docker
- 20GB以上のメモリ
- OSMデータ（planet-latest.osm.pbf）
- Java 8以上（Docker内で実行）

## ステップ1: データの準備

### 1.1 OSMデータの取得

```bash
# Planet OSMデータをダウンロード
wget https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf -O data/planet-latest.osm.pbf
```

## ステップ2: スキーマ定義の作成

### 2.1 Planetilerスキーマファイル（railways.yml）

```yaml
schema_name: Railways
schema_description: Railways (merged & un-merged lines, z0-14)
attribution: <a href="https://www.openstreetmap.org/copyright" target="_blank">&copy; OpenStreetMap contributors</a>

sources:
  osm:
    type: osm
    local_path: /data/planet-latest.osm.pbf

layers:
  - id: railways_low
    features:
      - source: osm
        geometry: line
        min_zoom: 0
        max_zoom: 3
        include_when:
          railway: __any__
    tile_post_process:
      merge_line_strings:
        min_length: 0
        tolerance: -1
        buffer: -1

  - id: railways_merged
    features:
      - source: osm
        geometry: line
        min_zoom: 4
        include_when:
          railway: __any__
    tile_post_process:
      merge_line_strings:
        min_length: 0
        tolerance: -1
        buffer: -1

  - id: railways_unmerged
    features:
      - source: osm
        geometry: line
        min_zoom: 4
        include_when:
          railway: __any__
```

### 2.2 スキーマの重要なポイント

- **railways_low**: zoom 0-3での低解像度表示用（線の統合あり）
- **railways_merged**: zoom 4以上での統合された線
- **railways_unmerged**: zoom 4以上での元の線形状
- **merge_line_strings**: 線の統合処理設定

## ステップ3: ベクトルタイルの生成

### 3.1 実行スクリプト（run_railways.sh）

```bash
#!/bin/bash
docker run \
    -u `id -u`:`id -g` \
    --memory 20g --memory-swap -1 \
    -e JAVA_TOOL_OPTIONS="-Xms8g -Xmx8g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        generate-custom \
        --schema=/data/railways.yml \
        --output=/data/railways.mbtiles \
        --force
```

### 3.2 実行

```bash
chmod +x run_railways.sh
./run_railways.sh
```

## ステップ4: スタイル定義の作成

### 4.1 Mapbox GL JSスタイル（railways.json）

```json
{
  "version": 8,
  "name": "Railways Minimal",
  "sources": {
    "railways": {
      "type": "vector",
      "url": "mbtiles://{railways}"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f0f0f0"
      }
    },
    {
      "id": "railways_merged_line",
      "type": "line",
      "source": "railways",
      "source-layer": "railways_merged",
      "paint": {
        "line-color": "#ff0000",
        "line-width": 1
      }
    },
    {
      "id": "railways_unmerged_line",
      "type": "line",
      "source": "railways",
      "source-layer": "railways_unmerged",
      "paint": {
        "line-color": "#0000ff",
        "line-width": 1
      }
    },
    {
      "id": "railways_low_line",
      "type": "line",
      "source": "railways",
      "source-layer": "railways_low",
      "paint": {
        "line-color": "#00ff00",
        "line-width": 1
      }
    }
  ]
}
```

## ステップ5: tileserver-gl設定

### 5.1 設定ファイル（config.json）

```json
{
  "options": {
    "paths": {
      "root": "",
      "fonts": "fonts",
      "sprites": "",
      "styles": "",
      "mbtiles": ""
    },
    "formatQuality": {
      "jpeg": 80,
      "webp": 90,
      "pngQuantization": false,
      "png": 90
    },
    "maxSize": 2048,
    "pbfAlias": "pbf",
    "serveAllFonts": true
  },
  "styles": {
    "railways": {
      "style": "railways.json"
    }
  },
  "data": {
    "railways": {
      "mbtiles": "railways.mbtiles"
    }
  }
}
```

### 5.2 tileserver-glの起動

```bash
# tileserver-glをDockerで起動
docker run -it -v $(pwd)/data:/data -p 8080:8080 \
    maptiler/tileserver-gl \
    --config /data/config.json
```

## ステップ6: 動作確認

1. ブラウザで `http://localhost:8080` にアクセス
2. "railways" スタイルを選択
3. 世界地図上で鉄道ネットワークが表示されることを確認

## 技術的なポイント

### メモリ設定
- Docker: 20GB RAM + unlimited swap
- JVM: 8GB heap memory

### ズームレベル戦略
- **zoom 0-3**: 統合された簡略化線（railways_low）
- **zoom 4+**: 統合線（railways_merged）と元線（railways_unmerged）の両方

### 線の統合処理
- `merge_line_strings`: 隣接する線分を統合してタイル容量を削減
- `tolerance: -1`: 自動設定
- `buffer: -1`: 自動設定

## カスタマイズの応用例

### 他の地物への適用
```yaml
# 道路の例
layers:
  - id: roads
    features:
      - source: osm
        geometry: line
        min_zoom: 0
        max_zoom: 14
        include_when:
          highway: [primary, secondary, tertiary]
```

### 属性の追加
```yaml
# 鉄道種別を含める例
layers:
  - id: railways_detailed
    features:
      - source: osm
        geometry: line
        min_zoom: 6
        include_when:
          railway: __any__
        attributes:
          - key: railway
          - key: gauge
          - key: electrified
```

## トラブルシューティング

### メモリ不足
- `--memory`と`JAVA_TOOL_OPTIONS`のメモリ設定を調整
- データサイズに応じてヒープサイズを変更

### 生成時間の短縮
- より小さなOSMデータ（地域データ）でテスト
- `--bounds`オプションで処理範囲を限定

### スタイルの確認
- `railways.json`のレイヤー名がスキーマのlayer idと一致していることを確認
- ブラウザの開発者ツールでタイルリクエストを確認

このガイドに従うことで、カスタムスキーマによる世界規模のベクトルタイルシステムを構築できます。