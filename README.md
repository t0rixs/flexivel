# Flexivel

旅程が破綻したとき、代替プランを提案するモバイルアプリです。

## 概要

- 旅行の予定（場所・開始時刻・終了時刻）を登録
- 15分ごとに現在地と時刻から、次の予定に間に合うかを自動チェック
- 破綻が検出されると、代替プラン（次の予定へ直行 / 寄り道先 / スキップ）を提案

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| フロントエンド | Flutter (Dart) |
| バックエンド | NestJS (TypeScript) — Cloud Run でホスティング済み |
| データベース | Cloud Firestore |
| 外部 API | Google Places API, Google Routes API, Gemini API |

## セットアップ

### 前提条件

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x 以上)
- iOS: Xcode + CocoaPods
- Android: Android Studio + Android SDK

### インストール

```bash
git clone https://github.com/t0rixs/flexivel.git
cd flexivel/frontend
flutter pub get
```

### 起動

```bash
cd frontend
flutter run
```

> バックエンド API は Cloud Run 上にデプロイ済みのため、ローカルでのバックエンド起動は不要です。

### カスタム API サーバーの指定（任意）

ローカルでバックエンドを動かす場合は、環境変数で API URL を上書きできます:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## プロジェクト構成

```
frontend/
├── lib/
│   ├── main.dart              # エントリーポイント
│   ├── models/                # データモデル
│   ├── screens/               # 画面 (旅程画面, 予定作成画面)
│   ├── services/              # API通信, Firestore, 位置情報
│   ├── state/                 # 状態管理 (TripState)
│   └── widgets/               # 共通ウィジェット (タイムライン, モーダル等)
├── android/                   # Android 固有設定
├── ios/                       # iOS 固有設定
└── pubspec.yaml               # 依存関係
```

## デバッグモード

Flutter のデバッグモード (`kDebugMode`) で以下の機能が有効になります:

- 現在時刻の手動オーバーライド
- 現在地の手動オーバーライド
- 破綻チェックの手動実行ボタン
