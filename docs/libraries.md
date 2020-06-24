# libraries

OBazl uses the term "library" to refer to a collection of modules.  It
is _not_ used to refer to archive files (files with extensions .a,
.cma, or .cmxa).

To build a single module, use `ocaml_module`; to build a library, use
`ocaml_library`; to build an archive, use `ocaml_archive`.

Note that `ocaml_library` does not produce an archive file; it only
compiles the modules in the library.

A library may have intra-library dependencies; that is, a module in
the library may refer to identifiers in another module within the
library.  To compile such a library, the modules must be compiled in
the proper order: each file must be compiled after the files on which
it depends are compiled.  If there are cyclic dependencies, then the
library must be built using `ocaml_ns_archive`.

There are two ways to build the modules in a library, one-by-one and
batched.  A batch build runs a single Bazel compile action
parameterized by the list of modules in the library.  The compiler is
then responsible for running one compile "job" per source file; such
jobs are not visible to Bazel.  A one-by-one build runs one Bazel
compile action per source file; this puts the compile actions in
Bazel's dependency graph, so it can schedule them as it sees fit,
possibily parallelizing them.

[FIXME:  What is the opposite of "batch"?  "One-by-one" is infelicitous.]

In either case, intra-library dependencies must be taken into account.
For a batch builds, this means that the list of source files must be
in dependency-order.  For one-by-one builds, each compile target must
explicitly list its dependencies; this will allow Bazel to schedule
the jobs in the required order.

For batch builds, the `ocaml_library` rule and handle dependency
ordering automatically.  It does this by using `ocamldep` to analyze
the dependencies of each module, and processing the results (using an
internal tool) to generate an arguments file, which it then passes to
the compiler task using the `-args` compiler parameter.

For one-by-one builds, module dependencies must be explicitly
articulated in the BUILD.bazel file. They cannot be generated
dynamically at build time (or at least, I have not figured out how to
do this).  This is because Bazel does not allow rules to read files,
env variables, etc. in order to ensure hermetic builds.  Plus
dependencies must be known ahead of time, and cannot be added during
the build process.  The batch mode process described above works
because it does not change the dependencies; it just uses them in a
particular way that does not change either the inputs or the outputs
specified statically by the BUILD.bazel file.  But to support
intra-library dependencies for one-by-one builds, we must do the
dependency analysis ahead of time, and structure our BUILD.bazel file
accordingly.

It is easy but tedious to write a BUILD.bazel file for a library.  The
rule `ocaml_deps` can be used to generate a deps file, which can be
used to guide the writing of targets in the BUILD.bazel file, which will look something like:

`ocaml_module(name="digestif_by", impl="src/digestif_by.ml")`

OBazl includes a tool that provides primitive support for
automatically generating BUILD.bazel files with the needed
dependencies.  It does so by using `ocamldep` to generate a list fo
dependencies, and then processes the list and generates a BUILD.bazel
file.  The process is structurally similar to what happens with a
batch build; the difference lies just in how the output of `ocamldep`
is processed.
