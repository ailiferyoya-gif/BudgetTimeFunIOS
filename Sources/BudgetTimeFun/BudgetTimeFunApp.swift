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
    var location = "名古屋駅"
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
}

struct PlannerView: View {
    @State private var input = PlannerInput()
    @State private var selectedIdea: PlanIdea?

    private var ideas: [PlanIdea] {
        PlanGenerator.ideas(for: input)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputPanel
                    summaryStrip
                    ideasSection
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .navigationTitle("予算時間プラン")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedIdea) { idea in
                IdeaDetailView(idea: idea, location: input.location)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("条件", systemImage: "slider.horizontal.3")
                .font(.headline)

            TextField("現在地", text: $input.location)
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

            Picker("気分", selection: $input.mood) {
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

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            InfoPill(icon: "mappin.and.ellipse", value: input.location)
            InfoPill(icon: "banknote", value: "最大\(input.budget)円")
            InfoPill(icon: "timer", value: "\(input.hours)時間以内")
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("おすすめ案")
                    .font(.title2.bold())
                Spacer()
                Text("\(ideas.count)件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(ideas) { idea in
                Button {
                    selectedIdea = idea
                } label: {
                    IdeaCard(idea: idea)
                }
                .buttonStyle(.plain)
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
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            TagRow(tags: idea.tags)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.black.opacity(0.05))
        }
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(location, systemImage: "mappin.and.ellipse")
                    Label("\(idea.cost)円目安", systemImage: "yensign.circle")
                    Label("\(idea.minutes)分目安", systemImage: "clock")
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

enum PlanGenerator {
    static func ideas(for input: PlannerInput) -> [PlanIdea] {
        let base = catalog(for: input.mood, location: input.location)
        let maxMinutes = input.hours * 60
        let filtered = base.filter { $0.cost <= input.budget && $0.minutes <= maxMinutes }

        if filtered.isEmpty {
            return [
                PlanIdea(
                    title: "近場の低予算リセット",
                    subtitle: "\(input.location)周辺を短時間で楽しむ控えめプラン",
                    cost: min(input.budget, 800),
                    minutes: min(maxMinutes, 60),
                    steps: ["駅や現在地から徒歩圏の公園や商店街へ向かう", "気になる店を1つだけ選んで飲み物を買う", "残り時間で写真を撮りながら戻る"],
                    tags: ["低予算", "徒歩", "短時間"],
                    systemImage: "figure.walk"
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
            return [
                PlanIdea(title: "喫茶店と散歩", subtitle: "\(location)近くで一息ついてから軽く歩く", cost: 1400, minutes: 110, steps: ["評価の高い喫茶店へ入る", "季節の飲み物か軽食を選ぶ", "近くの公園か川沿いを20分歩く"], tags: ["休憩", "会話", "雨でも可"], systemImage: "cup.and.saucer"),
                PlanIdea(title: "温浴施設で回復", subtitle: "移動少なめで疲れを落とす", cost: 2600, minutes: 180, steps: ["現在地から近い温浴施設を選ぶ", "入浴と休憩を90分確保する", "帰る前に軽食かドリンクを取る"], tags: ["回復", "ひとり向き", "屋内"], systemImage: "water.waves")
            ]
        case .active:
            return [
                PlanIdea(title: "街歩きミッション", subtitle: "\(location)から3スポットを巡る", cost: 900, minutes: 120, steps: ["ランドマークを1つ決める", "古い店か路地を探しながら歩く", "最後に気になった店で休む"], tags: ["徒歩", "写真", "軽運動"], systemImage: "figure.walk.motion"),
                PlanIdea(title: "ボウリング短期戦", subtitle: "2ゲームだけ遊んで切り上げる", cost: 2200, minutes: 100, steps: ["近くのボウリング場を探す", "2ゲームでスコア目標を決める", "余った予算でドリンクを買う"], tags: ["屋内", "友人向き", "短時間"], systemImage: "circle.grid.cross")
            ]
        case .culture:
            return [
                PlanIdea(title: "小さな展示巡り", subtitle: "美術館、資料館、ギャラリーを優先", cost: 1800, minutes: 150, steps: ["現在地周辺の展示を1つ選ぶ", "気になった作品を3つメモする", "近くの書店かカフェで余韻を整理する"], tags: ["展示", "静か", "発見"], systemImage: "building.columns"),
                PlanIdea(title: "ローカル書店探索", subtitle: "\(location)近くで本と雑貨を探す", cost: 2500, minutes: 90, steps: ["独立系書店か大型書店へ行く", "テーマを1つ決めて棚を見る", "予算内で1冊だけ選ぶ"], tags: ["本", "屋内", "少額"], systemImage: "books.vertical")
            ]
        case .food:
            return [
                PlanIdea(title: "食べ歩き2軒", subtitle: "軽い店を2つ選んで満足度を上げる", cost: 2800, minutes: 120, steps: ["1軒目は軽食にする", "15分歩いて次の候補へ向かう", "2軒目は甘いものか麺類で締める"], tags: ["食事", "散歩", "満足"], systemImage: "takeoutbag.and.cup.and.straw"),
                PlanIdea(title: "市場か地下街ランチ", subtitle: "迷う楽しさ込みの食事プラン", cost: 1800, minutes: 80, steps: ["市場、商店街、地下街のどれかへ行く", "行列が短い店を優先する", "残り予算で持ち帰りを1つ買う"], tags: ["ランチ", "短時間", "雨でも可"], systemImage: "fork.knife")
            ]
        }
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
