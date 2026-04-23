# flutter_app

`pingpong-record` の Flutter 版を別フォルダーで作り直すための土台です。

## 現在の状態

- Android 向け Flutter プロジェクトを新規作成済み
- `lib/main.dart` はデモではなく、既存アプリの 3 機能に合わせた仮画面へ差し替え済み
- 既存の `app.py` や `pinpon.db` には手を入れていません

## 想定する移植順

1. `matches` / `tag_definitions` / `form_drafts` の SQLite スキーマを Flutter 側へ移植
2. `試合結果の登録` 画面を先に実装
3. `履歴と編集` を実装
4. `分析・ダッシュボード` を実装
5. バックアップ入出力を実装

## 実行

```bash
cd flutter_app
flutter pub get
flutter run
```

## 補足

- 既存の Python/Streamlit 版は比較対象として残しています
- Flutter 版はこのフォルダー内で独立して進める想定です
