import Foundation

/// The tool surface Cicero exposes to the model: read/list/write/delete files in
/// the on-device project. This is what turns the chat into "vibe coding" — the
/// agent can inspect and change the same files open in the editor.
enum AgentTools {
    static let listFiles = "list_files"
    static let readFile = "read_file"
    static let writeFile = "write_file"
    static let deleteFile = "delete_file"

    static let all: [AnthropicTool] = [
        AnthropicTool(
            name: listFiles,
            description: "List every file path in the current on-device project.",
            inputSchema: objectSchema(properties: [:], required: [])),
        AnthropicTool(
            name: readFile,
            description: "Read the full contents of one file by its project-relative path.",
            inputSchema: objectSchema(
                properties: ["path": stringProp("Project-relative path, e.g. \"hello.swift\"")],
                required: ["path"])),
        AnthropicTool(
            name: writeFile,
            description: """
            Create or overwrite a file. Always pass the COMPLETE new file contents \
            in `contents` — never a diff or a fragment. Read the file first if you \
            need its current contents.
            """,
            inputSchema: objectSchema(
                properties: [
                    "path": stringProp("Project-relative path to write"),
                    "contents": stringProp("The complete new contents of the file"),
                ],
                required: ["path", "contents"])),
        AnthropicTool(
            name: deleteFile,
            description: "Delete one file by its project-relative path.",
            inputSchema: objectSchema(
                properties: ["path": stringProp("Project-relative path to delete")],
                required: ["path"])),
    ]

    static func systemPrompt(projectSummary: String) -> String {
        """
        You are Cicero, a coding agent living inside an iPhone app. The user is \
        coding on the go, so keep replies short and skimmable on a phone screen — \
        lead with the outcome, then only the detail that matters.

        You can act on the user's on-device project with these tools: \
        list_files, read_file, write_file, delete_file. Prefer inspecting files \
        (list/read) before editing. When you change a file, call write_file with \
        the file's COMPLETE new contents. After making changes, briefly say what \
        you changed and why in one or two sentences.

        Current project files:
        \(projectSummary)
        """
    }

    // MARK: Schema helpers

    private static func stringProp(_ description: String) -> JSONValue {
        .object(["type": .string("string"), "description": .string(description)])
    }

    private static func objectSchema(properties: [String: JSONValue], required: [String]) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map { .string($0) }),
        ])
    }
}
