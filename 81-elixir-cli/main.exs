# Elixir (BEAM) CLI Victim -- Prime Sieve + Fibonacci
# Run: elixir main.exs [limit]
defmodule Victim do
  import Bitwise

  def fib(n) when n <= 1, do: n

  def fib(n) do
    Enum.reduce(2..n, {0, 1}, fn _, {a, b} -> {b, a + b} end) |> elem(1)
  end

  def sieve(limit) do
    marked = mark(MapSet.new(), 2, limit)
    Enum.filter(2..limit, fn n -> not MapSet.member?(marked, n) end)
  end

  defp mark(set, i, limit) when i * i > limit, do: set

  defp mark(set, i, limit) do
    set =
      if MapSet.member?(set, i) do
        set
      else
        i * i
        |> Stream.iterate(&(&1 + i))
        |> Stream.take_while(&(&1 <= limit))
        |> Enum.reduce(set, fn j, acc -> MapSet.put(acc, j) end)
      end

    mark(set, i + 1, limit)
  end

  def checksum(primes) do
    mask = bsl(1, 64) - 1
    Enum.reduce(primes, 5381, fn p, h -> band(bsl(h, 5) + h + p, mask) end)
  end
end

limit =
  case System.argv() do
    [a | _] ->
      case Integer.parse(a) do
        {v, _} when v >= 10 -> v
        _ -> 100
      end

    _ ->
      100
  end

IO.puts("Elixir CLI Victim -- Prime Sieve + Fibonacci")
IO.puts("Limit: #{limit}")
IO.puts("")
IO.puts("Fibonacci(#{limit}) = #{Victim.fib(limit)}")

primes = Victim.sieve(limit)
count = length(primes)
IO.puts("Primes up to #{limit}: #{count}")
if count > 0, do: IO.puts("Largest prime: #{List.last(primes)}")

fname = "elixir_cli_test.txt"

try do
  File.write!(fname, "Elixir CLI Victim -- #{count} primes up to #{limit}\n")
  IO.write("File I/O: #{File.read!(fname)}")
  File.rm!(fname)
rescue
  _ -> :ok
end

hex =
  Victim.checksum(primes)
  |> Integer.to_string(16)
  |> String.upcase()
  |> String.pad_leading(16, "0")

IO.puts("Checksum: 0x#{hex}")
