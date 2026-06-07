-- Haskell CLI Victim -- Prime Sieve + Fibonacci
-- Build: ghc -O2 main.hs -o haskell_cli.exe
{-# LANGUAGE ScopedTypeVariables #-}
module Main where

import System.Environment (getArgs)
import System.Directory (removeFile)
import Data.Word (Word64)
import Data.Bits (shiftL)
import Data.List (foldl')
import Text.Printf (printf)
import Control.Exception (catch, SomeException, evaluate)
import qualified Data.Array.Unboxed as A

fib :: Int -> Word64
fib n
  | n <= 1    = fromIntegral n
  | otherwise = go 2 0 1
  where
    go i a b
      | i > n     = b
      | otherwise = go (i + 1) b (a + b)

sieve :: Int -> [Int]
sieve limit = [ n | n <- [2 .. limit], not (arr A.! n) ]
  where
    isqrt = floor . (sqrt :: Double -> Double) . fromIntegral
    arr :: A.UArray Int Bool
    arr = A.accumArray (\_ v -> v) False (0, limit)
            [ (j, True)
            | i <- [2 .. isqrt limit]
            , let start = i * i
            , j <- [start, start + i .. limit]
            ]

parseLimit :: [String] -> Int
parseLimit (a:_) = case reads a of
  [(v, "")] -> max v 10
  _         -> 100
parseLimit _ = 100

main :: IO ()
main = do
  args <- getArgs
  let limit  = parseLimit args
      primes = sieve limit
      count  = length primes
      hash   = foldl' (\h p -> (h `shiftL` 5) + h + fromIntegral p) (5381 :: Word64) primes

  putStrLn "Haskell CLI Victim -- Prime Sieve + Fibonacci"
  putStrLn $ "Limit: " ++ show limit
  putStrLn ""
  putStrLn $ "Fibonacci(" ++ show limit ++ ") = " ++ show (fib limit)
  putStrLn $ "Primes up to " ++ show limit ++ ": " ++ show count
  if count > 0
    then putStrLn $ "Largest prime: " ++ show (last primes)
    else return ()

  let fname = "haskell_cli_test.txt"
  (do
      writeFile fname ("Haskell CLI Victim -- " ++ show count ++ " primes up to " ++ show limit ++ "\n")
      content <- readFile fname
      _ <- evaluate (length content)
      putStr ("File I/O: " ++ content)
      removeFile fname)
    `catch` (\(_ :: SomeException) -> return ())

  printf "Checksum: 0x%016X\n" hash
