// Swift CLI Victim -- Prime Sieve + Fibonacci
// Build: swiftc -O main.swift -o swift_cli.exe
import Foundation

func fib(_ n: Int) -> UInt64 {
    if n <= 1 { return UInt64(n) }
    var a: UInt64 = 0
    var b: UInt64 = 1
    for _ in 2...n {
        let t = a &+ b
        a = b
        b = t
    }
    return b
}

var limit = 100
if CommandLine.arguments.count > 1, let v = Int(CommandLine.arguments[1]) {
    limit = max(v, 10)
}

print("Swift CLI Victim -- Prime Sieve + Fibonacci")
print("Limit: \(limit)")
print("")
print("Fibonacci(\(limit)) = \(fib(limit))")

var buf = [Bool](repeating: false, count: limit + 1)
var i = 2
while i * i <= limit {
    if !buf[i] {
        var j = i * i
        while j <= limit {
            buf[j] = true
            j += i
        }
    }
    i += 1
}

var count = 0
var largest = 0
var hash: UInt64 = 5381
for n in 2...limit where !buf[n] {
    count += 1
    largest = n
    hash = (hash << 5) &+ hash &+ UInt64(n)
}

print("Primes up to \(limit): \(count)")
if count > 0 {
    print("Largest prime: \(largest)")
}

let fname = "swift_cli_test.txt"
let payload = "Swift CLI Victim -- \(count) primes up to \(limit)\n"
try? payload.write(toFile: fname, atomically: true, encoding: .utf8)
if let content = try? String(contentsOfFile: fname, encoding: .utf8) {
    print("File I/O: \(content)", terminator: "")
}
try? FileManager.default.removeItem(atPath: fname)

print(String(format: "Checksum: 0x%016llX", hash))
