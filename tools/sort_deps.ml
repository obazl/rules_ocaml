open Core
(* open Core_kernel *)
open Map
open Printf

let file = "deps.depends"

(* running tallys for deps *)
(* let unresolved_deps = map of module name : count *)

let compare_deps (amod, afile, adeps) (bmod, bfile, bdeps) =

  (* For each dep we maintain an "unresolved" flag, which is 3-valued,
     i.e. "not unresolved" does not mean "resolved".  Instead, it
     means "not counted in the global unresolved tally".  So
     "unresolved True" means two things: 1) the dep is not in the
     depstack, and 2) the global tally for the dep has been
     incremented.  This allows us to decided when to decrement the tally. *)

  (* For example, suppose we are comparing a and b, and b.m in a.deps
     - a depends on b. Suppose furthermore that a's b dep is marked as
     "unresolved", and the tally is > 0.  That means we handle a
     previously and its dep on b was unresolved - we incremented the
     tally for b and marked it as unresolved in a.  So we can
     decrement the tally.  Suppose by contrast that a's b dep is not
     marked "unresolved", and the global tally is n > 0. That would
     mean that n preceding modules have an unresolved dep on b, and
     further that we have not handled a before - we did not previously
     fail to resolve it's b dep, so it has not been marked as
     "unresolved" (which does not mean it has been resolved - that's
     what we're about to do).  In this case we do not decrement the
     counter, we leave "unresolved" as false, and we pass b back up
     the chain to resolve the unresolved deps.  (After which "not
     unresolved" comes to mean "resolved".) *)

  (* When comparing a and b, we first check the global unresolved
     tally for b.  If the tally = 0, we know that a's b dep must not
     be marked as unresolved - if it were, the tally would be n >
     0. But it is not yet resolved either - we need to resolve it by
     putting b before a in the deplist. So we swap a and b, do nothing
     with the tally, and the leave the unresolved flag false - which
     now means "resolved", since we put a and b in dependency order.
     If the tally is n > 0, we check to see if a's b dep is marked as
     unresolved.  If it is not, that means we're seeing a for the
     first time, so we just resolve it (swap places of a and b, so b
     precedes a), leave "unresolved" false, and leave the tally
     untouched.  This will propagate b back up the list.  If it is
     marked unresolved, we know we have seen a before and marked its b
     dep unresolved. So we swap a and b, reset unresolved to false,
     and decrement the counter.  b will now percolate upwards to
     resolve the unresolved deps. *)

  (* if a.modulename in b.deps then a < b *)
  if List.exists bdeps (fun bdep -> bdep = amod)
  then begin incr unresolved_deps; -1 ; end
  (* else if b.modulename in a.deps, then a > b *)
  else if List.exists  adeps (fun adep -> adep = bmod)
  then 1
  else 0

let rec print_deps = function
    [] -> ()
  | dep :: rest -> print_string dep ;
                   if not (List.is_empty rest) then print_string " " ;
                   print_deps rest

let print_depline = function
    (* [] -> () *)
  | (m,f,deps) -> print_string m ;
                  print_string " " ;
                  print_string f ;
                  print_string " [" ;
                  print_deps deps ;
                  print_string "]"

let rec print_list = function
    [] -> ()
  | e::l -> print_depline e ;
            print_string "\n" ;
            print_list l

let build_depline l =
  let flds = String.split_on_chars l ~on:[' '] in
  let depline = 
    match flds with
    | fname :: rest ->
       (Filename.basename  fname |> String.capitalize |> Filename.chop_extension),
       String.rstrip ?drop:(Some (fun x -> x = ':')) fname,
       rest
    | [] -> ("","",[]);
  in
  depline

let () =
  let ic = open_in file in
  let rec build_list l =
    match input_line ic with
    | line -> build_list (build_depline line :: l)
    | exception End_of_file -> close_in ic;
                               List.rev l;
  in
  let x = build_list([])
  in
  let sorted_deps = List.sort ~compare:compare_deps x;
  in
  print_list sorted_deps ;
  print_string "Count: " ;
  print_int !unresolved_deps ;
  print_newline ();
