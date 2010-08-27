{-# LANGUAGE RankNTypes, ScopedTypeVariables #-}
module Logic.Harrison.Prop
    ( psimplify1
    , nnf
    , simpcnf
    , trivial
    ) where

import Logic.Clause (Literal(..))
import Logic.FirstOrder (FirstOrderLogic(..), Predicate(..), Quant(..), quant)
import Logic.Logic (Logic(..), Combine(..), Boolean(..), BinOp(..))
import qualified Logic.Set as S

{-
(* ========================================================================= *)
(* Basic stuff for propositional logic: datatype, parsing and printing.      *)
(* ========================================================================= *)

type prop = P of string;;

let pname(P s) = s;;

(* ------------------------------------------------------------------------- *)
(* Parsing of propositional formulas.                                        *)
(* ------------------------------------------------------------------------- *)

let parse_propvar vs inp =
  match inp with
    p::oinp when p <> "(" -> Atom(P(p)),oinp
  | _ -> failwith "parse_propvar";;

let parse_prop_formula = make_parser
  (parse_formula ((fun _ _ -> failwith ""),parse_propvar) []);;

(* ------------------------------------------------------------------------- *)
(* Set this up as default for quotations.                                    *)
(* ------------------------------------------------------------------------- *)

let default_parser = parse_prop_formula;;

(* ------------------------------------------------------------------------- *)
(* Printer.                                                                  *)
(* ------------------------------------------------------------------------- *)

let print_propvar prec p = print_string(pname p);;

let print_prop_formula = print_qformula print_propvar;;

#install_printer print_prop_formula;;

(* ------------------------------------------------------------------------- *)
(* Testing the parser and printer.                                           *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
let fm = <<p ==> q <=> r /\ s \/ (t <=> ~ ~u /\ v)>>;;

And(fm,fm);;

And(Or(fm,fm),fm);;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Interpretation of formulas.                                               *)
(* ------------------------------------------------------------------------- *)

let rec eval fm v =
  match fm with
    False -> false
  | True -> true
  | Atom(x) -> v(x)
  | Not(p) -> not(eval p v)
  | And(p,q) -> (eval p v) & (eval q v)
  | Or(p,q) -> (eval p v) or (eval q v)
  | Imp(p,q) -> not(eval p v) or (eval q v)
  | Iff(p,q) -> (eval p v) = (eval q v);;

(* ------------------------------------------------------------------------- *)
(* Example of use.                                                           *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
eval <<p /\ q ==> q /\ r>>
     (function P"p" -> true | P"q" -> false | P"r" -> true);;

eval <<p /\ q ==> q /\ r>>
     (function P"p" -> true | P"q" -> true | P"r" -> false);;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Return the set of propositional variables in a formula.                   *)
(* ------------------------------------------------------------------------- *)

let atoms fm = atom_union (fun a -> [a]) fm;;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
atoms <<p /\ q \/ s ==> ~p \/ (r <=> s)>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Code to print out truth tables.                                           *)
(* ------------------------------------------------------------------------- *)

let rec onallvaluations subfn v ats =
  match ats with
    [] -> subfn v
  | p::ps -> let v' t q = if q = p then t else v(q) in
             onallvaluations subfn (v' false) ps &
             onallvaluations subfn (v' true) ps;;

let print_truthtable fm =
  let ats = atoms fm in
  let width = itlist (max ** String.length ** pname) ats 5 + 1 in
  let fixw s = s^String.make(width - String.length s) ' ' in
  let truthstring p = fixw (if p then "true" else "false") in
  let mk_row v =
     let lis = map (fun x -> truthstring(v x)) ats
     and ans = truthstring(eval fm v) in
     print_string(itlist (^) lis ("| "^ans)); print_newline(); true in
  let separator = String.make (width * length ats + 9) '-' in
  print_string(itlist (fun s t -> fixw(pname s) ^ t) ats "| formula");
  print_newline(); print_string separator; print_newline();
  let _ = onallvaluations mk_row (fun x -> false) ats in
  print_string separator; print_newline();;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
print_truthtable <<p /\ q ==> q /\ r>>;;

let fm = <<p /\ q ==> q /\ r>>;;

print_truthtable fm;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Additional examples illustrating formula classes.                         *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
print_truthtable <<((p ==> q) ==> p) ==> p>>;;

print_truthtable <<p /\ ~p>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Recognizing tautologies.                                                  *)
(* ------------------------------------------------------------------------- *)

let tautology fm =
  onallvaluations (eval fm) (fun s -> false) (atoms fm);;

(* ------------------------------------------------------------------------- *)
(* Examples.                                                                 *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;

tautology <<p \/ ~p>>;;

tautology <<p \/ q ==> p>>;;

tautology <<p \/ q ==> q \/ (p <=> q)>>;;

tautology <<(p \/ q) /\ ~(p /\ q) ==> (~p <=> q)>>;;

END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Related concepts.                                                         *)
(* ------------------------------------------------------------------------- *)

let unsatisfiable fm = tautology(Not fm);;

let satisfiable fm = not(unsatisfiable fm);;

(* ------------------------------------------------------------------------- *)
(* Substitution operation.                                                   *)
(* ------------------------------------------------------------------------- *)

let psubst subfn = onatoms (fun p -> tryapplyd subfn p (Atom p));;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
psubst (P"p" |=> <<p /\ q>>) <<p /\ q /\ p /\ q>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Surprising tautologies including Dijkstra's "Golden rule".                *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
tautology <<(p ==> q) \/ (q ==> p)>>;;

tautology <<p \/ (q <=> r) <=> (p \/ q <=> p \/ r)>>;;

tautology <<p /\ q <=> ((p <=> q) <=> p \/ q)>>;;

tautology <<(p ==> q) <=> (~q ==> ~p)>>;;

tautology <<(p ==> ~q) <=> (q ==> ~p)>>;;

tautology <<(p ==> q) <=> (q ==> p)>>;;

(* ------------------------------------------------------------------------- *)
(* Some logical equivalences allowing elimination of connectives.            *)
(* ------------------------------------------------------------------------- *)

forall tautology
 [<<true <=> false ==> false>>;
  <<~p <=> p ==> false>>;
  <<p /\ q <=> (p ==> q ==> false) ==> false>>;
  <<p \/ q <=> (p ==> false) ==> q>>;
  <<(p <=> q) <=> ((p ==> q) ==> (q ==> p) ==> false) ==> false>>];;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Dualization.                                                              *)
(* ------------------------------------------------------------------------- *)

let rec dual fm =
  match fm with
    False -> True
  | True -> False
  | Atom(p) -> fm
  | Not(p) -> Not(dual p)
  | And(p,q) -> Or(dual p,dual q)
  | Or(p,q) -> And(dual p,dual q)
  | _ -> failwith "Formula involves connectives ==> or <=>";;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
dual <<p \/ ~p>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Routine simplification.                                                   *)
(* ------------------------------------------------------------------------- *)

let psimplify1 fm =
  match fm with
    Not False -> True
  | Not True -> False
  | Not(Not p) -> p
  | And(p,False) | And(False,p) -> False
  | And(p,True) | And(True,p) -> p
  | Or(p,False) | Or(False,p) -> p
  | Or(p,True) | Or(True,p) -> True
  | Imp(False,p) | Imp(p,True) -> True
  | Imp(True,p) -> p
  | Imp(p,False) -> Not p
  | Iff(p,True) | Iff(True,p) -> p
  | Iff(p,False) | Iff(False,p) -> Not p
  | _ -> fm;;
-}
-- |Do one step of simplify for propositional formulas:
-- Perform the following transformations everywhere, plus any
-- commuted versions for &, |, and <=>.
-- 
-- @
--  ~False      -> True
--  ~True       -> False
--  True & P    -> P
--  False & P   -> False
--  True | P    -> True
--  False | P   -> P
--  True => P   -> P
--  False => P  -> True
--  P => True   -> P
--  P => False  -> True
--  True <=> P  -> P
--  False <=> P -> ~P
-- @
-- 
psimplify1 :: forall formula term v p f. FirstOrderLogic formula term v p f => formula -> formula
psimplify1 fm =
    foldF (\ _ _ _ -> fm) simplifyCombine (\ _ -> fm) fm
    where
      simplifyCombine ((:~:) f) = foldF (\ _ _ _ -> fm) simplifyNotCombine simplifyNotPred f
      simplifyCombine (BinOp l op r) =
          case (pBool l, op, pBool r) of
            (Just True,  (:&:), _)            -> r
            (Just False, (:&:), _)            -> false
            (_,          (:&:), Just True)    -> l
            (_,          (:&:), Just False)   -> false
            (Just True,  (:|:), _)            -> true
            (Just False, (:|:), _)            -> r
            (_,          (:|:), Just True)    -> true
            (_,          (:|:), Just False)   -> l
            (Just True,  (:=>:), _)           -> r
            (Just False, (:=>:), _)           -> true
            (_,          (:=>:), Just True)   -> true
            (_,          (:=>:), Just False)  -> (.~.) l
            (Just True,  (:<=>:), _)          -> r
            (Just False, (:<=>:), _)          -> (.~.) r
            (_,          (:<=>:), Just True)  -> l
            (_,          (:<=>:), Just False) -> (.~.) l
            _                                 -> fm
      simplifyNotCombine ((:~:) f) = f
      simplifyNotCombine _ = fm
      simplifyNotPred (Apply pr ts)
          | pr == fromBool False = pApp (fromBool True) ts
          | pr == fromBool True = pApp (fromBool False) ts
          | True = (.~.) (pApp pr ts)
      simplifyNotPred (Constant x) = pApp (fromBool (not x)) []
      simplifyNotPred (Equal t1 t2) = t1 .!=. t2
      simplifyNotPred (NotEqual t1 t2) = t1 .=. t2
      -- Return a Maybe Bool depending upon whether a formula is true,
      -- false, or something else.
      pBool :: formula -> Maybe Bool
      pBool = foldF (\ _ _ _ -> Nothing) (\ _ -> Nothing) p
          where p (Apply pr _ts) =
                    if pr == fromBool True
                    then Just True
                    else if pr == fromBool False
                         then Just False
                         else Nothing
                p _ = Nothing
{-

let rec psimplify fm =
  match fm with
  | Not p -> psimplify1 (Not(psimplify p))
  | And(p,q) -> psimplify1 (And(psimplify p,psimplify q))
  | Or(p,q) -> psimplify1 (Or(psimplify p,psimplify q))
  | Imp(p,q) -> psimplify1 (Imp(psimplify p,psimplify q))
  | Iff(p,q) -> psimplify1 (Iff(psimplify p,psimplify q))
  | _ -> fm;;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
psimplify <<(true ==> (x <=> false)) ==> ~(y \/ false /\ z)>>;;

psimplify <<((x ==> y) ==> true) \/ ~false>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Some operations on literals.                                              *)
(* ------------------------------------------------------------------------- *)

let negative = function (Not p) -> true | _ -> false;;

let positive lit = not(negative lit);;

let negate = function (Not p) -> p | p -> Not p;;

(* ------------------------------------------------------------------------- *)
(* Negation normal form.                                                     *)
(* ------------------------------------------------------------------------- *)

let rec nnf fm =
  match fm with
  | And(p,q) -> And(nnf p,nnf q)
  | Or(p,q) -> Or(nnf p,nnf q)
  | Imp(p,q) -> Or(nnf(Not p),nnf q)
  | Iff(p,q) -> Or(And(nnf p,nnf q),And(nnf(Not p),nnf(Not q)))
  | Not(Not p) -> nnf p
  | Not(And(p,q)) -> Or(nnf(Not p),nnf(Not q))
  | Not(Or(p,q)) -> And(nnf(Not p),nnf(Not q))
  | Not(Imp(p,q)) -> And(nnf p,nnf(Not q))
  | Not(Iff(p,q)) -> Or(And(nnf p,nnf(Not q)),And(nnf(Not p),nnf q))
  | _ -> fm;;

(* ------------------------------------------------------------------------- *)
(* Roll in simplification.                                                   *)
(* ------------------------------------------------------------------------- *)

let nnf fm = nnf(psimplify fm);;
-}

-- |Eliminate => and <=> and move negations inwards:
-- 
-- @
-- Formula      Rewrites to
--  P => Q      ~P | Q
--  P <=> Q     (P & Q) | (~P & ~Q)
-- ~∀X P        ∃X ~P
-- ~∃X P        ∀X ~P
-- ~(P & Q)     (~P | ~Q)
-- ~(P | Q)     (~P & ~Q)
-- ~~P  P
-- @
-- 
nnf :: FirstOrderLogic formula term v p f => formula -> formula
nnf fm =
    foldF nnfQuant nnfCombine (\ _ -> fm) fm
    where
      nnfQuant op v p = quant op v (nnf p)
      nnfCombine ((:~:) p) = foldF nnfNotQuant nnfNotCombine (\ _ -> fm) p
      nnfCombine (BinOp p (:=>:) q) = nnf ((.~.) p) .|. (nnf q)
      nnfCombine (BinOp p (:<=>:) q) =  (nnf p .&. nnf q) .|. (nnf ((.~.) p) .&. nnf ((.~.) q))
      nnfCombine (BinOp p (:&:) q) = nnf p .&. nnf q
      nnfCombine (BinOp p (:|:) q) = nnf p .|. nnf q
      nnfNotQuant All v p = exists v (nnf ((.~.) p))
      nnfNotQuant Exists v p = for_all v (nnf ((.~.) p))
      nnfNotCombine ((:~:) p) = nnf p
      nnfNotCombine (BinOp p (:&:) q) = nnf ((.~.) p) .|. nnf ((.~.) q)
      nnfNotCombine (BinOp p (:|:) q) = nnf ((.~.) p) .&. nnf ((.~.) q)
      nnfNotCombine (BinOp p (:=>:) q) = nnf p .&. nnf ((.~.) q)
      nnfNotCombine (BinOp p (:<=>:) q) = (nnf p .&. nnf ((.~.) q)) .|. nnf ((.~.) p) .&. nnf q
{-
(* ------------------------------------------------------------------------- *)
(* Example of NNF function in action.                                        *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
let fm = <<(p <=> q) <=> ~(r ==> s)>>;;

let fm' = nnf fm;;

tautology(Iff(fm,fm'));;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Simple negation-pushing when we don't care to distinguish occurrences.    *)
(* ------------------------------------------------------------------------- *)

let rec nenf fm =
  match fm with
    Not(Not p) -> nenf p
  | Not(And(p,q)) -> Or(nenf(Not p),nenf(Not q))
  | Not(Or(p,q)) -> And(nenf(Not p),nenf(Not q))
  | Not(Imp(p,q)) -> And(nenf p,nenf(Not q))
  | Not(Iff(p,q)) -> Iff(nenf p,nenf(Not q))
  | And(p,q) -> And(nenf p,nenf q)
  | Or(p,q) -> Or(nenf p,nenf q)
  | Imp(p,q) -> Or(nenf(Not p),nenf q)
  | Iff(p,q) -> Iff(nenf p,nenf q)
  | _ -> fm;;

let nenf fm = nenf(psimplify fm);;

(* ------------------------------------------------------------------------- *)
(* Some tautologies remarked on.                                             *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
tautology <<(p ==> p') /\ (q ==> q') ==> (p /\ q ==> p' /\ q')>>;;
tautology <<(p ==> p') /\ (q ==> q') ==> (p \/ q ==> p' \/ q')>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Disjunctive normal form (DNF) via truth tables.                           *)
(* ------------------------------------------------------------------------- *)

let list_conj l = if l = [] then True else end_itlist mk_and l;;

let list_disj l = if l = [] then False else end_itlist mk_or l;;

let mk_lits pvs v =
  list_conj (map (fun p -> if eval p v then p else Not p) pvs);;

let rec allsatvaluations subfn v pvs =
  match pvs with
    [] -> if subfn v then [v] else []
  | p::ps -> let v' t q = if q = p then t else v(q) in
             allsatvaluations subfn (v' false) ps @
             allsatvaluations subfn (v' true) ps;;

let dnf fm =
  let pvs = atoms fm in
  let satvals = allsatvaluations (eval fm) (fun s -> false) pvs in
  list_disj (map (mk_lits (map (fun p -> Atom p) pvs)) satvals);;

(* ------------------------------------------------------------------------- *)
(* Examples.                                                                 *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
let fm = <<(p \/ q /\ r) /\ (~p \/ ~r)>>;;

dnf fm;;

print_truthtable fm;;

dnf <<p /\ q /\ r /\ s /\ t /\ u \/ u /\ v>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* DNF via distribution.                                                     *)
(* ------------------------------------------------------------------------- *)

let rec distrib fm =
  match fm with
    And(p,(Or(q,r))) -> Or(distrib(And(p,q)),distrib(And(p,r)))
  | And(Or(p,q),r) -> Or(distrib(And(p,r)),distrib(And(q,r)))
  | _ -> fm;;

let rec rawdnf fm =
  match fm with
    And(p,q) -> distrib(And(rawdnf p,rawdnf q))
  | Or(p,q) -> Or(rawdnf p,rawdnf q)
  | _ -> fm;;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
rawdnf <<(p \/ q /\ r) /\ (~p \/ ~r)>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* A version using a list representation.                                    *)
(* ------------------------------------------------------------------------- *)

let distrib s1 s2 = setify(allpairs union s1 s2);;

let rec purednf fm =
  match fm with
    And(p,q) -> distrib (purednf p) (purednf q)
  | Or(p,q) -> union (purednf p) (purednf q)
  | _ -> [[fm]];;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
purednf <<(p \/ q /\ r) /\ (~p \/ ~r)>>;;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Filtering out trivial disjuncts (in this guise, contradictory).           *)
(* ------------------------------------------------------------------------- *)

let trivial lits =
  let pos,neg = partition positive lits in
  intersect pos (image negate neg) <> [];;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
filter (non trivial) (purednf fm);;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* With subsumption checking, done very naively (quadratic).                 *)
(* ------------------------------------------------------------------------- *)

let simpdnf fm =
  if fm = False then [] else if fm = True then [[]] else
  let djs = filter (non trivial) (purednf(nnf fm)) in
  filter (fun d -> not(exists (fun d' -> psubset d' d) djs)) djs;;

(* ------------------------------------------------------------------------- *)
(* Mapping back to a formula.                                                *)
(* ------------------------------------------------------------------------- *)

let dnf fm = list_disj(map list_conj (simpdnf fm));;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
let fm = <<(p \/ q /\ r) /\ (~p \/ ~r)>>;;
dnf fm;;
tautology(Iff(fm,dnf fm));;
END_INTERACTIVE;;

(* ------------------------------------------------------------------------- *)
(* Conjunctive normal form (CNF) by essentially the same code.               *)
(* ------------------------------------------------------------------------- *)

let purecnf fm = image (image negate) (purednf(nnf(Not fm)));;

let simpcnf fm =
  if fm = False then [[]] else if fm = True then [] else
  let cjs = filter (non trivial) (purecnf fm) in
  filter (fun c -> not(exists (fun c' -> psubset c' c) cjs)) cjs;;
-}

simpcnf :: forall formula term v p f. (FirstOrderLogic formula term v p f, Literal formula) => formula -> S.Set (S.Set formula)
simpcnf fm =
    foldF (\ _ _ _ -> cjs') (\ _ -> cjs') p fm
    where
      p (Apply pr _ts)
          | pr == fromBool False = S.empty
          | pr == fromBool True = S.singleton S.empty
          | True = cjs'
      p (Equal _ _) = cjs'
      p (NotEqual _ _) = cjs'
      p (Constant _) = cjs'
      -- Discard any clause that is the proper subset of another clause
      cjs' = S.filter keep cjs
      keep x = not (S.or (S.map (S.isProperSubsetOf x) cjs))
      cjs = S.filter (not . trivial) (purecnf (nnf fm))

-- |Harrison page 59.  Look for complementary pairs in a clause.
trivial :: Literal lit => S.Set lit -> Bool
trivial lits =
    not . S.null $ S.intersection (S.map invert n) p
    where
      (n, p) = S.partition inverted lits

-- | CNF: (a | b | c) & (d | e | f)
purecnf :: forall formula term v p f. FirstOrderLogic formula term v p f => formula -> S.Set (S.Set formula)
purecnf fm =
    foldF (\ _ _ _ -> ss fm) c (\ _ -> ss fm) fm
    where
      ss = S.singleton . S.singleton
      -- ((a | b) & (c | d) | ((e | f) & (g | h)) -> ((a | b | e | f) & (c | d | e | f) & (c | d | e | f) & (c | d | g | h))
      c (BinOp l (:|:) r) =
          let lss = purecnf l
              rss = purecnf r in
          S.distrib lss rss
      -- [[a,b],[c,d]] | [[e,f],[g,y]] -> [[a,b],[c,d],[e,f],[g,h]]
      -- a & b -> [[a], [b]]
      c (BinOp l (:&:) r) = S.union (purecnf l) (purecnf r)
      c _ = ss fm
{-

let cnf fm = list_conj(map list_disj (simpcnf fm));;

(* ------------------------------------------------------------------------- *)
(* Example.                                                                  *)
(* ------------------------------------------------------------------------- *)

START_INTERACTIVE;;
let fm = <<(p \/ q /\ r) /\ (~p \/ ~r)>>;;
cnf fm;;
tautology(Iff(fm,cnf fm));;
END_INTERACTIVE;;
-}
