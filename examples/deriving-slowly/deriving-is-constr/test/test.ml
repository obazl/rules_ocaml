
type x =
  | A of int
  | B
  | C of string * int
  | D of { x : int }
[@@deriving is_constr]

let () =
  assert (is_a (A 123));
  assert (is_b B);
  assert (not (is_b (A 123)));
  assert (is_d (D { x = 42 }));
  assert (not (is_d (A 42)));
  print_endline "is_constr tests passed"

