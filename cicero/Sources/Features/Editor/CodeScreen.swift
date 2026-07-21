import SwiftUI

/// The Code tab: browse the project's files and open one in the editor.
struct CodeScreen: View {
    @ObservedObject var projects: ProjectStore
    @State private var showingNewFile = false
    @State private var newFileName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                CiceroTheme.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewFile = true } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .tint(CiceroTheme.accent)
                    .accessibilityLabel("New file")
                }
            }
            .alert("New file", isPresented: $showingNewFile) {
                TextField("name.swift", text: $newFileName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Create", action: createFile)
                Button("Cancel", role: .cancel) { newFileName = "" }
            } message: {
                Text("Enter a file name (or a path like src/main.py).")
            }
        }
    }

    @ViewBuilder private var content: some View {
        let fileList = projects.files.filter { !$0.isDirectory }
        if fileList.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundStyle(CiceroTheme.faint)
                Text("No files yet")
                    .font(CiceroTheme.ui(18, weight: .semibold))
                    .foregroundStyle(CiceroTheme.ink)
                Text("Tap the + to create one, or ask the Agent to scaffold a project.")
                    .font(CiceroTheme.ui(14))
                    .foregroundStyle(CiceroTheme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            List {
                ForEach(fileList) { file in
                    NavigationLink {
                        EditorScreen(projects: projects, path: file.relativePath)
                    } label: {
                        FileRow(file: file)
                    }
                    .listRowBackground(CiceroTheme.surface)
                }
                .onDelete { offsets in
                    for index in offsets {
                        try? projects.delete(fileList[index].relativePath)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func createFile() {
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFileName = ""
        guard !name.isEmpty else { return }
        try? projects.write(name, contents: "")
    }
}

private struct FileRow: View {
    let file: CodeFile
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(CiceroTheme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(CiceroTheme.mono(15))
                    .foregroundStyle(CiceroTheme.ink)
                if file.relativePath != file.name {
                    Text(file.relativePath)
                        .font(CiceroTheme.ui(11))
                        .foregroundStyle(CiceroTheme.faint)
                }
            }
            Spacer()
            Text(file.language.displayName)
                .font(CiceroTheme.ui(11))
                .foregroundStyle(CiceroTheme.faint)
        }
    }

    private var icon: String {
        switch file.language {
        case .swift: return "swift"
        case .markdown: return "text.alignleft"
        case .json: return "curlybraces"
        default: return "doc.text"
        }
    }
}

/// Full-screen editor for one file. Loads from disk on appear; Save writes back.
private struct EditorScreen: View {
    @ObservedObject var projects: ProjectStore
    let path: String

    @State private var text = ""
    @State private var savedText = ""
    @State private var loadError: String?

    private var dirty: Bool { text != savedText }
    private var fileName: String { (path as NSString).lastPathComponent }

    var body: some View {
        ZStack {
            CiceroTheme.bg.ignoresSafeArea()
            if let loadError {
                Text(loadError)
                    .font(CiceroTheme.ui(14))
                    .foregroundStyle(CiceroTheme.bad)
                    .padding()
            } else {
                CodeEditorView(text: $text, language: Language(filename: path))
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: save)
                    .disabled(!dirty)
                    .tint(CiceroTheme.accent)
            }
        }
        .task { load() }
    }

    private func load() {
        do {
            let contents = try projects.read(path)
            text = contents
            savedText = contents
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try projects.write(path, contents: text)
            savedText = text
        } catch {
            loadError = error.localizedDescription
        }
    }
}
