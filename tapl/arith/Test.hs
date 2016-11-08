module Main where

import Control.Monad (forM_)
import TAPL.Meow (exec_)
import Test.QuickCheck
import Text.Printf (printf)

import Runner (run)

testCount :: Int
testCount = 6

main :: IO ()
main = do
  forM_ [1 .. testCount] $ \i -> do
    input <- readFile (printf "arith/examples/ex%d.in" i)
    expected <- readFile (printf "arith/examples/outputs/ex%d.out" i)
    output <- unlines <$> exec_ (run input)
    printf "[%d/%d] " i testCount
    quickCheck (expected == output)
