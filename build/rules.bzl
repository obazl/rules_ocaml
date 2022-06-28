"""Public definitions for OCaml rules.

All public OCaml rules imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

# load("//ocaml/_repo_rules:new_local_pkg_repository.bzl",
#      _new_local_pkg_repository = "new_local_pkg_repository")

load("//ocaml/_rules:ocaml_null.bzl", _ocaml_null = "ocaml_null")

load("//ocaml/_rules:ocaml_archive.bzl", _ocaml_archive = "ocaml_archive")

load("//ocaml/_rules:ocaml_binary.bzl"  , _ocaml_binary = "ocaml_binary")

# load("//ocaml/_rules:ocaml_genrule.bzl"      , _ocaml_genrule = "ocaml_genrule")

load("//ocaml/_rules:ocaml_import.bzl"      , _ocaml_import = "ocaml_import")
load("//ocaml/_rules:ocaml_lex.bzl"         , _ocaml_lex = "ocaml_lex")
load("//ocaml/_rules:ocaml_library.bzl"     , _ocaml_library = "ocaml_library")
load("//ocaml/_rules:ocaml_module.bzl"      , _ocaml_module = "ocaml_module")

# load("//ocaml/_rules:ocaml_pack_library.bzl"      , _ocaml_pack_library = "ocaml_pack_library")

load("//ocaml/_rules:ocaml_ns_archive.bzl"  , _ocaml_ns_archive = "ocaml_ns_archive")
load("//ocaml/_rules:ocaml_ns_library.bzl"  , _ocaml_ns_library = "ocaml_ns_library")
load("//ocaml/_rules:ocaml_ns_resolver.bzl"      , _ocaml_ns_resolver = "ocaml_ns_resolver")

load("//ocaml/_rules:ocaml_signature.bzl",
     _ocaml_signature = "ocaml_signature",
     )
load("//ocaml/_rules:ocaml_ns_signature.bzl",
     _ocaml_ns_signature = "ocaml_ns_signature"
     )

load("//ocaml/_rules:ocaml_test.bzl"        , _ocaml_test = "ocaml_test")
load("//ocaml/_rules:ocaml_yacc.bzl"        , _ocaml_yacc = "ocaml_yacc")

load("//ocaml/_rules:ppx_module.bzl", _ppx_module = "ppx_module")

load("//ocaml/_rules:ppx_executable.bzl" ,
     _ppx_executable = "ppx_executable")
# load("//ocaml/_rules:ppx_test.bzl",
#      _ppx_expect_test = "ppx_expect_test",
#      _ppx_test = "ppx_test")

# new_local_pkg_repository = _new_local_pkg_repository

ocaml_null = _ocaml_null

ocaml_binary = _ocaml_binary
ocaml_archive    = _ocaml_archive
# ocaml_genrule    = _ocaml_genrule
ocaml_import     = _ocaml_import
ocaml_lex        = _ocaml_lex
ocaml_library    = _ocaml_library
# ocaml_pack_library    = _ocaml_pack_library
ocaml_module     = _ocaml_module
ocaml_ns_archive = _ocaml_ns_archive
ocaml_ns_library = _ocaml_ns_library
ocaml_ns_resolver = _ocaml_ns_resolver
ocaml_signature  = _ocaml_signature
ocaml_ns_signature  = _ocaml_ns_signature
# ocaml_ns_subsignature  = _ocaml_ns_subsignature
ocaml_test       = _ocaml_test
ocaml_yacc       = _ocaml_yacc

ppx_executable   = _ppx_executable
ppx_module       = _ppx_module
# ppx_expect_test  = _ppx_expect_test
# ppx_test         = _ppx_test
