import SwiftUI

@main
struct PrismetFieldDeckApp: App {
    @StateObject private var store = FieldDeckStore()

    var body: some Scene {
        WindowGroup {
            FieldDeckRootView()
                .environmentObject(store)
                .onAppear { store.activate() }
        }
    }
}
