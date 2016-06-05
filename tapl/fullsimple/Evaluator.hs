module Evaluator (
  evaluate
) where

import Base
import Context

termMap :: (Int -> Int -> Term) -> Term -> Term
termMap onvar t = go 0 t
  where
    go index (TermIfThenElse t t1 t2) = TermIfThenElse (go index t) (go index t1) (go index t2)
    go _ TermTrue = TermTrue
    go _ TermFalse = TermFalse
    go index (TermSucc t) = TermSucc (go index t)
    go index (TermPred t) = TermPred (go index t)
    go index (TermIsZero t) = TermIsZero (go index t)
    go _ TermZero = TermZero
    go _ TermUnit = TermUnit
    go index (TermLet var t1 t2) = TermLet var (go index t1) (go (index + 1) t2)
    go index (TermVar var) = onvar index var
    go index (TermAbs var ty t) = TermAbs var ty (go (index + 1) t)
    go index (TermApp t1 t2) = TermApp (go index t1) (go index t2)
    go index (TermAscribe t ty) = TermAscribe (go index t) ty

-- | Shift up deBruijn indices of all free variables by delta.
termShift :: Term -> Int -> Term
termShift t delta = termMap (\index var -> if var >= index then TermVar (var + delta) else TermVar var) t

-- | Substitute the variable with 0 deBruijn index in term to subterm.
termSubstitute :: Term -> Term -> Term
termSubstitute t subt = termMap (\index var -> if var == index then subt else TermVar var) t

termSubstituteTop :: Term -> Term -> Term
termSubstituteTop t subt = termShift (termSubstitute t (termShift subt 1)) (-1)

getBindingTerm :: Context -> Int -> Term
getBindingTerm ctx index = termShift t (index + 1) -- Shift all term variables to meet the current context.
  where
    t = case snd (indexToBinding ctx index) of
          BindTermAlias t _ -> t
          _ -> undefined

isNumericValue :: Term -> Bool
isNumericValue TermZero = True
isNumericValue (TermPred t) = isNumericValue t
isNumericValue (TermSucc t) = isNumericValue t
isNumericValue _ = False

isValue :: Term -> Bool
isValue TermTrue = True
isValue TermFalse = True
isValue TermUnit = True
isValue (TermAbs _ _ _) = True
isValue t = isNumericValue t

evaluate1 :: Context -> Term -> Maybe Term

evaluate1 _ (TermIfThenElse TermTrue t1 _) = Just t1

evaluate1 _ (TermIfThenElse TermFalse _ t2) = Just t2

evaluate1 ctx (TermIfThenElse t t1 t2) = do
  t' <- evaluate1 ctx t
  return $ TermIfThenElse t' t1 t2

evaluate1 ctx (TermSucc t) = do
  t' <- evaluate1 ctx t
  return $ TermSucc t'

evaluate1 _ (TermPred TermZero) = Just TermZero

evaluate1 _ (TermPred (TermSucc nv))
  | isNumericValue nv = Just nv

evaluate1 ctx (TermPred t) = do
  t' <- evaluate1 ctx t
  return $ TermPred t'

evaluate1 _ (TermIsZero TermZero) = Just TermTrue

evaluate1 _ (TermIsZero (TermSucc nv))
  | isNumericValue nv = Just TermFalse

evaluate1 ctx (TermIsZero t) = do
  t' <- evaluate1 ctx t
  return $ TermIsZero t'

evaluate1 _ (TermLet _ v t)
  | isValue v = Just $ termSubstituteTop t v

evaluate1 ctx (TermLet var t1 t2) = do
  t1' <- evaluate1 ctx t1
  return $ TermLet var t1' t2

evaluate1 ctx (TermVar var) = Just $ getBindingTerm ctx var

evaluate1 _ (TermApp (TermAbs _ _ t) v)
  | isValue v = Just $ termSubstituteTop t v

evaluate1 ctx (TermApp v t)
  | isValue v = do
      t' <- evaluate1 ctx t
      return $ TermApp v t'

evaluate1 ctx (TermApp t1 t2) = do
  t1' <- evaluate1 ctx t1
  return $ TermApp t1' t2

evaluate1 _ (TermAscribe v _)
  | isValue v = Just v

evaluate1 ctx (TermAscribe t ty) = do
  t' <- evaluate1 ctx t
  return $ TermAscribe t' ty

evaluate1 _ _ = Nothing

evaluate :: Context -> Term -> Term
evaluate ctx t = case evaluate1 ctx t of
  Just t' -> evaluate ctx t'
  Nothing -> t
