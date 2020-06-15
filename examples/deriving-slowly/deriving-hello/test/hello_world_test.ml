type 'a my_typ =
  { foo : int
  ; bar : 'a
  } [@@deriving hello_world]

let () =
  let open Info_my_typ in
  Format.eprintf "path: %s@.name: %s@." path name
