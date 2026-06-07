-- Lua CLI Victim -- Prime Sieve + Fibonacci
-- Run: lua main.lua [limit]   (precompile: luac -o lua_cli.luac main.lua)
local function fib(n)
  if n <= 1 then return n end
  local a, b = 0, 1
  for _ = 2, n do
    a, b = b, a + b
  end
  return b
end

local limit = 100
if arg[1] then
  local v = math.tointeger(tonumber(arg[1]))
  if v and v >= 10 then limit = v end
end

print("Lua CLI Victim -- Prime Sieve + Fibonacci")
print("Limit: " .. limit)
print("")
print(string.format("Fibonacci(%d) = %d", limit, fib(limit)))

local buf = {}
local i = 2
while i * i <= limit do
  if not buf[i] then
    local j = i * i
    while j <= limit do
      buf[j] = true
      j = j + i
    end
  end
  i = i + 1
end

local count, largest = 0, 0
local hash = 5381
for n = 2, limit do
  if not buf[n] then
    count = count + 1
    largest = n
    hash = (hash << 5) + hash + n
  end
end

print(string.format("Primes up to %d: %d", limit, count))
if count > 0 then
  print("Largest prime: " .. largest)
end

local fname = "lua_cli_test.txt"
local fh = io.open(fname, "w")
if fh then
  fh:write(string.format("Lua CLI Victim -- %d primes up to %d\n", count, limit))
  fh:close()
  local rh = io.open(fname, "r")
  if rh then
    io.write("File I/O: " .. rh:read("a"))
    rh:close()
  end
  os.remove(fname)
end

print(string.format("Checksum: 0x%016X", hash))
