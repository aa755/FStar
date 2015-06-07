(*--build-config
    options:--admit_fsi Set;
    variables:LIB=../../lib;
    other-files:$LIB/ext.fst $LIB/set.fsi $LIB/heap.fst $LIB/st.fst $LIB/list.fst stack.fst listset.fst
  --*)

module StructuredMem
open Heap
open Stack
open Set
open Prims
open List
open ListSet
type sidt = nat

(*How does List.memT work? is equality always decidable?*)
type memStackAux = Stack (sidt * heap) * list sidt

val wellFormedAux : list sidt -> list sidt -> Tot bool
let  wellFormedAux stids idhistory = (lsubset stids idhistory) && (noRepeats stids)

val wellFormed : memStackAux -> Tot bool
let wellFormed x =
let stids = mapT fst (fst x) in
  let idhistory = snd x in (wellFormedAux stids idhistory)

type memStack = x:memStackAux{wellFormed x}


(* Should we also include sizes of refs in order to enable reasoninag about memory usage of programs?*)
(* Even a simple notion of size, e.g. 1 unit per object, can help us reason about (lack of) memory leaks.*)
(* What is the size of functions? Does it make even make sense to store a function at a reference? Would it be possible to transpile such a construct? *)
type smem = heap * memStack


let hp (s : smem) = fst s

val st : smem -> Tot (Stack (sidt * heap))
let st (s : smem) = fst (snd s)

val heapAndStack : smem -> Tot (heap * (Stack (sidt * heap)))
let heapAndStack (s : smem) = (hp s, st s)

val heapAndStackTail : smem -> Tot (heap * (Stack (sidt * heap)))
let heapAndStackTail (s : smem) = (hp s, stail (st s))

val mstail : smem -> Tot ((Stack (sidt * heap)))
let mstail (s : smem) = stail (st s)

val sids : smem -> Tot (list sidt)
let sids (m : smem) = mapT fst (st m)

val idHistory : smem -> Tot (list sidt)
let idHistory (s : smem) = snd (snd s)

let sid (s : (sidt * heap)) = fst s

val topst : (s:smem{isNonEmpty (st s)}) -> Tot  (sidt * heap)
let topst ss = (top (st ss))

val topstb : (s:smem{isNonEmpty (st s)}) ->  Tot heap
let topstb ss = snd (topst ss)

val topstid : (s:smem{isNonEmpty (st s)}) ->  Tot sidt
let topstid ss = fst (topst ss)

type refLocType =
  | InHeap : refLocType
  | InStack : id:sidt -> refLocType

assume val refLoc : #a:Type -> ref a -> Tot refLocType

new_effect StSTATE = STATE_h smem

val stackBlockAtLoc : sidt  -> (Stack (sidt * heap)) -> Tot (option heap)
let rec stackBlockAtLoc id sp =
  match sp with
  | Nil -> None
  | h::tl -> if (id=(fst h)) then Some (snd h) else stackBlockAtLoc id tl


val blockAtLoc : smem -> refLocType  -> Tot (option heap)
let blockAtLoc m rl =
match rl with
| InHeap -> Some (hp m)
| InStack id -> stackBlockAtLoc id (st m)


(* are there associative maps in FStar? *)
(*  proof by computation *)

val writeMemStack : #a:Type -> (ref a) -> (Stack (sidt * heap)) -> sidt -> a -> Tot (Stack (sidt * heap))
let rec writeMemStack r ms s v =
match ms with
| [] -> []
| h::tl ->
  (if (fst h = s) then ((fst h, (upd (snd h) r v))::tl) else h::(writeMemStack r tl s v))

val writeMemStackSameIDs : #a:Type -> r:(ref a) -> ms:(Stack (sidt * heap))
  -> s:sidt -> v:a
  -> Lemma (ensures ((mapT fst ms) = (mapT fst (writeMemStack r ms s v))))
          (* [SMTPat (writeMemStack r ms s v)] *)
let rec writeMemStackSameIDs r ms s v =
match ms with
| Nil -> ()
| h::tl ->   if (fst h = s) then () else (writeMemStackSameIDs r tl s v)



val writeMemStackWellFormed : #a:Type -> r:(ref a)
  -> his : (list sidt)
  -> ms:(Stack (sidt * heap))
  -> s:sidt -> v:a
  -> Lemma
      (requires (wellFormed (ms,his)))
      (ensures (wellFormed (writeMemStack r ms s v,his)))
      [SMTPat (writeMemStack r ms s v)]
let writeMemStackWellFormed r his ms s v =
(writeMemStackSameIDs r ms s v) ; admit ()
(* what is the analog of transport / eq_ind?*)


val writeMemStackSameStail : #a:Type -> r:(ref a) -> ms:(Stack (sidt * heap))
  -> s:sidt -> v:a
  -> Lemma (ensures ((stail ms) = (stail (writeMemStack r ms s v))))
         (*  [SMTPat (writeMemStack r ms s v)] *)
let rec writeMemStackSameStail r ms s v = ()


val refExistsInStack : #a:Type -> (ref a)
  -> id:sidt -> (Stack (sidt * heap)) -> Tot bool
let refExistsInStack r id ms =
match  (stackBlockAtLoc id ms)  with
                | Some b -> Heap.contains b r
                | None -> false

val refExistsInMem : #a:Type -> (ref a) -> smem ->  Tot bool
let refExistsInMem (#a:Type) (r:ref a) (m:smem) =
match (refLoc r) with
| InHeap -> Heap.contains (hp m) r
| InStack id -> refExistsInStack r id (st m)

val writeMemStackExists : #a:Type -> rw:(ref a) -> r: (ref a)
  -> ms:(Stack (sidt * heap))
  -> id:sidt -> v:a
  -> Lemma
      (requires (refExistsInStack r id ms))
      (ensures (refExistsInStack r  id (writeMemStack rw ms id v)))
      [SMTPat (writeMemStack rw ms id v)]
let rec writeMemStackExists rw r ms id v =
match ms with
| Nil -> ()
| h::tl ->   if (fst h = id) then () else ((writeMemStackExists rw r tl id v))

(* ((writeMemStackLem r ms s v)) *)

val writeMemAux : #a:Type -> (ref a) -> m:smem -> a -> Tot smem
let writeMemAux r m v =
  match (refLoc r) with
  | InHeap -> ((upd (hp m) r v), snd m)
  | InStack s -> ((hp m), ((writeMemStack r (st m) s v), idHistory m))


val writeMemAuxPreservesExists :  #a:Type -> r:(ref a) -> m:smem -> v:a ->
Lemma (requires (refExistsInMem r m))
      (ensures (refExistsInMem r (writeMemAux r m v)))
      [SMTPat (writeMemAux r m v)]
let rec writeMemAuxPreservesExists r m v =  ()

val writeMemAuxPreservesStail :  #a:Type -> r:(ref a) -> m:smem -> v:a ->
Lemma (requires (is_InStack (refLoc r)))
  (ensures heapAndStackTail m = heapAndStackTail (writeMemAux r m v))
let rec writeMemAuxPreservesStail r m v =  ()

val loopkupRefStack : #a:Type -> r:(ref a) -> id:sidt -> ms:(Stack (sidt * heap)){refExistsInStack r id ms}  ->  Tot a
let rec loopkupRefStack r id ms =
match ms with
| h::tl ->
    if (fst h = id) then  sel (snd h) r else (loopkupRefStack r id tl)


(* it is surprising that sel always returns something; It might be tricky to implement it.
   What prevents me from creating a ref of an empty type? Perhaps it is impossible to create a member
   of the type (ref False) . For example, the memory allocation operator, which creates a new (ref 'a)
   requires an initial value of type 'a
*)
val loopkupRef : #a:Type -> r:(ref a) -> m:smem{(refExistsInMem r m) == true} ->  Tot a
let loopkupRef r m =
match (refLoc r) with
| InHeap -> (sel (hp m) r)
| InStack id -> loopkupRefStack r id (st m)

val readAfterWriteStack :
  #a:Type -> r:(ref a) -> v:a -> m:(Stack (sidt * heap)) -> id:sidt ->
  Lemma (requires (refExistsInStack r id m))
        (ensures ((refExistsInStack r id m) /\ loopkupRefStack r id (writeMemStack r m id v) == v))
let rec readAfterWriteStack r v m id =
match m with
| [] -> ()
| h::tl -> if (fst h = id) then () else ((readAfterWriteStack r v tl id))


val readAfterWrite : #a:Type -> r:(ref a) -> v:a -> m:smem ->
  Lemma (requires (refExistsInMem r m))
        (ensures ((refExistsInMem r m) /\ loopkupRef r (writeMemAux r m v) == v))
        [SMTPat (writeMemAux r m v)]
let readAfterWrite r v m =
match (refLoc r) with
| InHeap -> ()
| InStack id -> readAfterWriteStack r v (st m) id

(*should extend to types with decidable equality*)
val is1SuffixOf : list sidt -> list sidt -> Tot bool
let is1SuffixOf lsmall lbig =
match lbig with
| [] -> false
| h::tl -> tl=lsmall


type allocateInBlock (#a:Type) (r: ref a) (h0 : heap) (h1 : heap) (init : a)   = not(Heap.contains h0 r) /\ Heap.contains h1 r /\  h1 == upd h0 r init

kind Pre  = smem -> Type
kind Post (a:Type) = a -> smem -> Type

effect SST (a:Type) (pre:Pre) (post: (smem -> Post a)) =
        StSTATE a
              (fun (p:Post a) (h:smem) -> pre h /\ (forall a h1. (pre h  /\ post h a h1) ==> p a h1)) (* WP *)
              (fun (p:Post a) (h:smem) -> (forall a h1. (pre h  /\ post h a h1) ==> p a h1))          (* WLP *)

assume val halloc:  #a:Type -> init:a -> SST (ref a)
                                         (fun m -> True)
                                         (fun m0 r m1 -> allocateInBlock r (hp m0)  (hp m1) init /\ (snd m0 = snd m1) /\ refLoc r == InHeap)

assume val salloc:  #a:Type -> init:a -> SST (ref a)
     (fun m -> b2t (isNonEmpty (st m))) (*why is "== true" required here, but not at other places? : *)
     (*Does F* have (user defined?) implicit coercions? : Not yet *)
     (fun m0 r m1 ->
          (isNonEmpty (st m0)) /\ (isNonEmpty (st m1))
          /\ allocateInBlock r (topstb m0) (topstb m1) init
          /\ refLoc r = InStack (topstid m0) /\ (topstid m0 = topstid m1)
          /\ heapAndStackTail m0 = heapAndStackTail m1 /\ idHistory m0 = idHistory m1)

assume val read:  #a:Type -> r:(ref a) -> SST a
	  (fun m -> b2t (refExistsInMem r m))
    (fun m0 a m1 -> m0=m1 /\ (refExistsInMem r m0) /\ loopkupRef r m0 = a)

assume val write:  #a:Type -> r:(ref a) -> v:a ->
  SST unit
	    (fun m -> b2t (refExistsInMem r m))
      (fun m0 a m1 -> (refExistsInMem r m1) /\ (writeMemAux r m0 v) =  m1
        /\ (writeMemAux r m0 v) =  m1 /\ idHistory m0 = idHistory m1)

(*make sure that the ids are monotone *)
assume val pushStackFrame:  unit -> SST unit
    (fun m -> True)
    (fun m0 a m1 -> (heapAndStackTail m1 = heapAndStack m0) /\ (isNonEmpty (st m1)) /\ topstb m1 = emp /\ is1SuffixOf (idHistory m0)  (idHistory m1))

assume val popStackFrame:  unit -> SST unit
    (fun m -> b2t (isNonEmpty (st m)))
    (fun m0 a m1 -> heapAndStackTail m0 == heapAndStack m1)


(** Injection of DIV effect into the new effect, mostly copied from prims.fst*)
kind SSTPost (a:Type) = STPost_h smem a

sub_effect
  DIV   ~> StSTATE = fun (a:Type) (wp:PureWP a) (p : SSTPost a) (h:smem) -> wp (fun a -> p a h)

(** algebraic properties of memory operations*)

(** withNewStackFrame combinator *)

effect WNSC (#a:Type) (post: (smem -> Post a)) =
(*instead of SST, this could be a weaker effect (in the lattic) which
    does not allow pushing and popping stack frames *)
  SST a
      (fun m -> isNonEmpty (st m) /\ topstb m = emp)
      (fun m0 a m1 -> post m0 a m1)

(*
val withNewStackFrame : #a:Type -> post:(smem -> Post a) -> body:(WNSC post)
      -> SST a (fun m -> True) (fun m0 a m1 -> post m0 a m1)
*)
let withNewStackFrame post body =
  pushStackFrame ();
  body;
  popStackFrame ()