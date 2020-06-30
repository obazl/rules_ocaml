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


## misc notes

Findlib: OCaml library manager http://projects.camlcity.org/projects/findlib.html
ocamlfind: goes with Findlib

summary info: https://caml.inria.fr/pub/docs/oreilly-book/html/book-ora066.html

commands:

ocaml	toplevel loop
ocamlrun	bytecode interpreter
ocamlc	bytecode batch compiler
ocamlopt	native code batch compiler
ocamlc.opt	optimized bytecode batch compiler
ocamlopt.opt	optimized native code batch compiler
ocamlmktop	new toplevel constructor

preprocessing:  ocamlc -pp, -ppx (multiples allowed)



files:

extension	meaning
.ml	source file
.mli	interface file
.cmo	object file (bytecode)
.cma	library object file (bytecode)
.cmi	compiled interface file
.cmx	object file (native)
.cmxa	library object file (native)
.c	C source file
.o	C object file (native)
.a	C library object file (native)

IMPORTANT: if you compile with -c, but without passing a declared
output file for -o, ocamlopt will put the output in the same directory
as the source, thus polluting your source tree.  You would do this if
you were batch compiling a set of sources.  Bazel will not prevent
this, since it symlinks your source tree to its workdir.  So you must
declare the output file, so Bazel knows about it, and pass it with -o,
to tell ocamlopt about it (declaring it puts it in Bazel's work area).
If you are batch compiling, this won't work, since you will have more
than one output, so -o won't make sense.  In that case, you will need
two actions, one to copy the source files to a temp dir (which will be
in Bazel's work area), and another to compile them.  You will need to
declare the copied files, in order to get them into Bazel's dependency
graph; they will be registered as outputs of the copy action, and
inputs to the compile action.
