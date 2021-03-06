{

module Lexer (
  scanTokens
) where

import TAPL.Alex
import Base

}

tokens :-
  $white+                   ;
  \.                        { \_ -> TokenDot }
  \,                        { \_ -> TokenComma }
  \:                        { \_ -> TokenColon }
  \;                        { \_ -> TokenSemi }
  \=                        { \_ -> TokenEq }
  \_                        { \_ -> TokenUScore }
  \(                        { \_ -> TokenLParen }
  \)                        { \_ -> TokenRParen }
  \{                        { \_ -> TokenLCurly }
  \}                        { \_ -> TokenRCurly }
  \[                        { \_ -> TokenLBracket }
  \]                        { \_ -> TokenRBracket }
  \-\>                      { \_ -> TokenArrow }
  [0-9]+                    { \s -> TokenInt (read s) }
  [a-zA-Z]+                 { \s -> case lookupKeyword s of
                                      Just t -> t
                                      Nothing -> createId s }
  [a-zA-Z][a-zA-Z0-9\_\']*  { \s -> createId s }

{

type AlexAction = String -> Token

alexFail :: a
alexFail = error "lexical error"

scanTokens :: String -> [Token]
scanTokens str = go ('\n', [], str)
  where
    go inp@(_, _, input) = case alexScan inp 0 of
      AlexEOF -> []
      AlexError _ -> alexFail
      AlexSkip inp' _ -> go inp'
      AlexToken inp' length action -> action (take length input) : go inp'

createId :: String -> Token
createId s = if c >= 'a' && c <= 'z' then TokenLCaseId s else TokenUCaseId s
  where c = head s

lookupKeyword :: String -> Maybe Token
lookupKeyword kw = lookup kw keywords
  where
    keywords = [ ("if", TokenIf)
               , ("then", TokenThen)
               , ("else", TokenElse)
               , ("true", TokenTrue)
               , ("false", TokenFalse)
               , ("pred", TokenPred)
               , ("succ", TokenSucc)
               , ("iszero", TokenIsZero)
               , ("nil", TokenNil)
               , ("cons", TokenCons)
               , ("isnil", TokenIsNil)
               , ("head", TokenHead)
               , ("tail", TokenTail)
               , ("unit", TokenUnit)
               , ("lambda", TokenLambda)
               , ("let", TokenLet)
               , ("in", TokenIn)
               , ("letrec", TokenLetrec)
               , ("type", TokenTypeAlias)
               , ("as", TokenAs)
               , ("Top", TokenTop)
               , ("Bool", TokenBool)
               , ("Nat", TokenNat)
               , ("List", TokenList)
               , ("Unit", TokenUUnit)
               ]

}
