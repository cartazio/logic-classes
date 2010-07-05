{-# LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses,
             TypeSynonymInstances, UndecidableInstances #-}
{-# OPTIONS -Wall -Werror -fno-warn-orphans -fno-warn-missing-signatures #-}
module Logic.Instances.Chiou
    ( AtomicFunction(..)
    ) where

import Chiou.FirstOrderLogic
import Data.Char (ord, isDigit, chr)
import Logic.Logic (Logic(..), BinOp(..))
import Logic.Propositional (PropositionalLogic(..))
import Logic.Predicate (PredicateLogic(..), Skolem(..), InfixPred(..))
import qualified Logic.Predicate as Logic

-- |This enum instance is used to generate a series of new variable
-- names.
instance Enum String where
    succ v =
        toEnum (if n < cnt then n + 1 else if n == cnt then ord pref + cnt else n + cnt)
            where n = fromEnum v
    fromEnum s =
        case break (not . isDigit) (reverse s) of
          ("", [c]) | ord c >= ord mn && ord c <= ord mx -> ord c - ord mn
          (n, [c]) | ord c >= ord mn && ord c <= ord mx -> ord c - ord mn + cnt * (read (reverse n) :: Int)
          _ -> error $ "Invalid variable name: " ++ show s
    toEnum n =
        chr (ord mn + pre) : if suf == 0 then "" else show suf
        where (suf, pre) = divMod n cnt

mn = 'x'
pref = 'x'
mx = 'z'
cnt = ord mx - ord mn + 1

instance Logic Sentence where
    x .<=>. y = Connective x Equiv y
    x .=>.  y = Connective x Imply y
    x .|.   y = Connective x Or y
    x .&.   y = Connective x And y
    (.~.) x   = Not x

instance (Logic Sentence) => PropositionalLogic Sentence Sentence where
    atomic (Connective _ _ _) = error "Logic.Instances.Chiou.atomic: unexpected"
    atomic (Quantifier _ _ _) = error "Logic.Instances.Chiou.atomic: unexpected"
    atomic (Not _) = error "Logic.Instances.Chiou.atomic: unexpected"
    atomic (Predicate p ts) = pApp p ts
    atomic (Equal t1 t2) = t1 .=. t2
    foldF0 n b a formula =
        case formula of
          Not x -> n x
          Quantifier _ _ _ -> error "Logic.Instance.Chiou.foldF0: unexpected"
          Connective f1 Imply f2 -> b f1 (:=>:) f2
          Connective f1 Equiv f2 -> b f1 (:<=>:) f2
          Connective f1 And f2 -> b f1 (:&:) f2
          Connective f1 Or f2 -> b f1 (:|:) f2
          Predicate p ts -> a (Predicate p ts)
          Equal t1 t2 -> a (Equal t1 t2)

-- |We need a type to represent the atomic function, which is any term
-- which is not a variable.
data AtomicFunction
    = AtomicFunction Function
    | AtomicConstant Constant
    | AtomicSkolemFunction Int
    | AtomicSkolemConstant Int

-- |There is no correspondance between skolem functions and variable
-- names in this instance, we probably need to remove it from the
-- system.  Instead it maintains a skolem function allocator in its
-- state monad.
instance Skolem String Term where
    skolem = error "Chiou.skolem"

instance (PropositionalLogic Sentence Sentence) =>
          PredicateLogic Sentence Term Variable Predicate AtomicFunction where
    for_all vars x = Quantifier ForAll vars x
    exists vars x = Quantifier Exists vars x
    foldF n q b i p f =
        case f of
          Not x -> n x
          Quantifier ForAll vs f' -> q Logic.All vs f'
          Quantifier Exists vs f' -> q Logic.Exists vs f'
          Connective f1 Imply f2 -> b f1 (:=>:) f2
          Connective f1 Equiv f2 -> b f1 (:<=>:) f2
          Connective f1 And f2 -> b f1 (:&:) f2
          Connective f1 Or f2 -> b f1 (:|:) f2
          Predicate name ts -> p name ts
          Equal t1 t2 -> i t1 (:=:) t2
    foldT v fn t =
        case t of
          Variable name -> v name
          Function name ts -> fn (AtomicFunction name) ts
          Constant name -> fn (AtomicConstant name) []
          SkolemConstant n -> fn (AtomicSkolemConstant n) []
          SkolemFunction n ts -> fn (AtomicSkolemFunction n) ts
    pApp x args = Predicate x args
    var = Variable
    fApp (AtomicFunction name) ts = Function name ts
    fApp (AtomicConstant name) _ = Constant name
    fApp (AtomicSkolemFunction n) ts = SkolemFunction n ts
    fApp (AtomicSkolemConstant n) _ = SkolemConstant n
    x .=. y = Equal x y
    x .!=. y = Not (Equal x y)