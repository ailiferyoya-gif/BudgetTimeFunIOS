# BudgetTimeFunIOS

現在地、金額、時間、目的を入力すると、その範囲内で楽しめる案と周辺候補を返す SwiftUI アプリの初期実装です。

## 構成

- `Package.swift`: iOS 17 以上向け Swift Package
- `Sources/BudgetTimeFun/BudgetTimeFunApp.swift`: SwiftUI アプリ本体
- `PreviewWeb/`: GitHub Pages で確認できる静的プレビュー

## 機能

- CoreLocation で現在地を取得
- MapKit `MKLocalSearch` で目的別の周辺候補を検索
- 候補名、距離、所要時間、予算目安をカード表示
- 候補詳細から地図を開く
- 徒歩 / 公共交通の移動手段を切り替え
- 時間と予算が十分な場合、名古屋発の京都・犬山など移動込み候補を表示
- 目的地は駅やバス停ではなく、店、寺社、公園、市場、美術館など楽しめる場所に限定
- Web プレビューでは OpenStreetMap の地図に現在地と候補ピンを表示
- Web プレビューではブラウザ Geolocation と OpenStreetMap Overpass API で周辺の楽しめる候補を表示
- Google Maps の徒歩ルート / 公共交通ルートを開くリンクを表示

## Xcode で開く

1. Xcode で `Package.swift` を開く
2. scheme に `BudgetTimeFun` を選ぶ
3. iOS Simulator または実機を選択して Run

位置情報を使うには、アプリ側の Info 設定に `NSLocationWhenInUseUsageDescription` が必要です。Xcode のターゲット設定で「現在地周辺の遊び先を提案するために位置情報を使用します。」のような説明文を追加してください。

## Web 確認

https://ailiferyoya-gif.github.io/BudgetTimeFunIOS/PreviewWeb/

ブラウザで現在地取得を許可すると、目的と移動手段に合わせた周辺候補が地図付きで表示されます。現在地名に `名古屋` や `名古屋駅` を入力し、公共交通・3時間・8,000円前後にすると京都方面などの遠出候補も表示されます。
