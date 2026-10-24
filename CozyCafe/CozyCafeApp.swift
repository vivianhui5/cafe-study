import SwiftUI
import Combine
import UIKit

@MainActor final class CafeStore: ObservableObject {
    @Published private(set) var cafe: Cafe
    @Published var message: String?
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: "cozy.progress.v1").flatMap { try? JSONDecoder().decode(Progress.self, from: $0) }
        cafe = Cafe(progress: saved ?? Progress())
    }
    func save() { if let data = try? JSONEncoder().encode(cafe.progress) { defaults.set(data, forKey: "cozy.progress.v1") } }
    func configure(_ minutes: Int) { cafe.configure(minutes: minutes); save() }
    func select(_ drink: Drink) { cafe.select(drink); save() }
    func unlock(_ drink: Drink) { if cafe.unlock(drink) { save(); message = "\(drink.name) is now on your menu." } }
    func start() { cafe.start(at: ProcessInfo.processInfo.systemUptime); UIApplication.shared.isIdleTimerDisabled = true; message = nil }
    func cancel() {
        guard cafe.running else { return }
        cafe.cancel(); UIApplication.shared.isIdleTimerDisabled = false
        message = "Your brew was set aside. No coins earned — start fresh whenever you’re ready."
    }
    func tick() {
        if cafe.tick(at: ProcessInfo.processInfo.systemUptime) {
            save(); UIApplication.shared.isIdleTimerDisabled = false
            message = "A lovely little pause. +\(cafe.sessionMinutes) coins earned."
        }
    }
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
    static let cream = Color(hex: 0xF7F4E9)
    static let sage = Color(hex: 0x61765A)
    static let ink = Color(hex: 0x354332)
    static let paper = Color(hex: 0xEEEDDF)
}

@main struct CozyCafeApp: App {
    @StateObject private var store = CafeStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            CafeTabs().environmentObject(store).tint(.sage).preferredColorScheme(.light)
                .onChange(of: phase) { value in if value != .active { store.cancel() } }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in store.cancel() }
        }
    }
}

struct CafeTabs: View {
    @EnvironmentObject var store: CafeStore
    var body: some View {
        TabView {
            FocusView().tabItem { Label("Focus", systemImage: "cup.and.saucer") }
            MenuView(shop: false).tabItem { Label("Collection", systemImage: "square.grid.2x2") }
            MenuView(shop: true).tabItem { Label("Shop", systemImage: "storefront") }
        }
        .toolbarBackground(Color.cream, for: .tabBar)
        .alert("Cozy Café", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("Okay") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

struct CafeHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.caption).tracking(3).foregroundStyle(Color.sage)
            Text(title).font(.system(size: 34, weight: .regular, design: .serif)).foregroundStyle(Color.ink)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Flat shapes only: a ceramic silhouette, two calm layers, and a small saucer.
struct DrinkArt: View {
    let drink: Drink
    var fill: Double = 1
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse().fill(Color.sage.opacity(0.10)).frame(width: w * 0.88, height: h * 0.08).offset(y: h * 0.40)
                RoundedRectangle(cornerRadius: w * 0.13).stroke(Color.sage.opacity(0.45), lineWidth: 4)
                    .frame(width: w * 0.24, height: h * 0.28).offset(x: w * 0.30, y: h * 0.04)
                RoundedRectangle(cornerRadius: w * 0.09).fill(Color(hex: 0xE6E5D7)).frame(width: w * 0.60, height: h * 0.67)
                VStack(spacing: 0) {
                    Color(hex: 0xF6F0DC).frame(height: h * 0.10)
                    Color(hex: drink.color)
                }
                .frame(width: w * 0.56, height: h * 0.61 * max(0, min(1, fill)))
                .frame(width: w * 0.56, height: h * 0.63, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: w * 0.07))
                Capsule().fill(Color.sage.opacity(0.4)).frame(width: w * 0.70, height: h * 0.025).offset(y: h * 0.37)
            }.frame(width: w, height: h)
        }.accessibilityHidden(true)
    }
}

struct FocusView: View {
    @EnvironmentObject var store: CafeStore
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = ProcessInfo.processInfo.systemUptime
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var drink: Drink { Drink.menu.first { $0.id == store.cafe.progress.selected } ?? Drink.menu[0] }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack { Text("喫茶 · COZY CAFÉ").tracking(2).font(.caption); Spacer(); Label("\(store.cafe.progress.coins)", systemImage: "circle") }.foregroundStyle(Color.sage)
                CafeHeading(eyebrow: "A slower kind of day", title: "Make room for focus.")
                Text(store.cafe.running ? "Stay here. Let your drink slowly fill." : "Choose a cup. Settle in. Do one thing.")
                    .font(.subheadline).foregroundStyle(Color.sage).frame(maxWidth: .infinity, alignment: .leading)
                DrinkArt(drink: drink, fill: store.cafe.running ? store.cafe.fraction(at: now) : 1)
                    .frame(width: 220, height: 210)
                    .animation(reduceMotion ? nil : .linear(duration: 0.25), value: store.cafe.fraction(at: now))
                Text(drink.name).font(.system(.title3, design: .serif)).foregroundStyle(Color.ink)
                Text(String(format: "%02d:%02d", store.cafe.remaining(at: now) / 60, store.cafe.remaining(at: now) % 60))
                    .font(.system(size: 52, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(Color.ink)
                    .accessibilityLabel("\(store.cafe.remaining(at: now) / 60) minutes remaining")
                if !store.cafe.running {
                    Stepper("\(store.cafe.progress.duration) minutes", value: Binding(get: { store.cafe.progress.duration }, set: { store.configure($0) }), in: 1...120)
                        .padding().background(Color.paper, in: RoundedRectangle(cornerRadius: 16))
                    Picker("Your drink", selection: Binding(get: { store.cafe.progress.selected }, set: { id in if let d = Drink.menu.first(where: { $0.id == id }) { store.select(d) } })) {
                        ForEach(Drink.menu.filter { store.cafe.progress.unlocked.contains($0.id) }) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu)
                }
                Button { if store.cafe.running { store.cancel() } else { now = ProcessInfo.processInfo.systemUptime; store.start() } } label: {
                    Text(store.cafe.running ? "Set aside this brew" : "Begin focus").frame(maxWidth: .infinity).padding(18)
                }.buttonStyle(.plain).background(Color.sage, in: Capsule()).foregroundStyle(Color.cream)
                Text("1 coin per minute, awarded after a full brew.\nLeaving the app or locking your phone cancels your session.")
                    .font(.caption).foregroundStyle(Color.sage).multilineTextAlignment(.center)
            }.padding(26)
        }.background(Color.cream)
        .onReceive(timer) { _ in
            now = ProcessInfo.processInfo.systemUptime
            if phase == .active { store.tick() }
        }
    }
}

struct MenuView: View {
    @EnvironmentObject var store: CafeStore
    let shop: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CafeHeading(eyebrow: shop ? "The café menu" : "Your quiet rituals", title: shop ? "A new favorite awaits." : "Collected with care.")
                Text(shop ? "\(store.cafe.progress.coins) coins to spend · earned through focus" : "\(store.cafe.progress.minutes) minutes of focus · \(store.cafe.progress.cups) cups brewed")
                    .font(.subheadline).foregroundStyle(Color.sage)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                    ForEach(Drink.menu) { drink in
                        let owned = store.cafe.progress.unlocked.contains(drink.id)
                        VStack(spacing: 12) {
                            DrinkArt(drink: drink).frame(height: 130).opacity(owned || shop ? 1 : 0.35)
                            Text(drink.name).font(.system(.headline, design: .serif)).multilineTextAlignment(.center)
                            Text(drink.note).font(.caption).foregroundStyle(Color.sage).multilineTextAlignment(.center)
                            if owned {
                                Text("\(store.cafe.progress.brewed[drink.id, default: 0]) brewed").font(.caption)
                                Button(store.cafe.progress.selected == drink.id ? "Selected" : "Choose") { store.select(drink) }
                                    .disabled(store.cafe.running || store.cafe.progress.selected == drink.id)
                            } else if shop {
                                Button("Unlock · \(drink.price) coins") { store.unlock(drink) }
                                    .disabled(store.cafe.progress.coins < drink.price)
                            } else { Label("In the shop", systemImage: "lock").font(.caption) }
                        }.frame(maxWidth: .infinity).padding(14).background(Color.paper, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }.padding(26).foregroundStyle(Color.ink)
        }.background(Color.cream)
    }
}
