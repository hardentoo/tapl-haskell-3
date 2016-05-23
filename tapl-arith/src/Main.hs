module Main where

import Control.Monad (forever)
import System.Environment (getArgs)
import System.IO (stdout, hFlush)

import Parser (parseTree)
import Evaluator (eval)
import Types

pprint :: Term -> String
pprint TermTrue = "true"
pprint TermFalse = "false"
pprint t = show $ go t
  where
    go :: Term -> Int
    go TermZero = 0
    go (TermSucc nv) = succ $ go nv
    go _ = undefined

run :: String -> IO ()
run str = do
  let val = do
        term <- parseTree str
        eval term
  case val of
    Left err -> putStrLn err
    Right val -> putStrLn $ pprint val

usage = putStrLn "usage: tapl-arith <infile>"

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> do
      usage
      forever $ do
        putStr "tapl-arith> "
        hFlush stdout
        run =<< getLine
    [sourceFile] -> run =<< readFile sourceFile
    _ -> usage
