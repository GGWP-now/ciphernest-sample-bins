import Foundation

let input = CommandLine.arguments.dropFirst().first ?? "matrix-safe"
let scalars = input.unicodeScalars.map { UInt64($0.value) }
let checksum = scalars.reduce(UInt64(0xcbf29ce484222325)) { partial, value in
    (partial ^ value) &* UInt64(0x100000001b3)
}

print("macOS CLI victim")
print("Input: \(input)")
print(String(format: "Checksum: 0x%016llX", checksum))
