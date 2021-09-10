# threads

* vmthreads are deprecated.  we won't support until somebody needs.

From the manual [Chapter 27, Threads](https://ocaml.org/manual/libthreads.html):

"Programs that use threads must be linked as follows:

        ocamlc -I +threads other options unix.cma threads.cma other files
        ocamlopt -I +threads other options unix.cmxa threads.cmxa other files

Compilation units that use the threads library must also be compiled with the -I +threads option (see chapter 9)."


To support threads OBazl uses global config flags, one per rule type.
For example, `--@ocaml//module/threads`. When this flag is passed the
required args will automatically be added to build command lines.

Since the threads lib depends on the unix lib, we define a threads
target (`@opam//lib/threads` ? or `@ocaml//lib/threads` ?) with that
dependency, and that's what we add by rule.

[Since it is not really an opam lib we should maybe avoid
`@opam//lib/threads`?]

[TODO: does it make sense to support per-module threaded builds?]

Note:

* the required library is part of the OCaml stdlib
  * so there is no need to add a dependency, e.g. `@opam//lib/threads`.
  * legacy code based on ocamlfind may depend on findlib/opam pkg
    `thread`; this should be removed
* there is no `-threads` command line option. This is a change from
  previous versions, and from `ocamlfind`.

HOWEVER: the threads lib depends on the `unix` lib, so we need a bazel
target to record this.
