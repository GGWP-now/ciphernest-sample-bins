// Go CLI Victim -- Prime Sieve + Fibonacci
// Build: go build -o go_cli.exe main.go

package main

import (
	"fmt"
	"os"
	"strconv"
)

func fib(n int) int {
	if n <= 1 {
		return n
	}
	a, b := 0, 1
	for i := 2; i <= n; i++ {
		a, b = b, a+b
	}
	return b
}

func sieve(limit int) []int {
	buf := make([]bool, limit+1)
	for i := 2; i*i <= limit; i++ {
		if !buf[i] {
			for j := i * i; j <= limit; j += i {
				buf[j] = true
			}
		}
	}
	var primes []int
	for i := 2; i <= limit; i++ {
		if !buf[i] {
			primes = append(primes, i)
		}
	}
	return primes
}

func main() {
	limit := 100
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil && v >= 10 {
			limit = v
		}
	}

	fmt.Printf("Go CLI Victim -- Prime Sieve + Fibonacci\n")
	fmt.Printf("Limit: %d\n\n", limit)

	fmt.Printf("Fibonacci(%d) = %d\n", limit, fib(limit))

	primes := sieve(limit)
	fmt.Printf("Primes up to %d: %d\n", limit, len(primes))
	if len(primes) > 0 {
		fmt.Printf("Largest prime: %d\n", primes[len(primes)-1])
	}

	fname := "go_cli_test.txt"
	if fp, err := os.Create(fname); err == nil {
		fmt.Fprintf(fp, "Go CLI Victim -- %d primes up to %d\n", len(primes), limit)
		fp.Close()
	}
	if data, err := os.ReadFile(fname); err == nil {
		fmt.Printf("File I/O: %s", data)
	}
	os.Remove(fname)

	hash := uint64(5381)
	for _, p := range primes {
		hash = (hash<<5 + hash) + uint64(p)
	}
	fmt.Printf("Checksum: 0x%016X\n", hash)
}
