// Kotlin/Native CLI Victim -- Prime Sieve + Fibonacci
// Build: kotlinc-native main.kt -opt -o kotlin_cli   (emits kotlin_cli.exe on Windows)
@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.addressOf
import kotlinx.cinterop.toKString
import kotlinx.cinterop.usePinned
import platform.posix.fclose
import platform.posix.fgets
import platform.posix.fopen
import platform.posix.fputs
import platform.posix.remove

fun fib(n: Int): ULong {
    if (n <= 1) return n.toULong()
    var a = 0UL
    var b = 1UL
    for (i in 2..n) {
        val t = a + b
        a = b
        b = t
    }
    return b
}

fun roundTrip(fname: String, text: String): String? {
    val w = fopen(fname, "w") ?: return null
    fputs(text, w)
    fclose(w)
    val r = fopen(fname, "r") ?: return null
    val buffer = ByteArray(256)
    val line = buffer.usePinned { pinned ->
        fgets(pinned.addressOf(0), buffer.size, r)?.toKString()
    }
    fclose(r)
    remove(fname)
    return line
}

fun toHex16(v: ULong): String {
    val hex = v.toString(16).uppercase()
    return "0".repeat((16 - hex.length).coerceAtLeast(0)) + hex
}

fun main(args: Array<String>) {
    var limit = 100
    if (args.isNotEmpty()) {
        args[0].toIntOrNull()?.let { if (it >= 10) limit = it }
    }

    println("Kotlin/Native CLI Victim -- Prime Sieve + Fibonacci")
    println("Limit: $limit")
    println()
    println("Fibonacci($limit) = ${fib(limit)}")

    val buf = BooleanArray(limit + 1)
    var i = 2
    while (i * i <= limit) {
        if (!buf[i]) {
            var j = i * i
            while (j <= limit) {
                buf[j] = true
                j += i
            }
        }
        i++
    }

    var count = 0
    var largest = 0
    var hash = 5381UL
    for (n in 2..limit) {
        if (!buf[n]) {
            count++
            largest = n
            hash = (hash shl 5) + hash + n.toULong()
        }
    }

    println("Primes up to $limit: $count")
    if (count > 0) println("Largest prime: $largest")

    val line = roundTrip("kotlin_cli_test.txt", "Kotlin/Native CLI Victim -- $count primes up to $limit\n")
    if (line != null) print("File I/O: $line")

    println("Checksum: 0x${toHex16(hash)}")
}
