import CoreLocation
import MapKit
import SwiftUI

@main
struct BudgetTimeFunApp: App {
    var body: some Scene {
        WindowGroup {
            PlannerView()
        }
    }
}

struct PlannerInput: Equatable {
    var locationName = "現在地"
    var budget = 3000
    var hours = 3
    var mood: Mood = .relax
}

enum Mood: String, CaseIterable, Identifiable {
    case relax = "ゆっくり"
    case active = "動きたい"
    case culture = "発見したい"
    case food = "食べたい"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .relax: "leaf"
        case .active: "figure.walk"
        case .culture: "sparkles"
        case .food: "fork.knife"
        }
    }

    var searchQuery: String {
        switch self {
        case .relax: "cafe park spa"
        case .active: "park bowling amusement"
        case .culture: "museum gallery bookstore"
        case .food: "restaurant cafe market"
        }
    }

    var baseCost: Int {
        switch self {
        case .relax: 1400
        case .active: 1200
        case .culture: 1600
        case .food: 2200
        }
    }

    var baseMinutes: Int {
        switch self {
        case .relax: 110
        case .active: 120
        case .culture: 100
        case .food: 90
        }
    }
}

struct LocatedPoint: Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlanIdea: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let cost: Int
    let minutes: Int
    let steps: [String]
    let tags: [String]
    let systemImage: String
    let placeName: String?
    let address: String?
    let distanceMeters: Double?
    let mapURL: URL?
}

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locatedPoint: LocatedPoint?
    @Published var statusText = "現在地は未取得です"
    @Published var isRequesting = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        isRequesting = true
        statusText = "現在地を取得しています..."

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isRequesting = false
            statusText = "位置情報の利用が許可されていません"
        @unknown default:
            isRequesting = false
            statusText = "位置情報の状態を確認できません"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isRequesting = false
            statusText = "現在地を取得できませんでした"
            return
        }

        locatedPoint = LocatedPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        isRequesting = false
        statusText = "現在地を取得しました"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
        statusText = "現在地取得に失敗しました: \(error.localizedDescription)"
    }
}

enum SearchState: Equatable {
    case idle
    case loading
    case loaded([PlanIdea])
    case failed(String)
}

struct PlannerView: View {
    @StateObject private var locationProvider = LocationProvider()
    @State private var input = PlannerInput()
    @State private var selectedIdea: PlanIdea?
    @State private var searchState: SearchState = .idle

    private var fallbackIdeas: [PlanIdea] {
        PlanGenerator.fallbackIdeas(for: input)
    }

    private var displayedIdeas: [PlanIdea] {
        if case .loaded(let ideas) = searchState, !ideas.isEmpty {
            return ideas
        }
        return fallbackIdeas
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputPanel
                    locationPanel
                    summaryStrip
                    ideasSection
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .navigationTitle("予算時間プラン")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedIdea) { idea in
                IdeaDetailView(idea: idea, location: input.locationName)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: input.mood) {
                refreshNearbyPlaces()
            }
            .onChange(of: input.budget) {
                refreshNearbyPlaces()
            }
            .onChange(of: input.hours) {
                refreshNearbyPlaces()
            }
            .onChange(of: locationProvider.locatedPoint) {
                if locationProvider.locatedPoint != nil {
                    input.locationName = "現在地周辺"
                    refreshNearbyPlaces()
                }
            }
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("条件", systemImage: "slider.horizontal.3")
                .font(.headline)

            TextField("現在地名", text: $input.locationName)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("金額", systemImage: "yensign.circle")
                    Spacer()
                    Text(input.budget, format: .currency(code: "JPY"))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $input.budget, in: 0...20000, step: 500) {
                    Text("500円単位で調整")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("時間", systemImage: "clock")
                    Spacer()
                    Text("\(input.hours)時間")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $input.hours, in: 1...12) {
                    Text("1時間単位で調整")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("目的", selection: $input.mood) {
                ForEach(Mood.allCases) { mood in
                    Label(mood.rawValue, systemImage: mood.systemImage)
                        .tag(mood)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var locationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "location.viewfinder")
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(AppPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(AppPalette.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("現在地から探す")
                        .font(.headline)
                    Text(locationProvider.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                locationProvider.requestCurrentLocation()
            } label: {
                Label(locationProvider.isRequesting ? "取得中" : "現在地を取得", systemImage: "location")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(locationProvider.isRequesting)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summaryStrip: some View {
        FlowLayout(spacing: 8) {
            InfoPill(icon: "mappin.and.ellipse", value: input.locationName)
            InfoPill(icon: "banknote", value: "最大\(input.budget)円")
            InfoPill(icon: "timer", value: "\(input.hours)時間以内")
            InfoPill(icon: input.mood.systemImage, value: input.mood.rawValue)
        }
        .font(.caption)
    }

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("おすすめ案")
                    .font(.title2.bold())
                Spacer()
                Text("\(displayedIdeas.count)件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if case .loading = searchState {
                ProgressView("周辺の場所を検索しています")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if case .failed(let message) = searchState {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(displayedIdeas) { idea in
                Button {
                    selectedIdea = idea
                } label: {
                    IdeaCard(idea: idea)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func refreshNearbyPlaces() {
        guard let point = locationProvider.locatedPoint else {
            searchState = .idle
            return
        }

        let input = input
        searchState = .loading

        Task {
            do {
                let ideas = try await LocationSearchService.search(input: input, point: point)
                searchState = .loaded(ideas)
            } catch {
                searchState = .failed("周辺検索に失敗しました。固定プランを表示しています。")
            }
        }
    }
}

struct InfoPill: View {
    let icon: String
    let value: String

    var body: some View {
        Label(value, systemImage: icon)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
            .foregroundStyle(AppPalette.ink)
    }
}

struct IdeaCard: View {
    let idea: PlanIdea

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: idea.systemImage)
                    .font(.title2)
                    .frame(width: 38, height: 38)
                    .background(AppPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(AppPalette.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text(idea.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                Label("\(idea.cost)円", systemImage: "yensign.circle")
                Label("\(idea.minutes)分", systemImage: "clock")
                if let distance = idea.distanceMeters {
                    Label(distanceText(distance), systemImage: "figure.walk")
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let placeName = idea.placeName {
                Label(placeName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TagRow(tags: idea.tags)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.black.opacity(0.05))
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return "\(Int(meters))m"
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppPalette.soft, in: Capsule())
                    .foregroundStyle(AppPalette.ink)
            }
        }
    }
}

struct IdeaDetailView: View {
    let idea: PlanIdea
    let location: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(location, systemImage: "mappin.and.ellipse")
                    Label("\(idea.cost)円目安", systemImage: "yensign.circle")
                    Label("\(idea.minutes)分目安", systemImage: "clock")
                    if let address = idea.address {
                        Label(address, systemImage: "signpost.right")
                    }
                }

                Section("流れ") {
                    ForEach(Array(idea.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 24, height: 24)
                                .background(AppPalette.accent.opacity(0.15), in: Circle())
                            Text(step)
                        }
                    }
                }

                if let mapURL = idea.mapURL {
                    Section {
                        Button {
                            openURL(mapURL)
                        } label: {
                            Label("地図で開く", systemImage: "map")
                        }
                    }
                }
            }
            .navigationTitle(idea.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum LocationSearchService {
    static func search(input: PlannerInput, point: LocatedPoint) async throws -> [PlanIdea] {
        let coordinate = point.coordinate
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = input.mood.searchQuery
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 2500,
            longitudinalMeters: 2500
        )

        let response = try await MKLocalSearch(request: request).start()
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let maxMinutes = input.hours * 60

        let mapped = response.mapItems.prefix(8).compactMap { item -> PlanIdea? in
            guard let name = item.name else { return nil }
            let itemLocation = item.placemark.location
            let distance = itemLocation.map { $0.distance(from: origin) }
            let travelMinutes = max(20, Int((distance ?? 600) / 70) + 35)
            let minutes = min(maxMinutes, max(input.mood.baseMinutes, travelMinutes))
            let cost = min(input.budget, input.mood.baseCost)

            guard cost <= input.budget, minutes <= maxMinutes else {
                return nil
            }

            let address = [
                item.placemark.locality,
                item.placemark.thoroughfare,
                item.placemark.subThoroughfare
            ]
                .compactMap { $0 }
                .joined(separator: " ")

            return PlanIdea(
                title: "\(name)へ行く",
                subtitle: subtitle(for: input.mood, place: name),
                cost: cost,
                minutes: minutes,
                steps: steps(for: input.mood, place: name),
                tags: tags(for: input.mood),
                systemImage: input.mood.systemImage,
                placeName: name,
                address: address.isEmpty ? nil : address,
                distanceMeters: distance,
                mapURL: item.url
            )
        }

        return mapped.isEmpty ? PlanGenerator.fallbackIdeas(for: input) : Array(mapped)
    }

    private static func subtitle(for mood: Mood, place: String) -> String {
        switch mood {
        case .relax: "\(place)を中心に休憩と散歩を組み合わせる"
        case .active: "\(place)まで歩いて、周辺も軽く巡る"
        case .culture: "\(place)で発見を拾い、近くで余韻を整理する"
        case .food: "\(place)を軸に食事と寄り道を楽しむ"
        }
    }

    private static func steps(for mood: Mood, place: String) -> [String] {
        switch mood {
        case .relax:
            ["\(place)へ向かう", "飲み物や休憩時間を確保する", "近くを少し歩いてから戻る"]
        case .active:
            ["\(place)まで徒歩ルートを選ぶ", "到着後に周辺スポットを1つ追加する", "残り時間で休憩して戻る"]
        case .culture:
            ["\(place)で気になる展示や棚を見る", "印象に残ったものを3つメモする", "近くのカフェやベンチで整理する"]
        case .food:
            ["\(place)で食事候補を決める", "予算内でメインを選ぶ", "残り時間で近くの甘味や持ち帰りを探す"]
        }
    }

    private static func tags(for mood: Mood) -> [String] {
        switch mood {
        case .relax: ["現在地から検索", "休憩", "散歩"]
        case .active: ["現在地から検索", "徒歩", "軽運動"]
        case .culture: ["現在地から検索", "発見", "屋内候補"]
        case .food: ["現在地から検索", "食事", "寄り道"]
        }
    }
}

enum PlanGenerator {
    static func fallbackIdeas(for input: PlannerInput) -> [PlanIdea] {
        let base = catalog(for: input.mood, location: input.locationName)
        let maxMinutes = input.hours * 60
        let filtered = base.filter { $0.cost <= input.budget && $0.minutes <= maxMinutes }

        if filtered.isEmpty {
            return [
                PlanIdea(
                    title: "近場の低予算リセット",
                    subtitle: "\(input.locationName)周辺を短時間で楽しむ控えめプラン",
                    cost: min(input.budget, 800),
                    minutes: min(maxMinutes, 60),
                    steps: ["徒歩圏の公園や商店街へ向かう", "気になる店を1つだけ選んで飲み物を買う", "残り時間で写真を撮りながら戻る"],
                    tags: ["低予算", "徒歩", "短時間"],
                    systemImage: "figure.walk",
                    placeName: nil,
                    address: nil,
                    distanceMeters: nil,
                    mapURL: nil
                )
            ]
        }

        return filtered.sorted { lhs, rhs in
            let lhsScore = (input.budget - lhs.cost) + (maxMinutes - lhs.minutes) * 8
            let rhsScore = (input.budget - rhs.cost) + (maxMinutes - rhs.minutes) * 8
            return lhsScore < rhsScore
        }
    }

    private static func catalog(for mood: Mood, location: String) -> [PlanIdea] {
        switch mood {
        case .relax:
            [
                idea("喫茶店と散歩", "\(location)近くで一息ついてから軽く歩く", 1400, 110, ["休憩", "会話", "雨でも可"], "cup.and.saucer", ["評価の高い喫茶店へ入る", "季節の飲み物か軽食を選ぶ", "近くの公園か川沿いを20分歩く"]),
                idea("温浴施設で回復", "移動少なめで疲れを落とす", 2600, 180, ["回復", "ひとり向き", "屋内"], "water.waves", ["近い温浴施設を選ぶ", "入浴と休憩を90分確保する", "帰る前に軽食かドリンクを取る"])
            ]
        case .active:
            [
                idea("街歩きミッション", "\(location)から3スポットを巡る", 900, 120, ["徒歩", "写真", "軽運動"], "figure.walk.motion", ["ランドマークを1つ決める", "古い店か路地を探しながら歩く", "最後に気になった店で休む"]),
                idea("ボウリング短期戦", "2ゲームだけ遊んで切り上げる", 2200, 100, ["屋内", "友人向き", "短時間"], "circle.grid.cross", ["近くのボウリング場を探す", "2ゲームでスコア目標を決める", "余った予算でドリンクを買う"])
            ]
        case .culture:
            [
                idea("小さな展示巡り", "美術館、資料館、ギャラリーを優先", 1800, 150, ["展示", "静か", "発見"], "building.columns", ["周辺の展示を1つ選ぶ", "気になった作品を3つメモする", "近くの書店かカフェで余韻を整理する"]),
                idea("ローカル書店探索", "\(location)近くで本と雑貨を探す", 2500, 90, ["本", "屋内", "少額"], "books.vertical", ["独立系書店か大型書店へ行く", "テーマを1つ決めて棚を見る", "予算内で1冊だけ選ぶ"])
            ]
        case .food:
            [
                idea("食べ歩き2軒", "軽い店を2つ選んで満足度を上げる", 2800, 120, ["食事", "散歩", "満足"], "takeoutbag.and.cup.and.straw", ["1軒目は軽食にする", "15分歩いて次の候補へ向かう", "2軒目は甘いものか麺類で締める"]),
                idea("市場か地下街ランチ", "迷う楽しさ込みの食事プラン", 1800, 80, ["ランチ", "短時間", "雨でも可"], "fork.knife", ["市場、商店街、地下街のどれかへ行く", "行列が短い店を優先する", "残り予算で持ち帰りを1つ買う"])
            ]
        }
    }

    private static func idea(_ title: String, _ subtitle: String, _ cost: Int, _ minutes: Int, _ tags: [String], _ systemImage: String, _ steps: [String]) -> PlanIdea {
        PlanIdea(title: title, subtitle: subtitle, cost: cost, minutes: minutes, steps: steps, tags: tags, systemImage: systemImage, placeName: nil, address: nil, distanceMeters: nil, mapURL: nil)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum AppPalette {
    static let background = Color(red: 0.95, green: 0.96, blue: 0.94)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.12)
    static let accent = Color(red: 0.04, green: 0.42, blue: 0.38)
    static let soft = Color(red: 0.89, green: 0.93, blue: 0.90)
}

#Preview {
    PlannerView()
}
