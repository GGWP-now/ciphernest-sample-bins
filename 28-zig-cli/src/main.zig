const std = @import("std");

fn fib(n: u32) u128 {
    if (n <= 1) return @as(u128, n);
    var a: u128 = 0;
    var b: u128 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const t = a + b;
        a = b;
        b = t;
    }
    return b;
}

fn sieve(limit: usize, alloc: std.mem.Allocator) ![]const usize {
    var buf = try alloc.alloc(bool, limit + 1);
    defer alloc.free(buf);
    @memset(buf, false);

    var i: usize = 2;
    while (i * i <= limit) : (i += 1) {
        if (!buf[i]) {
            var j = i * i;
            while (j <= limit) : (j += i) {
                buf[j] = true;
            }
        }
    }

    var primes = try alloc.alloc(usize, limit);
    var count: usize = 0;
    i = 2;
    while (i <= limit) : (i += 1) {
        if (!buf[i]) {
            primes[count] = i;
            count += 1;
        }
    }
    return try alloc.realloc(primes, count);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const limit: usize = 100;

    const primes = try sieve(limit, alloc);

    std.debug.print("Zig CLI Victim -- Prime Sieve + Fibonacci\n", .{});
    std.debug.print("Limit: {d}\n\n", .{limit});
    std.debug.print("Fibonacci({d}) = {d}\n", .{ limit, fib(@intCast(limit)) });
    std.debug.print("Primes up to {d}: {d}\n", .{ limit, primes.len });
    if (primes.len > 0) {
        std.debug.print("Largest prime: {d}\n", .{primes[primes.len - 1]});
    }
    var hash: u64 = 5381;
    for (primes) |p| {
        hash = (hash << 5) +% hash +% @as(u64, p);
    }
    std.debug.print("Checksum: {d}\n", .{hash});
}

test "fib supports limit used by the CLI" {
    try std.testing.expectEqual(@as(u128, 354224848179261915075), fib(100));
}

test "sieve returns primes up to limit" {
    const primes = try sieve(100, std.testing.allocator);
    defer std.testing.allocator.free(primes);

    try std.testing.expectEqual(@as(usize, 25), primes.len);
    try std.testing.expectEqual(@as(usize, 2), primes[0]);
    try std.testing.expectEqual(@as(usize, 97), primes[primes.len - 1]);
}
