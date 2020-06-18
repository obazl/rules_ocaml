# examples

WARNING: some of these are a little outdated as of June 15 2020. Stay tuned.

## deriving-slowly

The `deriving-slowly` examples demonstrate simple PPX code. They are
taken from [Deriving
Slowly](http://rgrinberg.com/posts/deriving-slowly/).

## hello

A set of simple hello-world examples.

OBazl verions of examples from the Dune
[Quickstart](https://dune.readthedocs.io/en/stable/quick-start.html). Run
the Bazel builds from the `examples` directory. To run them, just
replace `build` with `run`, e.g. `$ bazel run hello/hello`.

* hello - [Building a hello world program](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program).  Bazel build command:  `$ bazel build hello/hello`
* lwt - [Building a hello world program using Lwt](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program-using-lwt)  Bazel build command:  `$ bazel build hello/lwt`
* ppx - [Building a hello world program using Core and Jane Street PPXs](https://dune.readthedocs.io/en/stable/quick-start.html#building-a-hello-world-program-using-core-and-jane-street-ppxs)  Bazel build command:  `$ bazel build hello/ppx`
* lib - [Defining a library using Lwt and ocaml-re](https://dune.readthedocs.io/en/stable/quick-start.html#defining-a-library-using-lwt-and-ocaml-re)  Bazel build command:  `$ bazel build hello/lib`
