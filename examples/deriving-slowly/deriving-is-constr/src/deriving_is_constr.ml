open Base
open Ppxlib

let f_name (constr : constructor_declaration) =
  "is_" ^ String.uncapitalize constr.pcd_name.txt

let sig_make_fun ~loc ~type_ (constr : constructor_declaration) =
  let (module Ast) = Ast_builder.make loc in
  let name = { loc ; txt = f_name constr } in
  let type_ = [%type: [%t type_] -> bool] in
  Ast.value_description ~name ~type_ ~prim:[]
  |> Ast.psig_value

let str_make_fun ~loc (constr : constructor_declaration) =
  let (module Ast) = Ast_builder.make loc in
  let f_name = f_name constr in
  let pat =
    let name =
      Ast_builder.Default.Located.lident
        ~loc:constr.pcd_name.loc
        constr.pcd_name.txt
    in
    let pat =
      match constr.pcd_args with
      | Pcstr_tuple [] -> []
      | Pcstr_tuple (_::_)
      | Pcstr_record _ -> [Ast.ppat_any]
    in
    Ast.ppat_construct name (Ast.ppat_tuple_opt pat)
  in
  let expr =
    [%expr
      function
      | [%p pat] -> true
      | _        -> false
    ]
  in
  let pat = Ast.pvar f_name in
  Ast.value_binding ~pat ~expr

let str_gen ~loc ~path:_ (_rec, t) =
  let (module Ast) = Ast_builder.make loc in
  (* we are silently dropping mutually recursive definitions to keep things
     brief *)
  let t = List.hd_exn t in
  let constructors =
    match t.ptype_kind with
    | Ptype_variant constructors -> constructors
    | _ -> Location.raise_errorf ~loc "is_constr only works on variants"
  in
  List.map constructors ~f:(str_make_fun ~loc)
  |> Ast.pstr_value_list ~loc Nonrecursive

let sig_gen ~loc ~path:_ (_rec, t) =
  let t : type_declaration = List.hd_exn t in
  let (module Ast) = Ast_builder.make loc in
  let constructors =
    match t.ptype_kind with
    | Ptype_variant constructors -> constructors
    | _ -> Location.raise_errorf ~loc "is_constr only works on variants"
  in
  let type_ =
    let name =
      Ast_builder.Default.Located.lident
        ~loc:t.ptype_name.loc
        t.ptype_name.txt
    in
    Ast.ptyp_constr name [] in
  List.map constructors ~f:(sig_make_fun ~loc ~type_)

let name = "is_constr"

let () =
  let str_type_decl = Deriving.Generator.make_noarg str_gen in
  let sig_type_decl = Deriving.Generator.make_noarg sig_gen in
  Deriving.add name ~str_type_decl ~sig_type_decl
  |> Deriving.ignore

(* let () = Migrate_parsetree.Driver.run_main () *)
