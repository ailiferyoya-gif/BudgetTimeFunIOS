# BudgetTimeFunIOS

現在地、金額、時間、気分を入力すると、その範囲内で楽しめる案を返す SwiftUI アプリの初期実装です。

## 構成

- `Package.swift`: iOS 17 以上向け Swift Package
- `Sources/BudgetTimeFun/BudgetTimeFunApp.swift`: SwiftUI アプリ本体
- `PreviewWeb/`: Windows 上でも挙動を確認できる静的プレビュー

## Xcode で開く

1. Xcode で `Package.swift` を開く
2. scheme に `BudgetTimeFun` を選ぶ
3. iOS Simulator を選択して Run

## 現時点の仕様

- 現在地はテキスト入力
- 金額は 0 円から 20,000 円まで 500 円単位
- 時間は 1 時間から 12 時間
- 気分は「ゆっくり」「動きたい」「発見したい」「食べたい」
- 条件に合う候補がない場合は、低予算の徒歩プランを提示

## 次にやること

- CoreLocation で現在地取得を追加
- MapKit または外部 API で周辺候補を実データ化
- 保存済みプラン、共有、履歴を追加
- ユーザーの移動手段や人数を入力条件に追加
