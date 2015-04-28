(*
   Copyright 2015 Chantal Keller and Catalin Hritcu, Microsoft Research and Inria

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)


module Wf


type acc (a:Type) (r:(a -> a -> Type)) (x:a) : Type =
  | AccIntro : (y:a -> r y x -> Tot (acc a r y)) -> acc a r x

type well_founded (a:Type) (r:(a -> a -> Type)) = x:a -> acc a r x

val acc_inv : r:('a -> 'a -> Type) -> x:'a -> a:(acc 'a r x) ->
              Tot (e:(y:'a -> r y x -> Tot (acc 'a r y)){e << a})
let acc_inv x a = match a with | AccIntro z h1 -> h1

assume val axiom1 : a:Type -> b:Type -> f:(a -> Tot b) -> x:a ->
                    Lemma (f x << f)

(* Can't prove it is total : I know that [acc_inv x a << a]
   but from this I cannot deduce [acc_inv x a y h << a] *)
val fix_F : #aa:Type -> #r:(aa -> aa -> Type) -> #p:(aa -> Type) ->
            (x:aa -> (y:aa -> r y x -> Tot (p y)) -> Tot (p x)) ->
            x:aa -> a:(acc aa r x) -> Tot (p x) (decreases a)
(*
val fix_F : r:('a -> 'a -> Type) -> p:('a -> Type) ->
            (x:'a -> (y:'a -> r y x -> p y) -> p x) ->
            x:'a -> acc 'a r x -> p x
*)
let rec fix_F #aa #r #p f x a =
  f x (fun y h ->
(*
         axiom1 a (r y x -> Tot (acc a r y)) (acc_inv x a) y;
         axiom1 (acc_inv x a y) h;
*)
         fix_F #aa #r #p f y (acc_inv x a y h))

val fix : r:('a -> 'a -> Type) -> well_founded 'a r -> p:('a -> Type) ->
          (x:'a -> (y:'a -> r y x -> p y) -> p x) -> x:'a -> p x
let fix rwf f x = fix_F f x (rwf x)