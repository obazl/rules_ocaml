# Preprocessing in OCaml.

The OCaml compilers are actually much more than just compilers; like
most C compilers, they can drive other tools. Where C compilers
integrate support for the One True Preprocessor (whose definition is
part of the C language specification), the OCaml compilers contain
logic to drive user-supplied preprocessors. These come in two kinds,
which are reflected in the compiler parameters:

* `-pp command`  "Cause the compiler to call the given command as a preprocessor for each source file. The output of command is redirected to an intermediate file, which is compiled. If there are no compilation errors, the intermediate file is deleted afterwards."  (source: [Chapter 12  Native-code compilation (ocamlopt)](https://caml.inria.fr/pub/docs/manual-ocaml/native.html))
* `-ppx command`  "After parsing, pipe the abstract syntax tree through the preprocessor command. The module Ast_mapper, described in chapter 26: Ast_mapper , implements the external interface of a preprocessor." (source: [Chapter 12  Native-code compilation (ocamlopt)](https://caml.inria.fr/pub/docs/manual-ocaml/native.html))

Note that these parameters take a *command* argument.  The first one,
evidently, supports genuine *pre*processing: the passed command is
applied to the source, and the compiler processes the output of the
command.  The second one applies the passed PPX command to the AST
resulting from parsing, and then, presumably, compiles the AST
produced by the PPX command.

Note also that using these parameters - that is, using the compiler to
manage/drive preprocessing - is optional; since they take (executable)
command arguments, the same result can be obtained by using the
command to preprocess the code before invoking the compiler.  That is
the strategy OBazl pursues at the moment.  It also appears to be the
strategy used by Dune; if you compile some code, with a PPX, with
`-verbose`, the output shows that the preprocessor is applied to the
source and the result is passed to the compiler.

[Question: that means that a standalone PPX command must include
parsing as the first step; how is this arranged? Via Ppx.Driver/ppx_driver/Migrate_parsetree.Driver?]

[Note also that a standalone PPX that emits source code must end with
a pretty-printer, to convert AST to source.]

## PP Extensions

You gotta love a language that supports something called a "PP
extension".  A PPX is a "preprocessor extension", which is code that
operates, not on source code, but on an AST, transforming an input AST
to an output AST.  Which means that a PPX can change the semantics of
the language; whether this is a bug or a feature is a debatable, but
the fact is that PPXes are widely used.

A minimal PPX is an OCaml module, although in principle PPXes could be
written in any language.  From a build engineering perspective, that
means a cmo/cmx file.

To be useful, a PPX module must be executable.

[NOTE: undocumented compiler params: `-dsource`, `-dparsetree`]

[It looks like Ppxlib.Driver calls Migrate_parsetree, which parses the input?]

#### drivers

OBazl calls these _pipelines_.  Build rule: `ocaml_ppx_pipeline`.

ppx_driver, Ppxlib.Driver, Migrate_parsetree.Driver, etc. Then we have
ppxlib.runner, which does Ppxlib.Driver.standalone()

## resources

* [ppxlib](https://github.com/ocaml-ppx/ppxlib)  The documentation is pretty thin; the best info is in the [History](https://github.com/ocaml-ppx/ppxlib/blob/master/HISTORY.md) doc.  E.g. "A driver is an executable created from a set of OCaml AST transformers linked together with a command line frontend."  We use "pipeline" instead.
* [ppx_driver](https://github.com/janestreet-deprecated/ppx_driver) Deprecated in favor of Ppxlib.Driver, but still shows up all over the place.
* [ocaml-migrate-parsetree](https://github.com/ocaml-ppx/ocaml-migrate-parsetree) Includes `Migrate_parsetree.Driver` which can be used, like `Ppxlib.Driver`, to create a standalone PPX pipeline.

* [blog post on ppxes](https://stackoverflow.com/questions/49583700/ocaml-specify-path-to-ppx-executable) "Contrarily, -ppx AST preprocessor takes as an input the name of the input AST binary file and the name of the output binary AST file."
