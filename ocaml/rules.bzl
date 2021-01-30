"""Public definitions for OCaml rules.

All public OCaml rules imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("//ocaml/_rules:ocaml_archive.bzl",
    _ocaml_archive = "ocaml_archive")
load("//ocaml/_rules:ocaml_executable.bzl",
    _ocaml_executable = "ocaml_executable")
load("//ocaml/_rules:ocaml_import.bzl",
    _ocaml_import = "ocaml_import")
load("//ocaml/_rules:ocaml_interface.bzl",
    _ocaml_interface = "ocaml_interface")
load("//ocaml/_rules:ocaml_library.bzl",
    _ocaml_library = "ocaml_library")
load("//ocaml/_rules:ocaml_module.bzl",
    _ocaml_module = "ocaml_module")
load("//ocaml/_rules:ocaml_ns_resolver.bzl",
    _ocaml_ns_resolver = "ocaml_ns_resolver")
load("//ocaml/_rules:ocaml_ns_module.bzl",
    _ocaml_ns_module = "ocaml_ns_module")
load("//ocaml/_rules:ocaml_test.bzl",
    _ocaml_test = "ocaml_test")

load("//ocaml/_rules:ocaml_lex.bzl",
    _ocaml_lex = "ocaml_lex")
load("//ocaml/_rules:ocaml_yacc.bzl",
    _ocaml_yacc = "ocaml_yacc")

load("//ocaml/_rules:x_cppo_filegroup.bzl",
    _x_cppo_filegroup = "x_cppo_filegroup")


load("//ocaml/_rules:ppx_archive.bzl",
     _ppx_archive = "ppx_archive")
load("//ocaml/_rules:ppx_executable.bzl",
     _ppx_executable = "ppx_executable")
load("//ocaml/_rules:ppx_library.bzl",
     _ppx_library = "ppx_library")
load("//ocaml/_rules:ppx_module.bzl",
     _ppx_module = "ppx_module")
load("//ocaml/_rules:ppx_ns_module.bzl",
     _ppx_ns_module = "ppx_ns_module")
load("//ocaml/_rules:ppx_runner.bzl",
     _ppx_runner = "ppx_runner")
load("//ocaml/_rules:ppx_test.bzl",
     _ppx_x_test = "ppx_x_test",
     _ppx_test = "ppx_test")
     # _ppx_fail_test = "ppx_fail_test")
# load("//ocaml/_rules:ppx_transform.bzl",
#      _ppx_transform = "ppx_transform")

# load("//implementation:macros/preproc.bzl",
#      _ocaml_preproc = "ocaml_preproc",
#      _ocaml_redirector_gen = "ocaml_redirector_gen",
#      _ocaml_submodule_rename = "ocaml_submodule_rename",
# )

ocaml_archive = _ocaml_archive
ocaml_executable = _ocaml_executable
ocaml_lex = _ocaml_lex
ocaml_yacc = _ocaml_yacc
ocaml_import = _ocaml_import
ocaml_interface = _ocaml_interface
ocaml_library = _ocaml_library
ocaml_module = _ocaml_module
ocaml_ns_resolver = _ocaml_ns_resolver
ocaml_ns_module  = _ocaml_ns_module
ocaml_test= _ocaml_test

ppx_archive = _ppx_archive
ppx_executable = _ppx_executable
ppx_library = _ppx_library
ppx_module = _ppx_module
ppx_ns_module     = _ppx_ns_module
ppx_runner = _ppx_runner
ppx_x_test = _ppx_x_test
ppx_test = _ppx_test
# ppx_fail_test = _ppx_fail_test
# ppx_transform = _ppx_transform

# macros
# ocaml_ns_archive_macro = _ocaml_ns_archive_macro
# ocaml_preproc = _ocaml_preproc

# ocaml_redirector_gen = _ocaml_redirector_gen
# ocaml_submodule_rename = _ocaml_submodule_rename

x_cppo_filegroup = _x_cppo_filegroup
