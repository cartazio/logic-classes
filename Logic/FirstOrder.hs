-- | 'FirstOrderFormula' is a multi-parameter type class for
-- representing instances of predicate or first order logic datatypes.
-- It builds on the 'Logic' class and adds the quantifiers @for_all@
-- and @exists@.  It also adds structure to the atomic formula
-- datatype: it introduces the @Term@ type and three type parameters:
-- @v@ (for variable), plus a @p@ parameter to represent the atomic
-- predicate type and an @f@ parameter to represent the type of the
-- atomic function type.
{-# LANGUAGE DeriveDataTypeable, FlexibleContexts, FlexibleInstances, FunctionalDependencies,
             GeneralizedNewtypeDeriving, MultiParamTypeClasses, RankNTypes, ScopedTypeVariables,
             TemplateHaskell, TypeSynonymInstances, UndecidableInstances #-}
{-# OPTIONS -fno-warn-orphans -Wall -Wwarn #-}
module Logic.FirstOrder
    ( Skolem(..)
    , Arity(..)
    , Variable(..)
    , Predicate(..)
    , FirstOrderFormula(..)
    , pApp
    , Term(..)
    , Quant(..)
    , quant
    , (!), (?)
    , quant'
    , for_all'
    , exists'
    , showForm
    , showTerm
    , freeVars
    , withUnivQuants
    , quantVars
    , allVars
    , univquant_free_vars
    , substitute
    , substitutePairs
    , convertFOF
    , convertTerm
    , toPropositional
    , Pretty(..)
    , prettyForm
    , prettyTerm
    , disj
    , conj
    ) where

import Data.Data (Data)
import Data.Function (on)
import Data.List (intercalate, intersperse)
import Data.Monoid (mappend)
import Data.SafeCopy (base, deriveSafeCopy)
import qualified Data.Set as S
import Data.Typeable (Typeable)
import Happstack.Data (deriveNewData)
import Logic.Logic
import Logic.Propositional (PropositionalFormula(..))
import Text.PrettyPrint

-- |A class for finding unused variable names.  The next method
-- returns the next in an endless sequence of variable names, if we
-- keep calling it we are bound to find some unused name.
class Variable v where
    one :: v
    -- ^ Return some commonly used variable, typically x
    next :: v -> v
    -- ^ Return a different variable name, @iterate next one@ should
    -- return a list which never repeats.

class Pretty x where
    pretty :: x -> Doc

-- |This class shows how to convert between atomic Skolem functions
-- and Ints.
class Skolem f where
    toSkolem :: Int -> f
    fromSkolem  :: f -> Maybe Int

-- |A temporary type used in the fold method to represent the
-- combination of a predicate and its arguments.  This reduces the
-- number of arguments to foldF and makes it easier to manage the
-- mapping of the different instances to the class methods.
data Predicate p term
    = Equal term term
    | NotEqual term term
    | Constant Bool
    | Apply p [term]
    deriving (Eq, Ord, Show, Read, Data, Typeable)

pApp :: FirstOrderFormula formula term v p f => p -> [term] -> formula
pApp p ts =
    case (ts, maybe (length ts) id (arity p)) of
      ([], 0) -> pApp0 p 
      ([a], 1) -> pApp1 p a
      ([a,b], 2) -> pApp2 p a b
      ([a,b,c], 3) -> pApp3 p a b c
      ([a,b,c,d], 4) -> pApp4 p a b c d
      ([a,b,c,d,e], 5) -> pApp5 p a b c d e
      ([a,b,c,d,e,f], 6) -> pApp6 p a b c d e f
      ([a,b,c,d,e,f,g], 7) -> pApp7 p a b c d e f g
      _ -> error ("Arity error: " ++ show (pretty p) ++ " " ++ intercalate " " (map (show . prettyTerm) ts))

class Arity p where
    -- |How many arguments does the predicate take?  Nothing
    -- means any number of arguments.
    arity :: p -> Maybe Int

class ( Ord v     -- Required so variables can be inserted into maps and sets
      , Variable v -- Used to rename variable during conversion to prenex
      , Data v    -- For serialization
      , Pretty v
      , Eq f      -- We need to check functions for equality during unification
      , Skolem f  -- Used to create skolem functions and constants
      , Data f    -- For serialization
      , Pretty f
      , Ord term  -- For implementing Ord in Literal
      ) => Term term v f | term -> v, term -> f where
    var :: v -> term
    -- ^ Build a term which is a variable reference.
    fApp :: f -> [term] -> term
    -- ^ Build a term by applying terms to an atomic function.  @f@
    -- (atomic function) is one of the type parameters, this package
    -- is mostly indifferent to its internal structure.
    foldT :: (v -> r) -> (f -> [term] -> r) -> term -> r
    -- ^ A fold for the term data type, which understands terms built
    -- from a variable and a term built from the application of a
    -- primitive function to other terms.
    zipT :: (v -> v -> Maybe r) -> (f -> [term] -> f -> [term] -> Maybe r) -> term -> term -> Maybe r

-- |The 'PropositionalFormula' type class.  Minimal implementation:
-- @for_all, exists, foldF, foldT, (.=.), pApp0-pApp7, fApp, var@.  The
-- functional dependencies are necessary here so we can write
-- functions that don't fix all of the type parameters.  For example,
-- without them the univquant_free_vars function gives the error @No
-- instance for (FirstOrderFormula Formula term V p f)@ because the
-- function doesn't mention the Term type.
class ( Term term v f
      , Logic formula  -- Basic logic operations
      , Data formula   -- Allows us to use Data.Generics functions on formulas
      , Data p
      , Boolean p      -- To implement true and false below
      , Arity p        -- To decide how many arguments
      , Eq p           -- Required during resolution
      , Ord p
      , Pretty p
      , Ord f
      ) => FirstOrderFormula formula term v p f
                                    | formula -> term
                                    , formula -> v
                                    , formula -> p
                                    , formula -> f
                                    , term -> p where
    -- | Universal quantification - for all x (formula x)
    for_all :: v -> formula -> formula
    -- | Existential quantification - there exists x such that (formula x)
    exists ::  v -> formula -> formula

    -- | A fold function similar to the one in 'PropositionalFormula'
    -- but extended to cover both the existing formula types and the
    -- ones introduced here.  @foldF (.~.) quant binOp infixPred pApp@
    -- is a no op.  The argument order is taken from Logic-TPTP.
    foldF :: (Quant -> v -> formula -> r)
          -> (Combine formula -> r)
          -> (Predicate p term -> r)
          -> formula
          -> r
    zipF :: (Quant -> v -> formula -> Quant -> v -> formula -> Maybe r)
         -> (Combine formula -> Combine formula -> Maybe r)
         -> (Predicate p term -> Predicate p term -> Maybe r)
         -> formula -> formula -> Maybe r
    -- | Build a formula by applying zero or more terms to an atomic
    -- predicate.
    pApp0 :: p  -> formula
    pApp1 :: p -> term  -> formula
    pApp2 :: p -> term -> term  -> formula
    pApp3 :: p -> term -> term -> term  -> formula
    pApp4 :: p -> term -> term -> term -> term  -> formula
    pApp5 :: p -> term -> term -> term -> term -> term  -> formula
    pApp6 :: p -> term -> term -> term -> term -> term -> term -> formula
    pApp7 :: p -> term -> term -> term -> term -> term -> term -> term -> formula
    -- | Equality of Terms
    (.=.) :: term -> term -> formula
    -- | Inequality of Terms
    (.!=.) :: term -> term -> formula
    a .!=. b = (.~.) (a .=. b)
    -- | The tautological formula
    true :: formula
    true = pApp0 (fromBool True)
    -- | The inconsistant formula
    false :: formula
    false = pApp0 (fromBool False)

-- |for_all with a list of variables, for backwards compatibility.
for_all' :: FirstOrderFormula formula term v p f => [v] -> formula -> formula
for_all' vs f = foldr for_all f vs

-- |exists with a list of variables, for backwards compatibility.
exists' :: FirstOrderFormula formula term v p f => [v] -> formula -> formula
exists' vs f = foldr for_all f vs

-- | Functions to disjunct or conjunct a list.
disj :: FirstOrderFormula formula term v p f => [formula] -> formula
disj [] = false
disj [x] = x
disj (x:xs) = x .|. disj xs

conj :: FirstOrderFormula formula term v p f => [formula] -> formula
conj [] = true
conj [x] = x
conj (x:xs) = x .&. conj xs

-- | Helper function for building folds.
quant :: FirstOrderFormula formula term v p f => 
         Quant -> v -> formula -> formula
quant All v f = for_all v f
quant Exists v f = exists v f

-- |Legacy version of quant from when we supported lists of quantified
-- variables.  It also has the virtue of eliding quantifications with
-- empty variable lists (by calling for_all' and exists'.)
quant' :: FirstOrderFormula formula term v p f => 
         Quant -> [v] -> formula -> formula
quant' All = for_all'
quant' Exists = exists'

-- | Display a formula in a format that can be read into the interpreter.
showForm :: forall formula term v p f. (FirstOrderFormula formula term v p f, Show v, Show p, Show f) => 
            formula -> String
showForm formula =
    foldF q c a formula
    where
      q All v f = "(for_all " ++ show v ++ " " ++ showForm f ++ ")"
      q Exists v f = "(exists " ++  show v ++ " " ++ showForm f ++ ")"
      c (BinOp f1 op f2) = "(" ++ parenForm f1 ++ " " ++ showCombine op ++ " " ++ parenForm f2 ++ ")"
      c ((:~:) f) = "((.~.) " ++ showForm f ++ ")"
      a :: Predicate p term -> String
      a (Equal t1 t2) =
          "(" ++ parenTerm t1 ++ " .=. " ++ parenTerm t2 ++ ")"
      a (NotEqual t1 t2) =
          "(" ++ parenTerm t1 ++ " .!=. " ++ parenTerm t2 ++ ")"
      a (Constant x) = "pApp' (Constant " ++ show x ++ ")"
      a (Apply p ts) = "(pApp" ++ show (length ts) ++ " (" ++ show p ++ ") (" ++ intercalate ") (" (map showTerm ts) ++ "))"
      parenForm x = "(" ++ showForm x ++ ")"
      parenTerm :: term -> String
      parenTerm x = "(" ++ showTerm x ++ ")"
      showCombine (:<=>:) = ".<=>."
      showCombine (:=>:) = ".=>."
      showCombine (:&:) = ".&."
      showCombine (:|:) = ".|."

showTerm :: forall term v f. (Term term v f, Show v, Show f) =>
            term -> String
showTerm term =
    foldT v f term
    where
      v :: v -> String
      v v' = "var (" ++ show v' ++ ")"
      f :: f -> [term] -> String
      f fn ts = "fApp (" ++ show fn ++ ") [" ++ intercalate "," (map showTerm ts) ++ "]"

prettyTerm :: forall v f term. Term term v f => term -> Doc
prettyTerm t = foldT pretty (\ fn ts -> pretty fn <> brackets (hcat (intersperse (text ",") (map prettyTerm ts)))) t

prettyForm :: forall formula term v p f. FirstOrderFormula formula term v p f =>
              Int -> formula -> Doc
prettyForm prec formula =
    foldF (\ qop v f -> parensIf (prec > 1) $ prettyQuant qop <> pretty v <+> prettyForm 1 f)
          (\ cm ->
               case cm of
                 (BinOp f1 op f2) ->
                     case op of
                       (:=>:) -> parensIf (prec > 2) $ (prettyForm 2 f1 <+> formOp op <+> prettyForm 2 f2)
                       (:<=>:) -> parensIf (prec > 2) $ (prettyForm 2 f1 <+> formOp op <+> prettyForm 2 f2)
                       (:&:) -> parensIf (prec > 3) $ (prettyForm 3 f1 <+> formOp op <+> prettyForm 3 f2)
                       (:|:) -> parensIf {-(prec > 4)-} True $ (prettyForm 4 f1 <+> formOp op <+> prettyForm 4 f2)
                 ((:~:) f) -> text {-"¬"-} "~" <> prettyForm 5 f)
          pr
          formula
    where
      pr (Constant x) = text (show x)
      pr (Equal t1 t2) = parensIf (prec > 6) (prettyTerm t1 <+> text "=" <+> prettyTerm t2)
      pr (NotEqual t1 t2) = parensIf (prec > 6) (prettyTerm t1 <+> text "!=" <+> prettyTerm t2)
      pr (Apply p ts) =
          pretty p <> case ts of
                        [] -> empty
                        _ -> parens (hcat (intersperse (text ",") (map prettyTerm ts)))
      parensIf False = id
      parensIf _ = parens . nest 1
      prettyQuant All = text {-"∀"-} "!"
      prettyQuant Exists = text {-"∃"-} "?"
      formOp (:<=>:) = text "<=>"
      formOp (:=>:) = text "=>"
      formOp (:&:) = text "&"
      formOp (:|:) = text "|"

-- |The 'Quant' and 'InfixPred' types, like the BinOp type in
-- 'Logic.Propositional', could be additional parameters to the type
-- class, but it would add additional complexity with unclear
-- benefits.
data Quant = All | Exists deriving (Eq,Ord,Show,Read,Data,Typeable,Enum,Bounded)

-- |Find the free (unquantified) variables in a formula.
freeVars :: FirstOrderFormula formula term v p f => formula -> S.Set v
freeVars f =
    foldF (\_ v x -> S.delete v (freeVars x))                    
          (\ cm ->
               case cm of
                 BinOp x _ y -> (mappend `on` freeVars) x y
                 (:~:) f' -> freeVars f')
          (\ pa -> case pa of
                     Constant _ -> S.empty
                     Equal t1 t2 -> S.union (freeVarsOfTerm t1) (freeVarsOfTerm t2)
                     NotEqual t1 t2 -> S.union (freeVarsOfTerm t1) (freeVarsOfTerm t2)
                     Apply _ ts -> S.unions (fmap freeVarsOfTerm ts))
          f
    where
      freeVarsOfTerm = foldT S.singleton (\ _ args -> S.unions (fmap freeVarsOfTerm args))

-- | Examine the formula to find the list of outermost universally
-- quantified variables, and call a function with that list and the
-- formula after the quantifiers are removed.
withUnivQuants :: FirstOrderFormula formula term v p f => ([v] -> formula -> r) -> formula -> r
withUnivQuants fn formula =
    doFormula [] formula
    where
      doFormula vs f =
          foldF (doQuant vs)
                (\ _ -> fn (reverse vs) f)
                (\ _ -> fn (reverse vs) f)
                f
      doQuant vs All v f = doFormula (v : vs) f
      doQuant vs Exists v f = fn (reverse vs) (exists v f)

{-
withImplication :: FirstOrderFormula formula term v p f => r -> (formula -> formula -> r) -> formula -> r
withImplication def fn formula =
    foldF (\ _ _ _ -> def) c (\ _ -> def) formula
    where
      c (BinOp a (:=>:) b) = fn a b
      c _ = def
-}

-- |Find the variables that are quantified in a formula
quantVars :: FirstOrderFormula formula term v p f => formula -> S.Set v
quantVars =
    foldF (\ _ v x -> S.insert v (quantVars x))
          (\ cm ->
               case cm of
                 BinOp x _ y -> (mappend `on` quantVars) x y
                 ((:~:) f) -> quantVars f)
          (\ _ -> S.empty)

-- |Find the free and quantified variables in a formula.
allVars :: FirstOrderFormula formula term v p f => formula -> S.Set v
allVars f =
    foldF (\_ v x -> S.insert v (allVars x))
          (\ cm ->
               case cm of
                 BinOp x _ y -> (mappend `on` allVars) x y
                 (:~:) f' -> freeVars f')
          (\ pa -> case pa of
                     Equal t1 t2 -> S.union (allVarsOfTerm t1) (allVarsOfTerm t2)
                     NotEqual t1 t2 -> S.union (allVarsOfTerm t1) (allVarsOfTerm t2)
                     Constant _ -> S.empty
                     Apply _ ts -> S.unions (fmap allVarsOfTerm ts))
          f
    where
      allVarsOfTerm = foldT S.singleton (\ _ args -> S.unions (fmap allVarsOfTerm args))

-- | Universally quantify all free variables in the formula (Name comes from TPTP)
univquant_free_vars :: FirstOrderFormula formula term v p f => formula -> formula
univquant_free_vars cnf' =
    if S.null free then cnf' else foldr for_all cnf' (S.toList free)
    where free = freeVars cnf'

-- |Replace each free occurrence of variable old with term new.
substitute :: FirstOrderFormula formula term v p f => v -> term -> formula -> formula
substitute old new formula =
    foldT (\ new' -> if old == new' then formula else substitute' formula)
          (\ _ _ -> substitute' formula)
          new
    where
      substitute' =
          foldF -- If the old variable appears in a quantifier
                -- we can stop doing the substitution.
                (\ q v f' -> quant q v (if old == v then f' else substitute' f'))
                (\ cm -> case cm of
                           ((:~:) f') -> combine ((:~:) (substitute' f'))
                           (BinOp f1 op f2) -> combine (BinOp (substitute' f1) op (substitute' f2)))
                (\ pa -> case pa of
                           Equal t1 t2 -> (st t1) .=. (st t2)
                           NotEqual t1 t2 -> (st t1) .!=. (st t2)
                           Constant x -> pApp0 (fromBool x)
                           Apply p ts -> pApp p (map st ts))
      st t = foldT sv (\ func ts -> fApp func (map st ts)) t
      sv v = if v == old then new else var v

substitutePairs :: FirstOrderFormula formula term v p f => [(v, term)] -> formula -> formula
substitutePairs pairs formula = 
    foldr (\ (old, new) f -> substitute old new f) formula pairs 

-- |Convert any instance of a first order logic expression to any other.
convertFOF :: forall formula1 term1 v1 p1 f1 formula2 term2 v2 p2 f2.
              (FirstOrderFormula formula1 term1 v1 p1 f1,
               FirstOrderFormula formula2 term2 v2 p2 f2) =>
              (v1 -> v2) -> (p1 -> p2) -> (f1 -> f2) -> formula1 -> formula2
convertFOF convertV convertP convertF formula =
    foldF q c p formula
    where
      convert' = convertFOF convertV convertP convertF
      convertTerm' = convertTerm convertV convertF
      q x v f = quant x (convertV v) (convert' f)
      c (BinOp f1 op f2) = combine (BinOp (convert' f1) op (convert' f2))
      c ((:~:) f) = combine ((:~:) (convert' f))
      p (Equal t1 t2) = (convertTerm' t1) .=. (convertTerm' t2)
      p (NotEqual t1 t2) = (convertTerm' t1) .!=. (convertTerm' t2)
      p (Apply x ts) = pApp (convertP x) (map convertTerm' ts)
      p (Constant x) = pApp (fromBool x) []

convertTerm :: forall term1 v1 f1 term2 v2 f2.
               (Term term1 v1 f1,
                Term term2 v2 f2) =>
               (v1 -> v2) -> (f1 -> f2) -> term1 -> term2
convertTerm convertV convertF term =
    foldT v fn term
    where
      convertTerm' = convertTerm convertV convertF
      v = var . convertV
      fn x ts = fApp (convertF x) (map convertTerm' ts)

-- |Try to convert a first order logic formula to propositional.  This
-- will return Nothing if there are any quantifiers, or if it runs
-- into an atom that it is unable to convert.
toPropositional :: forall formula1 term v p f formula2 atom.
                   (FirstOrderFormula formula1 term v p f,
                    PropositionalFormula formula2 atom) =>
                   (formula1 -> formula2) -> formula1 -> formula2
toPropositional convertAtom formula =
    foldF q c p formula
    where
      convert' = toPropositional convertAtom
      q _ _ _ = error "toPropositional: invalid argument"
      c (BinOp f1 op f2) = combine (BinOp (convert' f1) op (convert' f2))
      c ((:~:) f) = combine ((:~:) (convert' f))
      p _ = convertAtom formula

-- |Names for for_all and exists inspired by the conventions of the
-- TPTP project.
(!) :: FirstOrderFormula formula term v p f => v -> formula -> formula
(!) = for_all
(?) :: FirstOrderFormula formula term v p f => v -> formula -> formula
(?) = exists

$(deriveSafeCopy 1 'base ''Quant)
$(deriveSafeCopy 1 'base ''Predicate)

$(deriveNewData [''Quant, ''Predicate])
