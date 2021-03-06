(*--build-config
variables:LIB=../../lib;
other-files:$LIB/ext.fst $LIB/set.fsi $LIB/set.fst $LIB/heap.fst $LIB/st.fst $LIB/all.fst $LIB/list.fst stack.fst listset.fst  $LIB/ghost.fst located.fst lref.fst stackAndHeap.fst sst.fst sstCombinators.fst
  --*)
module Factorial
open SSTCombinators
open StackAndHeap
open SST
open Heap
open Lref  open Located
open Stack
open Set
open Prims
open List
open ListSet

val factorial : nat -> Tot nat
let rec factorial n =
match n with
| 0 -> 1
| n -> n * factorial (n - 1)

(* val factorialGuardLC :  n:nat -> li:(lref nat)  -> smem -> type *)
type factorialGuardLC (n:nat) (li : lref nat) (m:smem) =
  (liveRef li m) && (not ((loopkupRef li m) = n))

val factorialGuard :  n:nat -> li:(lref nat)  -> unit
  -> whileGuard (fun m -> b2t (liveRef li m))
                (factorialGuardLC n li)
let factorialGuard n li u = not (memread li = n)
(* the guard of a while loop is not supposed to change the memory*)


type  loopInv (li : lref nat) (res : lref nat) (m:smem) =
  liveRef li m /\ liveRef res m
    /\ (loopkupRef res m = factorial (loopkupRef li m))
    /\ (~ (li = res))

open Ghost
val factorialLoopBody :
  n:nat -> li:(lref nat) -> res:(lref nat)
  -> unit ->
  whileBody (loopInv li res) (factorialGuardLC n li)
  (hide (union (singleton (Ref li)) (singleton (Ref res))))
      (*SST unit (fun m -> loopInv li res (mtail m)) (fun m0 _ m1 -> loopInv li res (mtail m1))*)
let factorialLoopBody (n:nat) (li:(lref nat)) (res:(lref nat)) u =
  let liv = memread li in
  let resv = memread res in
  memwrite li (liv + 1);
  memwrite res ((liv+1) * resv)
 (*  (eunionUnion li res)*)
val factorialLoop : n:nat -> li:(lref nat) -> res:(lref nat)
  -> Mem unit (fun m -> mreads li 0 m /\ mreads res 1 m  /\ ~(li=res))
              (fun m0 _ m1 -> mreads res (factorial n) m1)
              (hide (union (singleton (Ref li)) (singleton (Ref res))))
let factorialLoop (n:nat) (li:(lref nat)) (res:(lref nat)) =
  scopedWhile
    (loopInv li res)
    (factorialGuardLC n li)
    (factorialGuard n li)
    (hide (union (singleton (Ref li)) (singleton (Ref res))))
    (factorialLoopBody n li res)

(*val factorialLoop2 : n:nat -> li:(lref nat) -> res:(lref nat)
  -> Mem unit (fun m -> mreads li 0 m /\ mreads res 1 m  /\ ~(li=res))
              (fun m0 _ m1 -> mreads res (factorial n) m1)
let factorialLoop2 (n:nat) (li:(lref nat)) (res:(lref nat)) =
  scopedWhile1
    li
    (fun liv -> not (liv = 1))
    (loopInv li res)
    (factorialLoopBody n li res)*)


val loopyFactorial : n:nat
  -> WNSC nat (fun m -> True)
              (fun _ rv _ -> (rv == (factorial n)))
              (hide empty)
let loopyFactorial n =
  let li = salloc 0 in
  let res = salloc 1 in
  (factorialLoop n li res);
  let v=memread res in
  v

val loopyFactorial2 : n:nat
  -> Mem nat (fun m -> True)
              (fun _ rv _ -> rv == (factorial n))
              (hide empty)
let loopyFactorial2 n =
  pushStackFrame ();
    let li:(lref nat) = salloc 0 in
    let res:(lref nat) = salloc 1 in
    (scopedWhile1
      li
      (fun liv -> not (liv = n))
      (loopInv li res)
      (eunion (only  li) (only res))
      (fun u ->
        let liv = memread li in
        let resv = memread res in
        memwrite li (liv + 1);
        memwrite res ((liv+1) * resv)));
    let v=memread res in
    popStackFrame (); v
