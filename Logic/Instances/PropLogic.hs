{-# LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses #-}
{-# OPTIONS -fno-warn-orphans #-}
module Logic.Instances.PropLogic
    ( flatten
    , plSat
    ) where

import Logic.Clause (Literal)
import Logic.FirstOrder (FirstOrderLogic, toPropositional)
import Logic.Logic
import Logic.Monad (NormalT)
import Logic.NormalForm (clauseNormalForm)
import Logic.Propositional
import qualified Logic.Set as S
import PropLogic

instance Logic (PropForm a) where
    x .<=>. y = EJ [x, y]
    x .=>.  y = SJ [x, y]
    x .|.   y = DJ [x, y]
    x .&.   y = CJ [x, y]
    (.~.) x   = N x

instance Logic (PropForm a) => PropositionalLogic (PropForm a) a where
    atomic = A
    foldF0 c a formula =
        case formula of
          -- EJ [x,y,z,...] -> CJ [EJ [x,y], EJ[y,z], ...]
          EJ [] -> error "Empty EJ"
          EJ [x] -> foldF0 c a x
          EJ [x0, x1] -> c (BinOp x0 (:<=>:) x1)
          EJ xs -> foldF0 c a (CJ (map (\ (x0, x1) -> EJ [x0, x1]) (pairs xs)))
          SJ [] -> error "Empty SJ"
          SJ [x] -> foldF0 c a x
          SJ [x0, x1] -> c (BinOp x0 (:=>:) x1)
          SJ xs -> foldF0 c a (CJ (map (\ (x0, x1) -> SJ [x0, x1]) (pairs xs)))
          DJ [] -> error "Empty disjunct"
          DJ [x] -> foldF0 c a x
          DJ (x0:xs) -> c (BinOp x0 (:|:) (DJ xs))
          CJ [] -> error "Empty conjunct"
          CJ [x] -> foldF0 c a x
          CJ (x0:xs) -> c (BinOp x0 (:&:) (CJ xs))
          N x -> c ((:~:) x)
          -- Not sure what to do about these - so far not an issue.
          T -> error "foldF0 method of PropForm: T"
          F -> error "foldF0 method of PropForm: F"
          A x -> a x

pairs :: [a] -> [(a, a)]
pairs (x:y:zs) = (x,y) : pairs (y:zs)
pairs _ = []

flatten :: PropForm a -> PropForm a
flatten (CJ xs) =
    CJ (concatMap f (map flatten xs))
    where
      f (CJ ys) = ys
      f x = [x]
flatten (DJ xs) =
    DJ (concatMap f (map flatten xs))
    where
      f (DJ ys) = ys
      f x = [x]
flatten (EJ xs) = EJ (map flatten xs)
flatten (SJ xs) = SJ (map flatten xs)
flatten (N x) = N (flatten x)
flatten x = x

plSat :: (Monad m, FirstOrderLogic formula term v p f, Literal formula, Ord formula) =>
                formula -> NormalT v term m Bool
plSat f = clauses f >>= return . satisfiable

clauses :: (Monad m, FirstOrderLogic formula term v p f, Literal formula) => formula -> NormalT v term m (PropForm formula)
clauses f = clauseNormalForm f >>= return . CJ . map (DJ . map (toPropositional A)) . map S.toList . S.toList

{-
inconsistant :: (Monad m, FirstOrderLogic formula term v p f, Literal formula, Ord formula) =>
                formula -> NormalT v term m Bool
inconsistant f =  satisfiable f >>= return . not

theorem :: (Monad m, FirstOrderLogic formula term v p f, Literal formula, Ord formula) =>
           formula -> NormalT v term m Bool
theorem f = inconsistant ((.~.) f)

invalid :: (Monad m, FirstOrderLogic formula term v p f, Literal formula, Ord formula) =>
           formula -> NormalT v term m Bool
invalid f = inconsistant f >>= \ fi -> theorem f >>= \ ft -> return (not (fi || ft))
-}
