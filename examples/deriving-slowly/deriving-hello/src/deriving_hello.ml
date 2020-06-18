open Base
open Ppxlib

(* Generate a module name Info_t from type [t] *)
let module_name_of_type t =
  let type_name = t.ptype_name.txt in
  { t.ptype_name with txt = "Info_" ^ type_name  }

let str_gen ~loc ~path (_rec, t) =
  (* All nodes created using this Ast module will use [loc] by default *)
  let (module Ast) = Ast_builder.make loc in
  (* we are silently dropping mutually recursive definitions to keep things
     brief *)
  let t = List.hd_exn t in
  let info_module =
    let expr =
      (* we are using this ppxlib function to generate a full name for the type
         that includes the type variable *)
      let name =
        core_type_of_type_declaration t
        |> string_of_core_type
      in
      Ast.pmod_structure (
        [%str
          let path = [%e Ast.estring path]
          let name = [%e Ast.estring name]
        ])
    in
    let name = module_name_of_type t in
    Ast.module_binding ~name ~expr
    |> Ast.pstr_module
  in
  [info_module]

let sig_gen ~loc ~path:_ (_rec, t) =
  let (module Ast) = Ast_builder.make loc in
  (* we are silently dropping mutually recursive definitions to keep things
     brief *)
  let t = List.hd_exn t in
  let name = module_name_of_type t in
  let type_ =
    let sig_ =
      [%sig:
        val path : string
        val name : string
      ]
    in
    Ast.pmty_signature sig_
  in
  Ast.module_declaration ~name ~type_
  |> Ast.psig_module
  |> List.return

let name = "hello_world"

let () =
  let str_type_decl = Deriving.Generator.make_noarg str_gen in
  let sig_type_decl = Deriving.Generator.make_noarg sig_gen in
  Deriving.add name ~str_type_decl ~sig_type_decl
  |> Deriving.ignore
