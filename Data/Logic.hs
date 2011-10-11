{-# OPTIONS -Wwarn #-}
module Data.Logic
    ( -- * Boolean Logic
      Negatable(..)
    , Boolean(fromBool)
    , Logic(..)
    -- * Propositional Logic
    , PropositionalFormula(..)
    , Combine(..)
    , BinOp(..)
    -- * FirstOrderLogic
    , Variable(..)
    , Arity(arity)
    , Pred(..)
    , pApp
    , Predicate(..)
    , Skolem(..)
    , Term(..)
    , FirstOrderFormula(..)
    -- * Normal Forms
    , Literal(..)
    , ClauseNormalFormula(..)
    , ImplicativeForm(..)
    -- * Knowledge Base and Theorem Proving
    , Proof(proofResult)
    , ProofResult(Proved, Invalid, Disproved)
    , tellKB
    , runProverT'
    , prettyProof
    ) where

import Data.Logic.Classes.Arity
import Data.Logic.Classes.Boolean
import Data.Logic.Classes.ClauseNormalForm
import Data.Logic.Classes.FirstOrder
import Data.Logic.Classes.Literal
import Data.Logic.Classes.Logic
import Data.Logic.Classes.Negatable
import Data.Logic.Classes.Pred
import Data.Logic.Classes.Propositional
import Data.Logic.Classes.Skolem
import Data.Logic.Classes.Term
import Data.Logic.Classes.Variable
import Data.Logic.KnowledgeBase
import Data.Logic.Normal.Implicative
import Data.Logic.Types.FirstOrder ()
import Data.Logic.Types.FirstOrderPublic ()
