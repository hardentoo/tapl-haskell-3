module Type (
  typeEqual
, typeOf
, typeOfPattern
, simplifyType
) where

import           Base
import           Context

import           Data.List (find)
import qualified Data.HashSet as S

typeMap :: (Int -> TermType) -> TermType -> TermType
typeMap onvar ty = go ty
  where
    go TypeBool = TypeBool
    go TypeNat = TypeNat
    go (TypeList ty) = TypeList (go ty)
    go TypeUnit = TypeUnit
    go (TypeRecord fields) = TypeRecord (map (\(f, ty) -> (f, go ty)) fields)
    go (TypeArrow ty1 ty2) = TypeArrow (go ty1) (go ty2)
    go (TypeVar var) = onvar var

typeShift :: TermType -> Int -> TermType
typeShift ty delta = typeMap (\var -> TypeVar (var + delta)) ty

getBindingType :: Context -> Int -> TermType
getBindingType ctx index = typeShift ty (index + 1) -- Shift all type variables to meet the current context.
  where
    ty = case snd (indexToBinding ctx index) of
           BindTypeAlias tyalias -> tyalias
           BindVar tyvar -> tyvar
           BindTermAlias _ ty -> ty
           _ -> undefined

-- | Simplify type so that the outer most is not TypeVar.
simplifyType :: Context -> TermType -> TermType
simplifyType ctx (TypeVar var) = simplifyType ctx (getBindingType ctx var)
simplifyType _ ty = ty

typeEqual :: Context -> TermType -> TermType -> Bool
typeEqual ctx ty1 ty2 = case (ty1, ty2) of
  (TypeBool, TypeBool) -> True
  (TypeNat, TypeNat) -> True
  (TypeList ty1, TypeList ty2) -> typeEqual ctx ty1 ty2
  (TypeUnit, TypeUnit) -> True
  (TypeRecord fields1, TypeRecord fields2) -> length fields1 == length fields2 && all (\((f1, ty1), (f2, ty2)) -> f1 == f2 && typeEqual ctx ty1 ty2) (zip fields1 fields2)
  (TypeArrow tya1 tya2, TypeArrow tyb1 tyb2) -> typeEqual ctx tya1 tyb1 && typeEqual ctx tya2 tyb2
  (TypeVar i, TypeVar j) -> i == j
  (TypeVar _, _) -> typeEqual ctx (simplifyType ctx ty1) ty2
  (_, TypeVar _) -> typeEqual ctx ty1 (simplifyType ctx ty2)
  _ -> False

-- | Return the type of the given term. For the sake of `TermAscribe`, type is not evaluated or simplified.
typeOf :: Context -> Term -> TermType

typeOf ctx (TermIfThenElse t t1 t2) =
  if typeEqual ctx (typeOf ctx t) TypeBool
    then let ty1 = typeOf ctx t1
             ty2 = typeOf ctx t2
          in if typeEqual ctx ty1 ty2
               then ty1
               else error "type error: arms of conditional have different types"
    else error "type error: guard of conditional not a boolean"

typeOf _ TermTrue = TypeBool

typeOf _ TermFalse = TypeBool

typeOf _ TermZero = TypeNat

typeOf ctx (TermSucc t) =
  if typeEqual ctx (typeOf ctx t) TypeNat
    then TypeNat
    else error "type error: argument of succ is not a number"

typeOf ctx (TermPred t) =
  if typeEqual ctx (typeOf ctx t) TypeNat
    then TypeNat
    else error "type error: argument of pred is not a number"

typeOf ctx (TermIsZero t) =
  if typeEqual ctx (typeOf ctx t) TypeNat
    then TypeBool
    else error "type error: argument of iszero is not a number"

-- Our syntax and typechecker are slightly different from TAPL's original implenmentation, see ex 11.12.2.
typeOf _ (TermNil ty) = TypeList ty

typeOf ctx (TermCons t1 t2) = case simplifyType ctx tyList of
  TypeList ty -> if typeEqual ctx ty (typeOf ctx t1)
                   then tyList
                   else error "type error: list head and rest are incompatible"
  _ -> error "type error: expect list type"
  where
    tyList = typeOf ctx t2

typeOf ctx (TermIsNil t) = case simplifyType ctx (typeOf ctx t) of
  TypeList _ -> TypeBool
  _ -> error "type error: expect list type"

typeOf ctx (TermHead t) = case simplifyType ctx (typeOf ctx t) of
  TypeList ty -> ty
  _ -> error "type error: expect list type"

typeOf ctx (TermTail t) = case simplifyType ctx (typeOf ctx t) of
  TypeList ty -> TypeList ty
  _ -> error "type error: expect list type"

typeOf _ TermUnit = TypeUnit

typeOf ctx (TermRecord fields) =
  if unique
    then TypeRecord (map (\(f, t) -> (f, typeOf ctx t)) fields)
    else error "type error: record contains duplicate field"
  where
    unique = S.size (S.fromList (map fst fields)) == length fields

typeOf ctx (TermProj t field) = case simplifyType ctx (typeOf ctx t) of
  TypeRecord fields -> case find (\(f, _) -> f == field) fields of
                         Just (_, ty) -> ty
                         Nothing -> error $ "type error: field " ++ field ++ " not found"
  _ -> error "type error: expected record type"

typeOf ctx (TermLet pat t1 t2) = typeShift (typeOf ctx' t2) (-1)
  where
    ty1 = typeOf ctx t1
    ctx' = foldr add ctx (typeOfPattern ctx ty1 pat)
      where
        add (var, ty) ctx = addBinding ctx var (BindVar ty)

typeOf ctx (TermFix t) = case simplifyType ctx (typeOf ctx t) of
  TypeArrow ty1 ty2 ->
    if typeEqual ctx ty1 ty2
      then ty1
      else error "result of body not compatible with domain"
  _ -> error "arrow type expected"

typeOf ctx (TermVar var) = getBindingType ctx var

typeOf ctx (TermAbs var ty t) = TypeArrow ty (typeShift (typeOf ctx' t) (-1))
  where
    ctx' = addBinding ctx var (BindVar ty)

typeOf ctx (TermApp t1 t2) = case ty1 of
  TypeArrow ty3 ty4 ->
    if typeEqual ctx ty3 ty2
      then ty4
      else error "type error: parameter type mismatch"
  _ -> error "type error: arrow type expected"
  where
    ty1 = simplifyType ctx (typeOf ctx t1)
    ty2 = typeOf ctx t2

typeOf ctx (TermAscribe t ty) =
  if typeEqual ctx ty ty0
    then ty
    else error "type error: body of as-term does not have the expected type"
  where
    ty0 = typeOf ctx t

typeOfPattern :: Context -> TermType -> Pattern -> [(String, TermType)]
typeOfPattern _ ty (PatternVar var) = [(var, ty)]
typeOfPattern ctx ty (PatternRecord pats) = case simplifyType ctx ty of
  TypeRecord fields -> go pats
    where
      go :: [(String, Pattern)] -> [(String, TermType)]
      go [] = []
      go ((index, pat) : pats) = case find (\(index2, _) -> index == index2) fields of
                                   Just (_, ty) -> go pats ++ typeOfPattern ctx ty pat
                                   Nothing -> error $ "type error: field " ++ index ++ " not found in pattern matching"
  _ -> error "type error: expected record type"
