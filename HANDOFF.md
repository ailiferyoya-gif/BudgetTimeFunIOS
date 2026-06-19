# 引継ぎ文

## 作業状況

`BudgetTimeFunIOS` として、現在地・金額・時間・目的から遊び方と周辺候補を提案する iOS アプリの初期実装を作成した。

## 変更点

- SwiftUI 側に CoreLocation の現在地取得を追加
- 現在地取得後、MapKit `MKLocalSearch` で目的別に周辺候補を検索
- 候補カードに場所名、住所、距離、予算、所要時間を表示
- 候補詳細から地図を開ける導線を追加
- Web プレビューにブラウザ Geolocation と OpenStreetMap Overpass API 検索を追加
- GitHub Pages で Web プレビューを確認可能

## 未完了事項

- この環境には Xcode / `xcodebuild` がないため、iOS ビルド確認は未実施
- Swift Package をアプリとして実行する際、Xcode 側で `NSLocationWhenInUseUsageDescription` の追加確認が必要
- 周辺検索の費用・所要時間は概算ロジック

## 次にやること

1. Mac の Xcode で `Package.swift` を開いてビルド確認する
2. 位置情報許可文言をターゲット Info に追加する
3. MapKit 検索結果のカテゴリや費用推定を調整する
4. 候補保存、共有、人数、移動手段、天候条件を追加する
