
type x =
  | A of int
  | B of string * char
  | C
[@@deriving poly]

let () =
  assert (`A 123   = poly_x (A 123));
  assert (`B ("foo", 'c') = poly_x (B ("foo", 'c')));
  assert (`C       = poly_x C);
  print_endline "poly tests passed"
