# examples

Run Bazel builds from the `examples` directory, e.g.

`$ bazel build hello/lwt`

To run executables, just replace `build` with `run`:

`$ bazel run hello/ppx`

Some of the examples also have dune files or make files.

## deriving-slowly

The `deriving-slowly` examples demonstrate simple PPX code. They are
taken from [Deriving
Slowly](http://rgrinberg.com/posts/deriving-slowly/).

## hello

OBazl verions of examples from the Dune
[Quickstart](https://dune.readthedocs.io/en/stable/quick-start.html).

* hello - [Building a hello world program](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program).  Bazel build command:  `$ bazel build hello/hello`
* lwt - [Building a hello world program using Lwt](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program-using-lwt)  Bazel build command:  `$ bazel build hello/lwt`
* ppx - [Building a hello world program using Core and Jane Street PPXs](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program-using-core-and-jane-street-ppxs)  Bazel build command:  `$ bazel build hello/ppx`
* lib - [Defining a library using Lwt and ocaml-re](https://dune.readthedocs.io/en/stable/quick-start.html#defining-a-library-using-lwt-and-ocaml-re)  Bazel build command:  `$ bazel build hello/lib`

## namespaces

Code demonstrating file-system namespaces and OCaml module paths.

* [flat](namespaces/flat) - demonstrates mapping from flat to hiearchical namespace.  Makefiles only.
  * `eager`
  * `lazy` - uses `-no-alias-deps` to enable lazy linking.
* [makefiles](namespaces/makefiles) - a few simple examples exploring use of underscores in names; does not use OBazl.
* [ns-archive](namespaces/ns-archive) - demonstrates rule `ocaml_ns_archive`: create a namespaced module from a file system tree.
  * `macro` - uses a Bazel macro for demo purposes.
  * `rule` - uses a Bazel rule, `ocaml_ns_archive`.  Automatically
    generates, renames, compiles, and links the files needed to support namespacing.
