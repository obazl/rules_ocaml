"""Public definitions for OCaml rules.

All public OCaml rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("@obazl//ocaml/private:rules/ocaml_binary.bzl",
    _ocaml_binary = "ocaml_binary")
load("@obazl//ocaml/private:rules/ocaml_library.bzl",
    _ocaml_library = "ocaml_library")

load("@obazl//ocaml/private:rules/ppx_binary.bzl",
     _ocaml_ppx_binary = "ocaml_ppx_binary")
load("@obazl//ocaml/private:rules/ppx_library.bzl",
     _ocaml_ppx_library = "ocaml_ppx_library")

load("@obazl//ocaml/private:rules/ppx_archive.bzl",
     _ocaml_ppx_archive = "ocaml_ppx_archive")
load("@obazl//ocaml/private:rules/ppx_module.bzl",
     _ocaml_ppx_module = "ocaml_ppx_module")
load("@obazl//ocaml/private:rules/ppx_pipeline.bzl",
     _ocaml_ppx_pipeline = "ocaml_ppx_pipeline")

load("@obazl//ocaml/private:rules/ppx_test.bzl",
     _ocaml_ppx_test = "ocaml_ppx_test")

ocaml_binary = _ocaml_binary
ocaml_library = _ocaml_library
ocaml_ppx_binary = _ocaml_ppx_binary
ocaml_ppx_library = _ocaml_ppx_library
ocaml_ppx_archive = _ocaml_ppx_archive
ocaml_ppx_module = _ocaml_ppx_module
ocaml_ppx_pipeline = _ocaml_ppx_pipeline
ocaml_ppx_test = _ocaml_ppx_test
