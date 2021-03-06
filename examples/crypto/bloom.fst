(*--build-config
    options:--z3timeout 10 --prims ../../lib/prims.fst --verify_module Bloom --admit_fsi FStar.Seq --max_fuel 4 --initial_fuel 0 --max_ifuel 2 --initial_ifuel 1;
    variables:LIB=../../lib
              CONTRIB=../../contrib;
    other-files:
            $LIB/ext.fst $LIB/classical.fst
            $LIB/set.fsi $LIB/set.fst
            $LIB/heap.fst $LIB/st.fst $LIB/all.fst
            $LIB/string.fst $LIB/list.fst
	    $LIB/bytes.fst
            $LIB/seq.fsi $LIB/seqproperties.fst
            $LIB/io.fsti
            $CONTRIB/Platform/fst/Bytes.fst
            $CONTRIB/CoreCrypto/fst/CoreCrypto.fst
	    bloom-format.fst
  --*)

module Bloom

open FStar.All
open FStar.String
open FStar.IO
open FStar.Heap
open FStar.Seq
open FStar.SeqProperties

open Format

logic type Pos (i: int) = (i > 0)
type ln_t = ln:uint16{Pos ln}
type hash = h:seq byte{Seq.length h >= 2}
type text = seq byte
type hash_fn = text -> Tot hash
type bloom (ln:ln_t) = bl:seq bool{Seq.length bl = ln}

logic type Le (ln:ln_t) (bl1:bloom ln) (bl2:bloom ln) =
  forall i . (0 <= i && i < ln) ==> ((not (Seq.index bl1 i)) || (Seq.index bl2 i))

val set: ln:ln_t -> bl:bloom ln -> i:uint16 -> Tot (bl':bloom ln{Le ln bl bl'})
let set ln bl i =
  let i' = op_Modulus i ln in
  Seq.upd bl i' true

val is_set: ln:ln_t -> bl:bloom ln -> i:uint16 -> Tot (b:bool)
let is_set ln bl i =
  let i' = op_Modulus i ln in
  Seq.index bl i'

val create: ln:ln_t -> Tot (bl:bloom ln)
let create ln = Seq.create ln false

val check: ln:ln_t -> h:hash_fn -> n:uint16 -> x:text -> bl:bloom ln -> Tot (b:bool)
let rec check ln h n x bl =
  if n > 0 then
  begin
    let pt = Seq.append (uint16_to_bytes n) x in
    let hs = Seq.slice (h pt) 0 2 in
    let b = is_set ln bl (bytes_to_uint16 hs) in
    if b then check ln h (n-1) x bl
    else false
  end
  else true

val add: ln:ln_t -> h:hash_fn -> n:uint16 -> x:text -> bl:bloom ln -> Tot (bl':bloom ln{Le ln bl bl' /\ check ln h n x bl'})
let rec add ln h n x bl =
  if n > 0 then
  begin
    let pt = Seq.append (uint16_to_bytes n) x in
    let hs = Seq.slice (h pt) 0 2 in
    let i = (bytes_to_uint16 hs) in
    let bl' = set ln bl i in
    let bl'' = add ln h (n-1) x bl' in
    bl''
  end
  else bl
