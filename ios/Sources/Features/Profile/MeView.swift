import SwiftUI

/// The "Me" sheet: profile + sign out.
struct MeView: View {
    @ObservedObject var auth: AuthManager
    @ObservedObject var profiles: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                let me = profiles.me
                Text(me?.avatarEmoji ?? "🎴").font(.system(size: 80))
                    .frame(width: 120, height: 120)
                    .background(Circle().fill(Color(hex: me?.avatarColor ?? "B88A2E").opacity(0.2)))
                    .overlay(Circle().strokeBorder(Color(hex: me?.avatarColor ?? "B88A2E"), lineWidth: 3))
                Text(me?.displayName ?? "Player").font(PrismetDesign.title(28)).foregroundStyle(PrismetDesign.ink)
                Text(auth.isCloudBacked ? "Game Center + cloud sync" : "Game Center")
                    .font(.subheadline)
                    .foregroundStyle(PrismetDesign.ink3)
                Spacer()
                Button(role: .destructive) {
                    Task { await auth.signOut(); profiles.reset(); dismiss() }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: 280)
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FacetBackdrop(accent: PrismetDesign.gold))
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
