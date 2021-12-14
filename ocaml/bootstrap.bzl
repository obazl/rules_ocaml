load("//ocaml/_bootstrap:ocaml.bzl", _ocaml_configure = "ocaml_configure")

# load("//ocaml/_bootstrap:obazl.bzl", _obazl_configure = "obazl_configure")

load("//ocaml/_rules:ocaml_repository.bzl"     , _ocaml_repository = "ocaml_repository")

# load("//ocaml/_rules:opam_configuration.bzl"     , _opam_configuration = "opam_configuration")

# load("//ocaml/_toolchains:ocaml_toolchains.bzl",
#      _ocaml_toolchain = "ocaml_toolchain",
#      _ocaml_register_toolchains = "ocaml_register_toolchains")

# obazl_configure    = _obazl_configure
ocaml_configure    = _ocaml_configure
ocaml_repository   = _ocaml_repository
# ocaml_toolchain    = _ocaml_toolchain
# ocaml_register_toolchains = _ocaml_register_toolchains
