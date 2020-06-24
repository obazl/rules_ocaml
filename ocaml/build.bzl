"""Public definitions for OCaml rules.

All public OCaml rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("@obazl//ocaml/private:rules/ocaml_archive.bzl",
    _ocaml_archive = "ocaml_archive")
load("@obazl//ocaml/private:rules/ocaml_binary.bzl",
    _ocaml_binary = "ocaml_binary")
load("@obazl//ocaml/private:rules/ocaml_interface.bzl",
    _ocaml_interface = "ocaml_interface")
load("@obazl//ocaml/private:rules/ocaml_deps.bzl",
    _ocaml_deps = "ocaml_deps")
load("@obazl//ocaml/private:rules/ocaml_library.bzl",
    _ocaml_library = "ocaml_library")
load("@obazl//ocaml/private:rules/ocaml_module.bzl",
    _ocaml_module = "ocaml_module")
load("@obazl//ocaml/private:rules/ocaml_ns_archive.bzl",
    _ocaml_ns_archive = "ocaml_ns_archive")

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

load("@obazl//ocaml/private:macros/ns_archive.bzl",
     _ocaml_ns_archive_macro = "ocaml_ns_archive_macro"
)
load("@obazl//ocaml/private:macros/preproc.bzl",
     _ocaml_preproc = "ocaml_preproc",
     _ocaml_redirector_gen = "ocaml_redirector_gen",
     _ocaml_submodule_rename = "ocaml_submodule_rename",
)

ocaml_archive = _ocaml_archive
ocaml_binary = _ocaml_binary
ocaml_deps = _ocaml_deps
ocaml_interface = _ocaml_interface
ocaml_library = _ocaml_library
ocaml_module = _ocaml_module
ocaml_ns_archive = _ocaml_ns_archive

ocaml_ppx_archive = _ocaml_ppx_archive
ocaml_ppx_binary = _ocaml_ppx_binary
ocaml_ppx_library = _ocaml_ppx_library
ocaml_ppx_module = _ocaml_ppx_module
ocaml_ppx_pipeline = _ocaml_ppx_pipeline
ocaml_ppx_test = _ocaml_ppx_test

# macros
ocaml_ns_archive_macro = _ocaml_ns_archive_macro
ocaml_preproc = _ocaml_preproc
ocaml_redirector_gen = _ocaml_redirector_gen
ocaml_submodule_rename = _ocaml_submodule_rename
