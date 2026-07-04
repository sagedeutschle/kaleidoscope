#!/usr/bin/env swift

import CryptoKit
import Foundation

let codes = CommandLine.arguments.dropFirst()
guard !codes.isEmpty else {
    FileHandle.standardError.write(Data("usage: scripts/hash-ad-unlock-code.swift CODE [CODE...]\n".utf8))
    exit(64)
}

for raw in codes {
    let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let digest = SHA256.hash(data: Data(normalized.utf8))
    let hash = digest.map { String(format: "%02x", $0) }.joined()
    print("\(normalized) \(hash)")
}
