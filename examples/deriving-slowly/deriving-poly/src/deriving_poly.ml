open Base
open Ppxlib

let str_gen ~loc ~path:_ (_rec, t) =
  let (module Ast) = Ast_builder.make loc in
  let t = List.hd_exn t in
  let constructors =
    match t.ptype_kind with
    | Ptype_variant constructors -> constructors
    | _ -> Location.raise_errorf ~loc "poly only works on variants"
  in
  let expr =
    (* loop over all over the constructors to:
     - generate the pattern for the constructor args in Foo (x, y, ..)
     - generate the argument for the rhs of the poly variant `Foo (x, y, ..)
     * *)
    List.map constructors ~f:(fun constructor ->
        let (arg_pat, arg_expr) =
          match constructor.pcd_args with
          | Pcstr_record _ ->
            Location.raise_errorf ~loc:constructor.pcd_name.loc
              "inline records aren't supported"
          | Pcstr_tuple args ->
            List.mapi args ~f:(fun i _ ->
                let var = "x" ^ Int.to_string i in
                let pat = Ast.ppat_var { txt = var; loc } in
                let expr = Ast.evar var in
                (pat, expr))
            |> List.unzip
        in
        let lhs =
          let name =
            Ast_builder.Default.Located.lident
              ~loc:constructor.pcd_name.loc
              constructor.pcd_name.txt
          in
          let pat = Ast.ppat_tuple_opt arg_pat in
          Ast.ppat_construct name pat
        in
        let rhs =
          let expr = Ast.pexp_tuple_opt arg_expr in
          Ast.pexp_variant constructor.pcd_name.txt expr
        in
        Ast.case ~lhs ~guard:None ~rhs)
    |> Ast.pexp_function
  in
  let fun_ =
    let f_name =
      let type_name = t.ptype_name.txt in
      "poly_" ^ type_name
    in
    let pat = Ast.pvar f_name in
    [Ast.value_binding ~pat ~expr]
    |> Ast.pstr_value Nonrecursive
  in
  [fun_]

let str_type_decl = Deriving.Generator.make_noarg str_gen

let name = "poly"

let () =
  Deriving.add name ~str_type_decl
  |> Deriving.ignore
