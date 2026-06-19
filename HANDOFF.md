# 引継ぎ文

## 作業状況

`BudgetTimeFunIOS` として、現在地・金額・時間・気分から遊び方を提案する iOS アプリの初期実装を作成した。

## 変更点

- Swift Package 形式で iOS 17 以上向けの SwiftUI アプリを追加
- `PlannerView` に現在地入力、金額 Stepper、時間 Stepper、気分 Picker、提案カード一覧を実装
- 条件に応じて候補を絞り込む `PlanGenerator` を実装
- 提案詳細を sheet で表示
- Windows 上で雰囲気を確認するための `PreviewWeb` を追加

## 未完了事項

- この環境には `xcodebuild` と `swift` がないため、iOS ビルド確認は未実施
- 現在地は手入力のみで、CoreLocation の実装は未追加
- 周辺スポットは固定カタログで、実店舗や地図 API 連携は未追加

## 次にやること

1. Mac の Xcode で `Package.swift` を開いてビルド確認する
2. CoreLocation と位置情報許可文言を追加する
3. MapKit または検索 API で現在地周辺の実データ提案に置き換える
4. 予算内訳、移動時間、人数、天候などの条件を増やす
