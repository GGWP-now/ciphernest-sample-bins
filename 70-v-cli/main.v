// V CLI Victim -- Prime Sieve + Fibonacci
// Build: v -prod -o v_cli.exe main.v
import os

fn fib(n int) u64 {
	if n <= 1 {
		return u64(n)
	}
	mut a := u64(0)
	mut b := u64(1)
	for _ in 2 .. n + 1 {
		t := a + b
		a = b
		b = t
	}
	return b
}

fn main() {
	mut limit := 100
	if os.args.len > 1 {
		limit = os.args[1].int()
		if limit < 10 {
			limit = 100
		}
	}

	println('V CLI Victim -- Prime Sieve + Fibonacci')
	println('Limit: ${limit}')
	println('')
	println('Fibonacci(${limit}) = ${fib(limit)}')

	mut buf := []bool{len: limit + 1}
	for i := 2; i * i <= limit; i++ {
		if !buf[i] {
			for j := i * i; j <= limit; j += i {
				buf[j] = true
			}
		}
	}

	mut count := 0
	mut largest := 0
	mut hash := u64(5381)
	for n := 2; n <= limit; n++ {
		if !buf[n] {
			count++
			largest = n
			hash = (hash << 5) + hash + u64(n)
		}
	}

	println('Primes up to ${limit}: ${count}')
	if count > 0 {
		println('Largest prime: ${largest}')
	}

	fname := 'v_cli_test.txt'
	os.write_file(fname, 'V CLI Victim -- ${count} primes up to ${limit}\n') or {}
	content := os.read_file(fname) or { '' }
	print('File I/O: ${content}')
	os.rm(fname) or {}

	println('Checksum: 0x${hash:016X}')
}
