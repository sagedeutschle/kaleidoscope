import SwiftUI

struct AccountPanelView: View {
    @ObservedObject var auth: AuthManager
    @ObservedObject var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            header
            Divider()
            content
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 390)
        .frame(minHeight: 360)
        .background(PrismetDesign.ground)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 28))
                .foregroundStyle(AngularGradient(gradient: Gradient(colors: PrismetDesign.wheel), center: .center))
            VStack(alignment: .leading, spacing: 2) {
                Text("Game Center")
                    .font(PrismetDesign.title(24))
                    .foregroundStyle(PrismetDesign.ink)
                Text("Shared with the mobile app")
                    .font(.caption)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var content: some View {
        switch auth.state {
        case .loading:
            ProgressView("Checking account...")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .signedOut:
            gameCenterStatus(accountID: nil)
        case .signedIn(let userID):
            gameCenterStatus(accountID: userID)
        }
    }

    private func gameCenterStatus(accountID: UUID?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(PrismetDesign.gold)
            Text(auth.displayName ?? profiles.me?.displayName ?? "Player")
                .font(PrismetDesign.title(28))
                .foregroundStyle(PrismetDesign.ink)
            Text(auth.isCloudBacked ? "Game Center + cloud sync" : "Game Center")
                .foregroundStyle(PrismetDesign.ink2)
            if let accountID {
                Text(accountID.uuidString)
                    .font(.caption.monospaced())
                    .foregroundStyle(PrismetDesign.ink3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button {
                Task {
                    await auth.signOut()
                    profiles.reset()
                }
            } label: {
                Label("Refresh Identity", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(PrismetDesign.gold)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
