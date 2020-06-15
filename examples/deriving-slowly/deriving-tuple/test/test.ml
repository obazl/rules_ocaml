type r =
  { a : int
  ; b : string
  ; c : bool
  }
[@@deriving tuple]

let x = { a = 42; b = "foo"; c = false }
let (a, b, c) = tuple_r x

let () =
  assert (x.a = a);
  assert (x.b = b);
  assert (x.c = c)
