# documentation

OBazl uses [Stardoc](https://github.com/bazelbuild/stardoc) to generate documentation.

WARNING: Stardoc is a little bit broken.  At least, the stardoc
documentation is a bit broken.

* The instructions for [multiple
  files](https://github.com/bazelbuild/stardoc/blob/master/docs/generating_stardoc.md#multiple-files)
  are broken.  The fix is to re-export the symbols from the hub
  file. See
  [doc_rules_ocaml.bzl](../ocaml/private/rules/doc_rules_ocaml.bzl)
* If your code loads external repos (such as `@bazel_skylib`
  libraries), stardoc will choke.  The fix is to use `bzl_library` to
  "wrap" the external repo and then have your `stardoc` rule depend on
  that `bzl_library` target.  See [Issue
  29](https://github.com/bazelbuild/stardoc/issues/29).  For OBazl,
  see:
  * [//ocaml/private/actions/BUILD.bazel](../ocaml/private/actions/BUILD.bazel) - handles `load("@bazel_skylib//lib:paths.bzl", "paths")`
  * [//opam/BUILD.bazel](../opam/BUILD.bazel)
