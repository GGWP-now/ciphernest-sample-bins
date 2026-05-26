package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:slice"

fib :: proc(n: int) -> int {
    if n <= 1 { return n }
    a, b := 0, 1
    for i := 2; i <= n; i += 1 {
        a, b = b, a + b
    }
    return b
}

sieve :: proc(limit: int) -> (primes: [dynamic]int) {
    buf := make([]bool, limit + 1)
    defer delete(buf)

    for i := 2; i * i <= limit; i += 1 {
        if !buf[i] {
            for j := i * i; j <= limit; j += i {
                buf[j] = true
            }
        }
    }
    for i := 2; i <= limit; i += 1 {
        if !buf[i] {
            append(&primes, i)
        }
    }
    return
}

main :: proc() {
    limit := 100
    if len(os.args) > 1 {
        if v, ok := strconv.parse_int(os.args[1]); ok && v >= 10 {
            limit = v
        }
    }

    fmt.printf("Odin CLI Victim -- Prime Sieve + Fibonacci\n")
    fmt.printf("Limit: %d\n\n", limit)

    fmt.printf("Fibonacci(%d) = %d\n", limit, fib(limit))

    primes := sieve(limit)
    defer delete(primes)
    fmt.printf("Primes up to %d: %d\n", limit, len(primes))
    if len(primes) > 0 {
        fmt.printf("Largest prime: %d\n", primes[len(primes) - 1])
    }

    fname := "odin_cli_test.txt"
    if fp, err := os.open(fname, os.O_WRONLY | os.O_CREATE | os.O_TRUNC); err == 0 {
        os.write_string(fp, fmt.tprintf("Odin CLI Victim -- {} primes up to {}\n", len(primes), limit))
        os.close(fp)
    }
    if data, err := os.read_entire_file_from_path(fname, context.allocator); err == os.ERROR_NONE {
        fmt.printf("File I/O: %s", data)
        delete(data)
    }
    os.remove(fname)

    hash: u64 = 5381
    for p in primes {
        hash = (hash << 5 + hash) + u64(p)
    }
    fmt.printf("Checksum: 0x%016X\n", hash)
}
