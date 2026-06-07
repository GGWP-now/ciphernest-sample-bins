# Julia CLI Victim -- Prime Sieve + Fibonacci
# Run: julia main.jl [limit]
function fib(n::Int)::UInt64
    n <= 1 && return UInt64(n)
    a::UInt64 = 0
    b::UInt64 = 1
    for _ in 2:n
        a, b = b, a + b
    end
    return b
end

function run()
    limit = 100
    if length(ARGS) >= 1
        v = tryparse(Int, ARGS[1])
        if v !== nothing && v >= 10
            limit = v
        end
    end

    println("Julia CLI Victim -- Prime Sieve + Fibonacci")
    println("Limit: ", limit)
    println("")
    println("Fibonacci(", limit, ") = ", fib(limit))

    buf = falses(limit + 1)
    i = 2
    while i * i <= limit
        if !buf[i + 1]
            j = i * i
            while j <= limit
                buf[j + 1] = true
                j += i
            end
        end
        i += 1
    end

    count = 0
    largest = 0
    hash = UInt64(5381)
    for n in 2:limit
        if !buf[n + 1]
            count += 1
            largest = n
            hash = (hash << 5) + hash + UInt64(n)
        end
    end

    println("Primes up to ", limit, ": ", count)
    count > 0 && println("Largest prime: ", largest)

    fname = "julia_cli_test.txt"
    try
        open(fname, "w") do io
            write(io, "Julia CLI Victim -- $count primes up to $limit\n")
        end
        print("File I/O: ", read(fname, String))
        rm(fname)
    catch
    end

    println("Checksum: 0x", uppercase(string(hash, base = 16, pad = 16)))
end

run()
