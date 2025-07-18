# AIエージェント向け Planetilerカスタムテーマ追加ガイド

このドキュメントは、AIエージェントがPlanetilerを使用して新しいカスタムベクトルタイルテーマを追加するための、最小限の必須手順を記述したものです。

---

## 必須の前提条件

- `data/planet-latest.osm.pbf` が存在すること。

---

## 新規テーマ追加ワークフロー

新しいテーマ `{THEME_NAME}` を追加する手順は、以下の3ステップで構成されます。

### ステップ1: テーマアセットの作成 (`theme/{THEME_NAME}/`)

新しいテーマの定義ファイルを作成します。作業を効率化し、一貫性を保つために、`theme` ディレクトリ内の既存テーマ（例: `railways`）をコピーし、それを基に変更を加えることを強く推奨します。

1.  **スキーマ定義 (`schema.yml`) の作成**
    -   `theme/{THEME_NAME}/schema.yml` を作成します。
    -   **目的**: OpenStreetMapやその他のデータソースからどのデータを抽出し、どのようなレイヤー構造にするかを定義します。
    -   **必須項目**:
        -   `schema_name`, `schema_description`, `attribution`
        -   `sources`: データソースを定義します。
            -   **OSM**: プロジェクトの規約として、`/data/planet-latest.osm.pbf` を `osm` ソースとして必ず含めます。
            -   **Natural Earth**: 低ズームレベルの背景地図用に `natural_earth` をURLソースとして含めることが標準です。
            -   **その他のソース**: 必要に応じて、GeoPackageやShapefileなどの追加のベクターソースを利用できます。データは `data` ディレクトリ配下に配置するか、URLで指定することで、Planetilerが利用可能になります。
        -   `layers`:
            -   背景用の `land`, `ocean`, `lakes` レイヤーをNatural Earthソースから定義します。
            -   主題となる地物（例: `waterway: river`）をOSMソースから抽出するレイヤーを定義します。

2.  **スタイル定義 (`style.json`) の作成**
    -   `theme/{THEME_NAME}/style.json` を作成します。
    -   **目的**: `schema.yml` で定義したレイヤーをどのように視覚的にレンダリングするか（色、線の太さなど）を定義します。
    -   **重要な規約**:
        -   `sources` オブジェクトのキーは `{THEME_NAME}` とし、`url` は `mbtiles://{{THEME_NAME}}` と規約に従って設定します。
        -   `layers` の `source` は `{THEME_NAME}` とし、`source-layer` は `schema.yml` で定義した `id` と一致させます。

### ステップ2: ベクトルタイルの生成

定義したスキーマに基づいて `.mbtiles` ファイルを生成します。

1.  **実行スクリプト (`run_{THEME_NAME}.sh`) の作成**
    -   `run_{THEME_NAME}.sh` をプロジェクトルートに作成します。
    -   **目的**: PlanetilerのDockerコンテナを実行し、タイルを生成します。
    -   **スクリプト内容**:
        ```bash
        #!/bin/bash
        docker run \
            -u `id -u`:`id -g` \
            --memory 20g --memory-swap -1 \
            -e JAVA_TOOL_OPTIONS="-Xms8g -Xmx8g" \
            -v "$(pwd)/data":/data \
            ghcr.io/onthegomap/planetiler:latest \
                generate-custom \
                --schema=/data/{THEME_NAME}.yml \
                --output=/data/{THEME_NAME}.mbtiles \
                --force
        ```

2.  **生成プロセスの実行**
    以下のコマンドを順番に実行します。
    ```bash
    # 1. スキーマファイルをdataディレクトリにコピー
    cp theme/{THEME_NAME}/schema.yml data/{THEME_NAME}.yml

    # 2. 実行権限を付与
    chmod +x run_{THEME_NAME}.sh

    # 3. タイル生成を実行（時間がかかります）
    ./run_{THEME_NAME}.sh
    ```

### ステップ3: タイルサーバーの設定

生成したタイルとスタイルをタイルサーバーで配信できるように設定します。

1.  **スタイルファイルのコピー**
    -   スタイルファイルを `data` ディレクトリにコピーします。
    ```bash
    cp theme/{THEME_NAME}/style.json data/{THEME_NAME}.json
    ```

2.  **設定ファイル (`config.json`) の更新**
    -   `data/config.json` を編集し、`styles` と `data` の両方のオブジェクトに新しいテーマのエントリを追加します。
    -   **`styles` オブジェクトに追加:**
        ```json
        "{\"THEME_NAME\"}": {
          "style": "{\"THEME_NAME\"}.json"
        }
        ```
    -   **`data` オブジェクトに追加:**
        ```json
        "{\"THEME_NAME\"}": {
          "mbtiles": "{\"THEME_NAME\"}.mbtiles"
        }
        ```

以上の手順で、新しいカスタムテーマの追加は完了です。
