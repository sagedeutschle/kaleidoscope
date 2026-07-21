import SwiftUI

/// The "vibe coding" surface: a chat with Claude that can act on the project.
struct AgentChatView: View {
    @ObservedObject var agent: AgentSession
    @ObservedObject var projects: ProjectStore
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                CiceroTheme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    transcript
                    inputBar
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        agent.reset()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(CiceroTheme.accent)
                    .accessibilityLabel("New chat")
                }
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if agent.messages.isEmpty {
                        emptyState
                    }
                    ForEach(agent.messages) { message in
                        MessageRow(message: message).id(message.id)
                    }
                    if agent.isWorking {
                        WorkingRow().id("working")
                    }
                }
                .padding(16)
            }
            .onChange(of: agent.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: agent.isWorking) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if agent.isWorking {
                proxy.scrollTo("working", anchor: .bottom)
            } else if let last = agent.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask Claude to build")
                .font(CiceroTheme.ui(22, weight: .bold))
                .foregroundStyle(CiceroTheme.ink)
            Text("It can read, write, and delete files in your project. Try:")
                .font(CiceroTheme.ui(15))
                .foregroundStyle(CiceroTheme.ink2)
            ForEach(["Explain what hello.swift does",
                     "Add a greet(name:) function and call it",
                     "Create a fizzbuzz.swift and run through the logic"], id: \.self) { hint in
                Button {
                    draft = hint
                    inputFocused = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text(hint)
                    }
                    .font(CiceroTheme.ui(14))
                    .foregroundStyle(CiceroTheme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Cicero…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .font(CiceroTheme.ui(16))
                .foregroundStyle(CiceroTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CiceroTheme.surfaceHi, in: RoundedRectangle(cornerRadius: 18))
                .focused($inputFocused)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? CiceroTheme.accent : CiceroTheme.faint)
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(CiceroTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(CiceroTheme.border).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !agent.isWorking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await agent.send(text) }
    }
}

// MARK: - Rows

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.kind {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(CiceroTheme.ui(16))
                    .foregroundStyle(CiceroTheme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(CiceroTheme.accent.opacity(0.22),
                                in: RoundedRectangle(cornerRadius: 16))
            }
        case .assistant:
            assistantText
                .font(CiceroTheme.ui(16))
                .foregroundStyle(CiceroTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .tool:
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 11))
                Text(message.text).font(CiceroTheme.mono(12))
            }
            .foregroundStyle(CiceroTheme.faint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(CiceroTheme.surface, in: Capsule())
        case .error:
            Text(message.text)
                .font(CiceroTheme.ui(14))
                .foregroundStyle(CiceroTheme.bad)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CiceroTheme.bad.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var assistantText: some View {
        if let attributed = try? AttributedString(
            markdown: message.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(message.text)
    }
}

private struct WorkingRow: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(CiceroTheme.accent)
            Text("Working…")
                .font(CiceroTheme.ui(14))
                .foregroundStyle(CiceroTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
