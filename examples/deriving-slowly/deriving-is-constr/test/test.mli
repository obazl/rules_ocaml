
type x =
  | A of int
  | B
  | C of string * int
  | D of { x : int }
[@@deriving is_constr]
