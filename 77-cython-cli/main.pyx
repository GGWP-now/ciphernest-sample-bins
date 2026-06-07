# Cython CLI Victim -- Prime Sieve + Fibonacci
# Build: cython --embed -3 main.pyx -o main.c
#        then compile main.c against the CPython headers/libs (see build_matrix.ps1)
import sys
import os


def fib(int n):
    cdef unsigned long long a = 0
    cdef unsigned long long b = 1
    cdef unsigned long long t
    cdef int i
    if n <= 1:
        return n
    for i in range(2, n + 1):
        t = a + b
        a = b
        b = t
    return b


def main():
    cdef int limit = 100
    cdef int i, j, n
    cdef int count = 0
    cdef int largest = 0
    cdef unsigned long long hash = 5381

    if len(sys.argv) > 1:
        try:
            limit = int(sys.argv[1])
            if limit < 10:
                limit = 10
        except ValueError:
            limit = 100

    print("Cython CLI Victim -- Prime Sieve + Fibonacci")
    print("Limit:", limit)
    print("")
    print("Fibonacci(%d) = %d" % (limit, fib(limit)))

    cdef list buf = [False] * (limit + 1)
    i = 2
    while i * i <= limit:
        if not buf[i]:
            j = i * i
            while j <= limit:
                buf[j] = True
                j += i
        i += 1

    for n in range(2, limit + 1):
        if not buf[n]:
            count += 1
            largest = n
            hash = (hash << 5) + hash + <unsigned long long> n

    print("Primes up to %d: %d" % (limit, count))
    if count > 0:
        print("Largest prime:", largest)

    fname = "cython_cli_test.txt"
    try:
        with open(fname, "w") as fp:
            fp.write("Cython CLI Victim -- %d primes up to %d\n" % (count, limit))
        with open(fname, "r") as fp:
            sys.stdout.write("File I/O: " + fp.read())
        os.remove(fname)
    except OSError:
        pass

    print("Checksum: 0x%016X" % hash)


main()
