// JS/TS CLI Victim -- Prime Sieve + Fibonacci
// Build: npx tsc   (emits dist/main.js; packaged to jsts_cli.exe via Node SEA)
import { writeFileSync, readFileSync, unlinkSync } from "node:fs";

function fib(n: number): bigint {
  if (n <= 1) return BigInt(n);
  let a = 0n;
  let b = 1n;
  for (let i = 2; i <= n; i++) {
    const t = a + b;
    a = b;
    b = t;
  }
  return b;
}

function main(): void {
  let limit = 100;
  const arg = process.argv[2];
  if (arg !== undefined) {
    const v = parseInt(arg, 10);
    if (!Number.isNaN(v) && v >= 10) limit = v;
  }

  console.log("JS/TS CLI Victim -- Prime Sieve + Fibonacci");
  console.log(`Limit: ${limit}`);
  console.log("");
  console.log(`Fibonacci(${limit}) = ${fib(limit)}`);

  const buf = new Array<boolean>(limit + 1).fill(false);
  for (let i = 2; i * i <= limit; i++) {
    if (!buf[i]) {
      for (let j = i * i; j <= limit; j += i) buf[j] = true;
    }
  }

  let count = 0;
  let largest = 0;
  let hash = 5381n;
  const mask = (1n << 64n) - 1n;
  for (let n = 2; n <= limit; n++) {
    if (!buf[n]) {
      count++;
      largest = n;
      hash = ((hash << 5n) + hash + BigInt(n)) & mask;
    }
  }

  console.log(`Primes up to ${limit}: ${count}`);
  if (count > 0) console.log(`Largest prime: ${largest}`);

  const fname = "jsts_cli_test.txt";
  try {
    writeFileSync(fname, `JS/TS CLI Victim -- ${count} primes up to ${limit}\n`);
    process.stdout.write(`File I/O: ${readFileSync(fname, "utf8")}`);
    unlinkSync(fname);
  } catch {
    /* ignore */
  }

  const hex = hash.toString(16).toUpperCase().padStart(16, "0");
  console.log(`Checksum: 0x${hex}`);
}

main();
