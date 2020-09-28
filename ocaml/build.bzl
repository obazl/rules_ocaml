"""Public definitions for OCaml rules.

All public OCaml rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_archive.bzl",
    _ocaml_archive = "ocaml_archive")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_executable.bzl",
    _ocaml_executable = "ocaml_executable")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_import.bzl",
    _ocaml_import = "ocaml_import")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_interface.bzl",
    _ocaml_interface = "ocaml_interface")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_deps.bzl",
    _ocaml_deps = "ocaml_deps")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_library.bzl",
    _ocaml_library = "ocaml_library")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_module.bzl",
    _ocaml_module = "ocaml_module")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_ns_archive.bzl",
    _ocaml_ns_archive = "ocaml_ns_archive")
load("@obazl_rules_ocaml//ocaml/private/rules:ocaml_ns_module.bzl",
    _ocaml_ns_module = "ocaml_ns_module")

load("@obazl_rules_ocaml//ocaml/private:macros/ns_archive.bzl",
     _ocaml_ns_archive_macro = "ocaml_ns_archive_macro"
)
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_archive.bzl",
     _ppx_archive = "ppx_archive")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_executable.bzl",
     _ppx_executable = "ppx_executable")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_library.bzl",
     _ppx_library = "ppx_library")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_module.bzl",
     _ppx_module = "ppx_module")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_ns_module.bzl",
     _ppx_ns_module = "ppx_ns_module")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_test.bzl",
     _ppx_test = "ppx_test",
     _ppx_diff_test = "ppx_diff_test",
     _ppx_fail_test = "ppx_fail_test")
load("@obazl_rules_ocaml//ocaml/private/rules:ppx_transform.bzl",
     _ppx_transform = "ppx_transform")

load("@obazl_rules_ocaml//ocaml/private:macros/preproc.bzl",
     _ocaml_preproc = "ocaml_preproc",
     _ocaml_redirector_gen = "ocaml_redirector_gen",
     _ocaml_submodule_rename = "ocaml_submodule_rename",
)

ocaml_archive = _ocaml_archive
ocaml_executable = _ocaml_executable
ocaml_deps = _ocaml_deps
ocaml_import = _ocaml_import
ocaml_interface = _ocaml_interface
ocaml_library = _ocaml_library
ocaml_module = _ocaml_module
ocaml_ns_archive = _ocaml_ns_archive
ocaml_ns_module  = _ocaml_ns_module

ppx_archive = _ppx_archive
ppx_executable = _ppx_executable
ppx_library = _ppx_library
ppx_module = _ppx_module
ppx_test = _ppx_test
ppx_diff_test = _ppx_diff_test
ppx_fail_test = _ppx_fail_test
ppx_transform = _ppx_transform
ppx_ns_module = _ppx_ns_module

# macros
ocaml_ns_archive_macro = _ocaml_ns_archive_macro
ocaml_preproc = _ocaml_preproc
ocaml_redirector_gen = _ocaml_redirector_gen
ocaml_submodule_rename = _ocaml_submodule_rename
