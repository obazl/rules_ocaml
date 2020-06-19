open Base
open Ppxlib

let str_gen ~loc ~path:_ (_rec, t) =
  let (module Ast) = Ast_builder.make loc in
  (* we are silently dropping mutually recursive definitions to keep things
     brief *)
  let t = List.hd_exn t in
  let fields =
    match t.ptype_kind with
    | Ptype_record fields -> fields
    | _ -> Location.raise_errorf ~loc "tuple only works on records"
  in
  let lident_of_field field =
    (* We are reusing the locations of the field declarations for the
       accesses. *)
    Ast_builder.Default.Located.lident
      ~loc:field.pld_name.loc
      field.pld_name.txt
  in
  let tuple_expr =
    List.map fields ~f:(fun field ->
        Ast.pexp_ident (lident_of_field field))
    |> Ast.pexp_tuple
  in
  let record_pat =
    let fields = List.map fields ~f:(fun field ->
        let pattern = Ast.pvar field.pld_name.txt in
        let field_id = lident_of_field field in
        (field_id, pattern))
    in
    Ast.ppat_record fields Closed
  in
  let fun_ =
    let f_name =
      let type_name = t.ptype_name.txt in
      "tuple_" ^ type_name
    in
    let pat = Ast.pvar f_name in
    let expr = Ast.pexp_fun Nolabel None record_pat tuple_expr in
    [Ast.value_binding ~pat ~expr]
    |> Ast.pstr_value Nonrecursive
  in
  [fun_]

let str_type_decl = Deriving.Generator.make_noarg str_gen

let name = "tuple"

let () =
  Deriving.add name ~str_type_decl
  |> Deriving.ignore
