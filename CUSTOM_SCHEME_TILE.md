# AIエージェント向け Planetilerカスタムテーマ追加ガイド

このドキュメントは、AIエージェントがPlanetilerを使用して新しいカスタムベクトルタイルテーマを追加するための、最小限の必須手順を記述したものです。

---

## プロジェクト哲学: 価値ある地図を作成するための3つの原則

このプロジェクト `planetiler-ai` のポテンシャルを最大限に引き出すためには、以下の3つの原則が重要です。AIエージェントは、新しいテーマを提案・作成する際に、常にこれらの原則を念頭に置く必要があります。

1.  **OpenStreetMap (OSM) を最大限に活用する**
    -   OSMは、このプロジェクトの基盤となる最も重要なデータソースです。その膨大で詳細なデータを深く理解し、創造的な方法で活用することで、ユニークで価値のある洞察を引き出すことができます。単なる地物のマッピングに留まらず、タグの組み合わせやリレーションを分析し、これまで可視化されてこなかった関係性やパターンを見つけ出すことを目指してください。

2.  **OSM以外のグローバルソースを積極的に活用する**
    -   OSMだけでは表現できない地球規模の現象を捉えるため、世界全体をカバーするオープンなデータソースを常に探し、積極的に活用してください。Natural Earthのような確立されたものだけでなく、各分野の専門機関が公開するデータセット（例: 気象、海洋、エネルギー、経済など）を組み合わせることで、地図に多層的で専門的な深みを与えることができます。

3.  **Zoom 0での視覚的インパクトを最大化する**
    -   作成する地図は、Zoom 0、つまり地球全体を俯瞰したときに、そのテーマが持つ最も重要なメッセージが一目で伝わるような、強力な視覚的インパクトを持つべきです。低ズームレベルでは大胆な単純化と象徴的な表現を用い、ズームインするにつれて詳細な情報が現れるようにスキーマとスタイルを設計してください。地球規模の課題や洞察を、直感的かつ美しく伝えることが重要です。

---

## 必須の前提条件

- `data/planet-latest.osm.pbf` が存在すること。

---

## トラブルシューティング: よくある間違い

Planetilerのスキーマ定義は非常に柔軟ですが、その分、特定の規約に従わないとエラーが発生しやすくなります。以下は、AIエージェントが陥りがちな間違いとその解決策です。

1.  **`sources` の形式が違う (`Cannot deserialize... from Array value`)**
    -   **問題**: `sources` を配列（リスト）で定義している。Planetilerはキーを持つマップ形式を期待します。
    -   **解決策**: 各データソースの `name` をトップレベルのキーとして使用します。
        ```yaml
        # 誤り
        sources:
          - name: osm
            type: osm
            ...
        # 正解
        sources:
          osm:
            type: osm
            ...
        ```

2.  **OSMファイルのパス指定が違う (`Unrecognized field "path"`)**
    -   **問題**: OSMデータソースのパスを `path` で指定している。
    -   **解決策**: 正しいキーは `local_path` です。
        ```yaml
        # 誤り
        osm:
          type: osm
          path: /data/planet-latest.osm.pbf
        # 正解
        osm:
          type: osm
          local_path: /data/planet-latest.osm.pbf
        ```

3.  **レイヤー構造が違う (`Unrecognized field "source_layer"`)**
    -   **問題**: `layers` の直下に `source` や `source_layer` を定義している。
    -   **解決策**: 各レイヤー定義 (`id`) の中に `features` リストを作成し、その中で地物の詳細（`source`, `geometry`, `include_when` など）を定義します。`source_layer` は `features` のプロパティではなく、`include_when` の中で使用します。
        ```yaml
        # 誤り
        - id: "land"
          source: natural_earth
          source_layer: "ne_50m_land"
          geometry: polygon
        # 正解
        - id: "land"
          features:
            - source: natural_earth
              geometry: polygon
              include_when:
                '${ feature.source_layer }': ne_50m_land
        ```

4.  **リモートソースの `type` が違う (`Cannot deserialize... from String "url"`)**
    -   **問題**: URLから取得するデータソースの `type` を `url` にしている。
    -   **解決策**: `type` には `url` ではなく、データの種類（`shapefile`, `geopackage` など）を指定します。
        ```yaml
        # 誤り
        natural_earth:
          type: url
          url: https://.../ne_50m_land.zip
        # 正解
        natural_earth:
          type: shapefile
          url: https://.../ne_50m_land.zip
        ```

5.  **データソースがダウンロードされない (`... does not exist. Run with --download`)**
    -   **問題**: スクリプト実行時にリモートのデータソース（Natural Earthなど）が見つからない。
    -   **解決策**: `run_{THEME_NAME}.sh` 内の `generate-custom` コマンドに `--download` フラグを追加します。
        ```bash
        generate-custom \\
            ...
            --download \\
            --force
        ```

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
