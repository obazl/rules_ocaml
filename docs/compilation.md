# Compiling OCaml code with Bazel

## The OCaml Toolset

* ocamlc
* ocamlopt
* ocamlfind

A typical cmd:
ocamlfind ocamlopt -predicates ppx_driver -o ppx -linkpkg \
-package ppx_sexp_conv -package ppx_bin_prot \
-package ocaml-migrate-parsetree.driver-main

 our version:
'external/opam/opam exec --root external/ocaml_sdk/opamroot --
external/ocaml_sdk/switch/bin/ocamlfind ocamlopt -predicates
ppx_driver -o
bazel-out/darwin-fastbuild/bin/src/deriving_hello_ppx -linkpkg
-package base -package ppxlib -package ppxlib.metaquot -package
ppxlib.runner '

  ## findlib says:
  ## "If you want to create an executable, do not forget to add the -linkpkg switch."
  # http://projects.camlcity.org/projects/dl/findlib-1.8.1/doc/QUICKSTART

## Preprocessing

Dune automatically injects one of two drivers.  In either case, what
gets injected is a one-line program:

* ocaml-migrate-parsetree: `let () = Migrate_parsetree.Driver.run_main ()`
Which is the exact contents of:

`~/.opam/4.07.1/lib/ocaml-migrate-parsetree/driver-main/migrate_parsetree_driver_main.ml`

* ppxlib.runner: `let () = Ppxlib.Driver.standalone()`
Compare the contents of `~/.opam/4.07.1/lib/ppxlib/runner/ppx_driver_runner.ml`:

`Ppxlib.Driver.standalone ()`

OBazl eschews such hidden stuff; we leave it up to the user to
explicitly specify a driver, e.g.
`deps = [..., "@opam//pkg:ppxlib.runner"]`.

