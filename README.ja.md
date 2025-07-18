# planetiler-ai

惑星規模のカスタムな地図ベクトルタイルを生成するAIエージェントのプルーフ・オブ・コンセプト

---

## AIが作成した地図の例

### 世界中の川だけの地図
[https://tile.yuiseki.net/styles/rivers/#1/0/0](https://tile.yuiseki.net/styles/rivers/#1/0/0)

[![Image from Gyazo](https://i.gyazo.com/94e93ff6e5e60fa48cf649c635d89833.png)](https://tile.yuiseki.net/styles/rivers/#1/0/0)

### 世界中の鉄道だけの地図
[https://tile.yuiseki.net/styles/railways/#1/0/0](https://tile.yuiseki.net/styles/railways/#1/0/0)

[![Image from Gyazo](https://i.gyazo.com/6edfbe4ff7eff9a8bcaa4e439450a6a5.png)](https://tile.yuiseki.net/styles/railways/#1/0/0)

---


## 背景

2023年の12月に、私は `charites-ai` というAIエージェントを開発しました。

- https://github.com/yuiseki/charites-ai

`charites-ai` は、既存の OpenMapTiles スキーマの地図ベクトルタイルのスタイルを、自然言語で生成することができるAIエージェントでした。

いま、次の段階に進むときが来ました。

OpenMapTiles スキーマは、人類が地図ベクトルタイルを閲覧する際の最高のベストプラクティスであり、デファクトスタンダードとなっています。

しかし、いまや、地図ベクトルタイルを閲覧し、あるいはデータとして活用するのは、もはや人類だけではありません。AIたちも地図ベクトルタイルを利用します。

私は、既存の OpenMapTiles スキーマに縛られることなく、AIエージェントが、自分自身や人類たちのために、目的や状況に応じたカスタムなスキーマでより用途に特化した多様な地図ベクトルタイルを作り出すことができるはずだと考えました。また、そのように、AIエージェントに自律的に様々な地図ベクトルタイルを構築させるチャレンジには重要な意義があるのではないかと考えました。

このソフトウェア、 `planetiler-ai` は、そのようなAIエージェントが実現可能であるということを示すために作られました。

## 概要

`planetiler-ai` は、AIエージェントが特定の目的に特化したカスタムベクトルタイルを自律的に生成するための、Proof-of-Concept（概念実証）プロジェクトです。

このプロジェクトは、[Planetiler](https://github.com/onthegomap/planetiler) をコアエンジンとして利用し、OpenStreetMap (OSM) や Natural Earth といったオープンな地理空間データソースから、必要な地物（例: 鉄道、河川、水域など）だけを抽出した軽量なベクトルタイル（`.mbtiles`）を生成します。

生成されたタイルは、[MapTiler Server](https://documentation.maptiler.com/hc/en-us/articles/4405443334417-MapTiler-Server) を通じて配信され、地図として可視化できます。

AIエージェントは、このフレームワークの規約に従って新しいテーマ（スキーマとスタイル）を追加し、実行スクリプトを生成することで、人間を介さずに新しい地図を次々と作り出すことが可能です。

## 特徴

-   **AIによる自律的な地図生成**: AIエージェントが自らスキーマを定義し、タイル生成と配信設定までを完結させるワークフローを想定しています。
-   **カスタムスキーマ**: OpenMapTilesのような汎用スキーマに縛られず、特定の用途（例: 鉄道網の分析、水系の可視化）に最適化された独自のタイルセットを構築できます。
-   **Planetilerベース**: 高速で柔軟なベクトルタイル生成エンジンである Planetiler を活用しています。
-   **Docker化された環境**: `planetiler` と `tileserver-gl` をDockerコンテナとして実行するため、環境構築が容易です。

## 使い方

このプロジェクトは、AIエージェントが利用することを主な目的としていますが、人間が手動で実行することも可能です。`CUSTOM_SCHEME_TILE.md` には、AIエージェントが新しいテーマを追加するための詳細な手順が記述されています。

### 既存のテーマでタイルを生成する例（河川）

1.  **必要なデータをダウンロードします。**
    -   プロジェクトの規約に従い、`data` ディレクトリに `planet-latest.osm.pbf` を配置してください。

2.  **スキーマファイルを `data` ディレクトリにコピーします。**
    ```bash
    cp theme/rivers/schema.yml data/rivers.yml
    ```

3.  **タイル生成スクリプトを実行します。**
    （この処理には時間がかかり、多くのメモリを消費します）
    ```bash
    chmod +x run_rivers.sh
    ./run_rivers.sh
    ```
    成功すると `data/rivers.mbtiles` が生成されます。

4.  **タイルサーバーを起動します。**
    ```bash
    docker-compose up -d
    ```

5.  **ブラウザで確認します。**
    -   `http://localhost:8000` にアクセスすると、タイルサーバーの管理画面が表示されます。
    -   スタイルを適用するには、`data/config.json` を編集し、`data/rivers.json` を参照するように設定を追加する必要があります。

## ディレクトリ構造

```
.
├── data/                  # 生成されたタイルやデータソースを格納するディレクトリ
├── sources/               # データソースの定義 (Natural Earthなど)
├── theme/                 # 各カスタムテーマのスキーマとスタイルを格納するディレクトリ
│   ├── railways/
│   │   ├── schema.yml     # 鉄道テーマのスキーマ定義
│   │   └── style.json     # 鉄道テーマのスタイル定義
│   ├── rivers/
│   │   └── ...
│   └── water/
│       └── ...
├── CUSTOM_SCHEME_TILE.md  # AIエージェント向けのカスタムテーマ追加ガイド
├── run_*.sh               # 各テーマのタイルを生成するための実行スクリプト
└── docker-compose.yml     # タイルサーバーを起動するための設定ファイル
```


