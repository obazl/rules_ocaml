(* first using flat namespace *)
Alpha__Beta1__Gamma__Hello.msg() ;;
Alpha__Beta1__Gamma__Goodbye.msg() ;;

(* same, in hierarchical namespace *)
Alpha.Beta1.Gamma.Hello.msg() ;;
Alpha.Beta1.Gamma.Goodbye.msg() ;;

(* let's open and use some namespaces. *)
open Alpha ;;
Beta1.Gamma.Hello.msg()

open Alpha.Beta1 ;;
Gamma.Hello.msg()

open Alpha.Beta1.Gamma ;;
Hello.msg() ;;

(* We just opened Alpha.Beta1.Gamma, so this opens Alpha.Beta1.Gamma.Hello: *)
open Hello ;;
msg() ;;

open Alpha.Beta1.Gamma.Hello ;;
msg() ;;

Alpha.Gamma.Howdy.msg() ;;

open Alpha.Gamma ;;
Howdy.msg() ;;

open Alpha.Gamma.Howdy ;;
msg() ;;

(* We've already opened Alpha.Beta1, so we can do this: *)
open Gamma.Goodbye ;;
msg() ;;

(* or this, since we've already opent Alpha.Beta1.Gamma: *)
open Goodbye ;;
msg() ;;

Goodbye.msg() ;;
open Alpha ;;
open Alpha.Beta2 ;;
open Alpha.Beta2.Gamma ;;
(* open Alpha.Beta2.Gamma.Gday ;; *)
Gday.msg() ;;
