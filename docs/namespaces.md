# namespaces

The problem: OCaml modules use a hierarchical namespace; module paths
are dot-segmented. But the language does not define a mapping from
module paths to file system paths.  It only maps (single-segment)
module names to file names.

That leaves mapping from module paths to file system paths and files
up to the tooling.  Dune provides limited support for such namespaces,
limited to a single directory.  OBazl provides a general solution,
mapping any filesystem structure to OCaml namespaces.  For example,
source code like this (from examples/namespaces/ns-archive/festooned):

```
festooned/
├── BUILD.bazel
├── README.md
├── alpha
│   ├── beta1
│   │   ├── gamma
│   │   │   ├── goodbye.ml
│   │   │   └── hello.ml
│   │   └── pluto.ml
│   ├── beta2
│   │   ├── gamma
│   │   │   └── hello.ml
│   │   └── jupiter.ml
│   └── gamma
│       └── howdy.ml
└── driver.ml

```

will map to module paths:

```
Alpha
Alpha.Beta1
Alpha.Beta1.Gamma
Alpha.Beta1.Gamma.Goodbye
Alpha.Beta1.Gamma.Hello
...etc...
```

Files within this tree can refer to each other as you would expect;
for example, `alpha/beta1/gamma/hello.ml` can refer to an identifier
`foo` in `alpha/beta1/gamma/goodbye.ml` as just `Goodbye.foo`;
`alpha.beta2.jupiter.ml` can refer to some `x` in
`alpha/beta2/gamma/hello.ml` as `Gamma.Hello.x`, and so forth.

Obazl - specifically, the `ocaml_ns_archive` rule - will automatically
generate the namespace modules containing the module aliases needed to
make this work, as well as renaming the .ml files accordingly, and it
will structure and parameterize the compile/link steps as needed.

module aliasing maps a public name to a private name.  The private
names are always in the default flat namespace; the public names for a
hierarchical namespace.

## compiling

NS modules:

1. Compile the ns module (containing the module alias stmts) first, using -no-alias-deps
2. Compile the submodules using -no-alias-deps and -open <ns module>

## Delegation: Modules, Namespaces, and the File system.

WARNING: the rest of this file is a little bit obsolete.  I wrote it before I
realized that this stuff is really just about managing namespacing.

IMPORTANT: what `-no-alias-deps` really means is
"-link-strategy=lazy".  And link strategy is orthogonal to namespacing
strategy.  This contrast is exactly analogous to the contrast between
semantics and evaluation strategy in language design.  [TODO: flesh
this out]

OBazl rules:

* `ocaml_ns_archive` - compiles and links a tree of source code
* `ocaml_ns_module` - ...

## OCaml Modules

OCaml has a sophisticated module system that is partially tied to the file system.

Each OCaml "compilation unit" determines a module, whose name is the
file name, capitalized and truncated to remove the extension.  Thus
`foo.ml` determines module `Foo`.

File names including double underscores, such as `foo__bar.ml`,
receive special treatment.  The compiler will treat the double
underscore as a dot, in this case yielding `Foo.bar`.

WARNING: The information about double underscores seems to be
outdated.  Experimentation shows that single underscores work as well;
see examples/hello/raw/single.

"[T]he compiler uses the following heuristic when printing paths:
given a path Lib__fooBar, if Lib.FooBar exists and is an alias for
Lib__fooBar, then the compiler will always display Lib.FooBar instead
of Lib__fooBar. This way the long Mylib__ names stay hidden and all
the user sees is the nicer dot names. This is how the OCaml standard
library is compiled." (source:
https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html)
Translated into English, this bit of indecipherability seems to mean
that i.e. if `lib.ml` contains `module FooBar = Lib__fooBar`, then
`Lib.FooBar` corresponds to `Lib__fooBar`.  The documentation does not
explicitly say that references to `Foo.Bar` are translated to
`foo__Bar.ml`, but that is the implication.

Delegation involves a "delegator" module and a set of delegate modules.
A delegator module contains a list "module aliases" that serve to
redirect "open" references to delegates.

The problem this solves is namespacing.

OCaml module paths correspond to a structure of nested modules, in contrast to
e.g. Java packages, which correspond to file system paths.

## Linkage Strategies: Eager v. Lazy

Linkage strategy is orthogonal to namespace semantics.

## Emulating namespaces with module aliases

OCaml version 4.02 introduced module aliases (in 2014?).  This was an
implementation optimization, rather than an extension of the language.
It changed the way compiling and linking works, not the way the
language works.

Without module aliases, the toolchain handles "opening" external
modules (i.e.  file-defined modules) by embedding the referenced code
within the referring code. In other words, it treats "open Foo" as an
instruction to embed module Foo, so that references to object defined
within FOO would be resolved internally, so to speak.

Module aliasing just changes the way "open" statements are handled by
the toolchain, treating them as references rather than embeddings.

"When the compiler flag -no-alias-deps is enabled, type-level module
aliases are also exploited to avoid introducing dependencies between
compilation units. Namely, a module alias referring to a module inside
another compilation unit does not introduce a link-time dependency on
that compilation unit, as long as it is not dereferenced; it still
introduces a compile-time dependency if the interface needs to be
read, i.e. if the module is a submodule of the compilation unit, or if
some type components are referred to. Additionally, accessing a module
alias introduces a link-time dependency on the compilation unit
containing the module referenced by the alias, rather than the
compilation unit containing the alias. (src:
https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html)

Which seems to mean something like the following:

* If your code says "open Foo", but does not actually use anything
  from the Foo module, then Foo will not be linked to your code - the
  "open Foo" statement essentially becomes a null op.  Previously,
  "open Foo" would have cause Foo to be embedded, whether it was
  actually used or not.
* On the other hand, "open Foo.Bar" may introduce a compile-time
  dependency, if `bar` is a submodule of the `Foo` compilation unit
  (i.e. is defined in `foo.ml`).  In that case, the compiler will need
  to read `Foo.ml` (FIXME: or `Foo.mli`?) at compile time to resolve
  the reference; however, the previous consideration still applies: if
  `Foo.Bar` is not actually used, i.e. no reference is made to
  anything within `Foo.Bar`, then no link-time dependency is established.
* When a link-time dependency _is_ established, i.e. when `open
  Foo.Bar` is followed by references to stuff in the `Foo.Bar`
  namespace, the dependency is on the file defining `Bar`, not the
  file containing the alias to `Bar`.  The idea here is that `Foo.ml`
  would contain an alias, like `module Bar = Foo__Bar` (note the
  double underscore), and `foo_Bar.ml` would then be treated as the
  `Bar` module within the `Foo` namespace. So opening `Foo.Bar` and
  using Bar stuff would cause `foo__Bar.ml` to be linked, but not
  `Foo.ml`.
* In short, `-no-alias-dep` seems to mean something like
  `--link-strategy=lazy`.

See also [Better namespaces through module
aliases](https://blog.janestreet.com/better-namespaces-through-module-aliases/)
(blog post dated 2014)


## Terminology

* module
* module path: a dot-segmented name string, e.g. foo.bar.baz
* ns module - namespace module containing aliases for delegates (submodules).
  Sometimes referred to as wrappers, but this is inaccurate, such
  modules are not containers and do not wrap anything.
* submodule - a submodule aliased by a delegator.

## Resources

* [8.8  Type-level module aliases](https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html) (OCaml manual)
