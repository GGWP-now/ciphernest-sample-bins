# Nim CLI Victim -- Prime Sieve + Fibonacci
# Build: nim c -d:release --out:nim_cli.exe main.nim
import os, strutils

proc fib(n: int): uint64 =
  if n <= 1:
    return uint64(n)
  var
    a: uint64 = 0
    b: uint64 = 1
  for _ in 2 .. n:
    let t = a + b
    a = b
    b = t
  b

proc run() =
  var limit = 100
  if paramCount() >= 1:
    try:
      limit = parseInt(paramStr(1))
      if limit < 10:
        limit = 10
    except ValueError:
      limit = 100

  echo "Nim CLI Victim -- Prime Sieve + Fibonacci"
  echo "Limit: ", limit
  echo ""
  echo "Fibonacci(", limit, ") = ", fib(limit)

  var buf = newSeq[bool](limit + 1)
  var i = 2
  while i * i <= limit:
    if not buf[i]:
      var j = i * i
      while j <= limit:
        buf[j] = true
        j += i
    inc i

  var
    count = 0
    largest = 0
    hash: uint64 = 5381
  for n in 2 .. limit:
    if not buf[n]:
      inc count
      largest = n
      hash = (hash shl 5) + hash + uint64(n)

  echo "Primes up to ", limit, ": ", count
  if count > 0:
    echo "Largest prime: ", largest

  let fname = "nim_cli_test.txt"
  try:
    writeFile(fname, "Nim CLI Victim -- " & $count & " primes up to " & $limit & "\n")
    let content = readFile(fname)
    stdout.write("File I/O: " & content)
    removeFile(fname)
  except IOError:
    discard

  echo "Checksum: 0x", toHex(hash, 16)

run()
