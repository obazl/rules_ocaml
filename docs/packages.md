# packages

In Bazel, the concept of a package is
[well-defined](https://docs.bazel.build/versions/master/build-ref.html#packages).

Not so much for OCaml.

Roughly: an OCaml package is a named library.  A library is a
collection of modules.  We need this distinction to enable smooth
interop with existing package management systems like OPAM, Dune and
ocamlfind.  For example, dune files list dependencies as "libraries";
theses are Dune packages. The actual dependencies are on modules, not
libraries.  The ocamldep tool lists module dependencies, which do not
necessarily correspond to packages.

## problems with current tools

Most commonly used: Dune and ocamlfind.

Here's the problem: their package naming conventions confuse module
paths, file paths, module names, package names, and subpackage names.

Example: the macaddr package. Located (within your OPAM tree) at
`lib/macaddr`.  Contains subdirs `lib/macaddr/sexp` and
`lib/macaddr/top`.  The ocamlfind META file lists `sexp` and `top` as
packages (that is, subpackages of package `macaddr`).  To list those
as dependencies, one writes `macaddr.sexp`, resp. `macaddr.top`.  In
other words, the _package path_ (in dotted seg notation) maps to the
_filesystem path_ (solidus-segmented notation).  But neither one has
anything to do with the _module name_ or _module path_.  If you depend
on `macaddr.top`, that does not mean you can write `open Macaddr.Top`
or similar in your code.  You have to just know that the module
associated with this package name is `Macaddr_top`.  Very
confusing. If you need `Macaddr_top`, why not write that as the dep,
instead of `macaddr.top`?  I suspect the answer is: because findlib
(i.e. ocamlfind) decided to implement a notion of subpackages using
dotted-segment notation. But this gives the false impression that such
package paths are somehow related to module paths. This is a bad
thing, IMHO.

Dune: similar.

With OBazl there is no conflation of package/target names and module
names.  But since Bazel is nicely namespaced (packages within
workspaces, targets within packages, and package name structure
matching directory structure), we _can_ (if we choose to do so) structure
our names to mirror the package structure expressed by the META files.
In our example, we would have the following targets:

* `//lib/macaddr`  - corresponds to `macaddr`
* `//lib/macaddr:sexp` - corresponds to `macaddr.sexp`, but does not suggest a module path quite so strongly
* `//lib/macaddr:top` - ditto for `macaddr.top`

The OBazl targets will produce the same results as the META file:

* `macaddr.[cma|cmxa|cmxs]` - from `//lib/macaddr`, or `macaddr`
* `macaddr_sexp.[cma|cmxa|cmxs]` - from `//lib/macaddr:sexp`, or `macaddr.sexp`
* `macaddr_top.[cma|cmxa|cmxs]` - from `//lib/macaddr:top`, or `macaddr.top`

And that of course gives the module names.  We still have a gap
between target (package) name and module name, but at least we're not
misleading the reader.

The interpretation of target names is clear: `//lib/macaddr:top` says
that `top` is a target in the `lib/macaddr` package (i.e. namespace),
but says nothing about how the files are organized within that
package, or about how the output of the target is named - which means
it says nothing about the name of the module it produces.  The writer
of the rule could call the output anything - calling it `macaddr_top`
is just convention.

[NOTE: critical point: in the build language, we can only depend on
top-level module names.  That's one reason allowing dotted-segment
package names is a bad idea.  In principle, we could support submodule
dependencies for external submodules, but that would probably not be a
good idea - how would the use know which module paths refer to
externally defined modules?  Furthermore the mapping from module paths
to filenames is not predictable.  Foo.Bar might map to Foo__Bar.ml,
but it could also map to "QWQFsf.ml", or any other random top-level
file name. It would probably lead to consternation - why does a
dependency on "foo.bar" work, but one on "a.b" doesn't?  Because b is
defined within module (file) a.ml, but bar is defined within module
(file) Foo_bar.ml.  Better just to be clear that target names bear no
necessary relation to output names, while following a clear convention.]

[OTOH, I think we could implement a rule to control the mapping from
target name to output name, so that e.g. `//lib/macaddr:top` produces
`macaddr_top.[...]`.  Maybe it would make sense to make this the
default mapping, but allow the user to override it. But what about
e.g. `//lib/foo/bar:baz`? Should that produce `foo_bar_baz.[...]`?]

[Note that the OCaml rules are a little different in this respect than
rules for some other languages, which take the name of the output from
the target name. That's not feasible for OCaml, since the filename is
a module name by definition, so we need to be able to control it
independent of build target names.]

Here's an example of what a BUILD.bazel file might look like for an
OPAM lib.  Note that I have used an `ocaml_module` rule for each file,
which produces a .cmx file, and then I list those targets in the
`deps` attributes of the archive rules.  Alternatively, we could list
the source files in the `srcs` attributes of the archive rules.
Compare this with what's in `lib/ipaddr`:

```
## in file lib/ipaddr/BUILD.bazel
## rules to compile each module
ocaml_module( name = "ipaddr_ml", intf = "ipaddr.mli", impl = "ipaddr.ml")
ocaml_module( name = "ipaddr_sexp_ml", intf = "sexp/ipaddr_sexp.mli", impl = "sexp/ipaddr_sexp.ml")
ocaml_module( name = "ipaddr_top_ml", intf = "top/ipaddr_top.mli", impl = "top/ipaddr_top.ml")
ocaml_module( name = "ipaddr_unix_ml", intf = "unix/ipaddr_unix.mli", impl = "unix/ipaddr_unix.ml")
## rules to assemble libs/archives
ocaml_archive( name = "ipaddr",  ## target //lib/ipaddr, produces ipaddr.cmxa
               deps = [":ipaddr_ml",
                       "//lib/macaddr"])
ocaml_archive( name = "sexp",   ## target //lib/ipaddr:sexp, produces ipaddr_sexp.cmxa
               deps = [":ipaddr_sexp_ml",
                       ":ipaddr",
                       "//lib/sexplib0"])
ocaml_archive( name = "top",   ## target //lib/ipaddr:top, produces ipaddr_top.cmxa
               deps = [":ipaddr_top_ml",
                       "//lib/compiler-libs",
                       ":ipaddr",
                       "//lib/macaddr:top"])
ocaml_archive( name = "unix",  ## target //lib/ipaddr:unixe, produces ipaddr_unix.cmxa
               deps = [":ipaddr_unix_ml",
                       ":ipaddr",
                       "//lib/unix"])
```


#### predicates?  wft?!

Another difference is "predicates". The type of output file is
selected by "predicates" for Dune/ocamlfind.  This is _very_
idiosyncratic, and thoroughly perplexing to newcomers.  It's also
pointless, since all it does is substitute a fancy word for a simple
on (i.e. "flag").  With OBazl the kind of output is determined by the
way the rule is parameterized, e.g. with "linkstatic", "shared", etc.

