module Main where

import Control.Monad (forever)
import System.Environment (getProgName, getArgs)
import System.IO (stdout, hFlush)
import Text.Printf (printf)

import Evaluator (eval)
import Parser (parseTree)
import PPrint (pprint)
import TypeChecker (typeCheck)

run :: String -> IO ()
run str = do
  let val = do
        term <- parseTree str
        ty <- typeCheck term
        val <- eval term
        return (val, ty)
  case val of
    Left err -> putStrLn err
    Right val -> putStrLn $ pprint val

usage :: IO ()
usage = printf "usage: %s <infile>\n" =<< getProgName

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> do
      usage
      forever $ do
        putStr "tyarith> "
        hFlush stdout
        run =<< getLine
    [sourceFile] -> run =<< readFile sourceFile
    _ -> usage