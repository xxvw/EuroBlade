# EuroBlade — 開発・コンパイル・デバッグ

## 前提条件

- MetaTrader 5 (build 4000 以降推奨)
- MetaEditor (MT5 に同梱)

## ファイル配置

MT5 のデータフォルダ (`MQL5/`) に以下の構成でファイルを配置します。
データフォルダの場所は MT5 で **ファイル > データフォルダを開く** から確認できます。

```
MQL5/
├── Experts/
│   └── gridEA.mq5
└── Include/
    └── GridEA/
        ├── GridDashboard.mqh
        └── euroblade_icon.bmp
```

## コンパイル

### MetaEditor から

1. MetaEditor で `Experts/gridEA.mq5` を開く
2. **F7** キーを押す、またはメニューから **コンパイル** を選択
3. エラーパネルに `0 errors` と表示されれば成功
4. `Experts/gridEA.ex5` が生成される

コンパイル時にアイコン (`euroblade_icon.bmp`) が `#resource` ディレクティブにより `.ex5` バイナリに埋め込まれます。

### コマンドラインから

MetaEditor はコマンドラインコンパイルにも対応しています。

```batch
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"MQL5\Experts\gridEA.mq5" /log
```

ログは同じディレクトリに `.log` ファイルとして出力されます。

## デバッグ

### Print デバッグ

`Print()` 関数でジャーナルに情報を出力します。MT5 の **ツールボックス > エキスパート** タブで確認できます。

```mql5
Print("breakEven=", breakEven, " bid=", bid, " trailSL=", g_trailStopBuy);
```

### MetaEditor デバッガ

1. MetaEditor で `gridEA.mq5` を開く
2. ブレークポイントを設定したい行の左端をクリック（赤丸が表示される）
3. **F5** キーでデバッグモード開始
4. MT5 のストラテジーテスターが起動し、ブレークポイントで停止する
5. 変数の値をウォッチウィンドウで確認可能

### ストラテジーテスターでの検証

1. MT5 で **表示 > ストラテジーテスター** を開く
2. EA に `gridEA` を選択
3. 通貨ペア・期間・モデルを設定
4. **スタート** を押してバックテスト実行
5. 完了後、ジャーナルタブにサマリーが出力される

推奨テスト設定:

| 項目 | 推奨値 |
|---|---|
| モデル | 全ティック (Every tick) |
| 期間 | M15 以上 |
| スプレッド | 現在のスプレッド、または固定値 |
| 初期証拠金 | 100,000 JPY / 10,000 USD 以上 |

### ビジュアルモード

ストラテジーテスターの「ビジュアルモード」にチェックを入れると、チャート上でEAの動作を視覚的に確認できます。ダッシュボードやトレーリングSLの動作確認に便利です。

## コード構造

### gridEA.mq5

| セクション | 説明 |
|---|---|
| Input パラメータ | 基本設定・時間・トレーリング・MAフィルター |
| `OnInit()` | 初期化、認証、チャート色変更、ダッシュボード作成 |
| `OnDeinit()` | ダッシュボード破棄、チャート色復元 |
| `OnTick()` | 毎Tick: 売買ロジック・トレーリング。1分ごと: ダッシュボード更新 |
| `OnChartEvent()` | エントリーON/OFFボタンのクリック検知 |
| `OnTester()` | バックテスト完了時のサマリーログ出力 |
| `GetMATrend()` | 指定TFのMA傾きからトレンド方向を判定 |
| `IsEntryAllowedByMA()` | MAフィルターによるエントリー許可判定 |
| `CheckAndTrailGrid()` | トレーリングストップの判定・SL設定 |
| `ApplyLightModeChart()` | チャートをライトモードに変更 |
| `RestoreChartColors()` | チャート色を元に復元 |

### GridDashboard.mqh

`CGridDashboard` クラス。`OBJ_RECTANGLE_LABEL` と `OBJ_LABEL` を使ってチャート上にダッシュボードを描画します。

| メソッド | 説明 |
|---|---|
| `Create()` | 全オブジェクトを初期作成 |
| `Update()` | セッション・ポジション・週次損益・経済指標・トレーリング/MAを更新 |
| `SetEntryEnabled()` | ボタンの表示を切り替え |
| `Destroy()` | 全オブジェクトを削除 |

## 変更時の注意

- `GridDashboard.mqh` の `Update()` シグネチャを変更した場合、`gridEA.mq5` 内の全呼び出し箇所を更新すること
- 新しいダッシュボードオブジェクトを追加した場合、`Destroy()` の削除リストにも追加すること
- `#resource` で埋め込む BMP は **24bit RGB (アルファなし)** であること
