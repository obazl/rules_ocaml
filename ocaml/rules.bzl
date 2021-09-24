"""Public definitions for OCaml rules.

All public OCaml rules imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load("//ocaml/_rules:ocaml_null.bzl"     , _ocaml_null = "ocaml_null")

load("//ocaml/_rules:ocaml_archive.bzl"     , _ocaml_archive = "ocaml_archive")
load("//ocaml/_rules:ocaml_executable.bzl"  , _ocaml_executable = "ocaml_executable")
load("//ocaml/_rules:ocaml_genrule.bzl"      , _ocaml_genrule = "ocaml_genrule")
load("//ocaml/_rules:ocaml_import.bzl"      , _ocaml_import = "ocaml_import")
load("//ocaml/_rules:ocaml_lex.bzl"         , _ocaml_lex = "ocaml_lex")
load("//ocaml/_rules:ocaml_library.bzl"     , _ocaml_library = "ocaml_library")
load("//ocaml/_rules:ocaml_module.bzl"      , _ocaml_module = "ocaml_module")
load("//ocaml/_rules:ocaml_pack_library.bzl"      , _ocaml_pack_library = "ocaml_pack_library")
load("//ocaml/_rules:ocaml_ns_archive.bzl"  , _ocaml_ns_archive = "ocaml_ns_archive")
load("//ocaml/_rules:ocaml_ns_library.bzl"  , _ocaml_ns_library = "ocaml_ns_library")
load("//ocaml/_rules:ocaml_ns_resolver.bzl"      , _ocaml_ns_resolver = "ocaml_ns_resolver")
load("//ocaml/_rules:ocaml_signature.bzl"   , _ocaml_signature = "ocaml_signature")
load("//ocaml/_rules:ocaml_test.bzl"        , _ocaml_test = "ocaml_test")
load("//ocaml/_rules:ocaml_yacc.bzl"        , _ocaml_yacc = "ocaml_yacc")

# load("//ocaml/_rules:x_cppo_filegroup.bzl",
#     _x_cppo_filegroup = "x_cppo_filegroup")

load("//ocaml/_rules:ppx_executable.bzl" ,
     _ppx_executable = "ppx_executable")
load("//ocaml/_rules:ppx_test.bzl",
     _ppx_expect_test = "ppx_expect_test",
     _ppx_test = "ppx_test")

ocaml_null = _ocaml_null

ocaml_archive    = _ocaml_archive
ocaml_cc_import = _ocaml_cc_import
ocaml_executable = _ocaml_executable
ocaml_genrule    = _ocaml_genrule
ocaml_import     = _ocaml_import
ocaml_lex        = _ocaml_lex
ocaml_library    = _ocaml_library
ocaml_pack_library    = _ocaml_pack_library
ocaml_module     = _ocaml_module
ocaml_ns_archive = _ocaml_ns_archive
ocaml_ns_library = _ocaml_ns_library
ocaml_ns_resolver = _ocaml_ns_resolver
ocaml_signature  = _ocaml_signature
ocaml_test       = _ocaml_test
ocaml_yacc       = _ocaml_yacc

## experimental
# x_ocaml_ns     = _x_ocaml_ns
# x_ocaml_module     = _x_ocaml_module
# x_ocaml_ns_library = _x_ocaml_ns_library

ppx_executable   = _ppx_executable
ppx_expect_test  = _ppx_expect_test
ppx_test         = _ppx_test
# macros
# ocaml_ns_archive_macro = _ocaml_ns_archive_macro
# ocaml_preproc = _ocaml_preproc

# ocaml_redirector_gen = _ocaml_redirector_gen
# ocaml_submodule_rename = _ocaml_submodule_rename

# x_cppo_filegroup = _x_cppo_filegroup
