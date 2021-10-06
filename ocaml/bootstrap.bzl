load("//ocaml/_bootstrap:ocaml.bzl", _ocaml_configure = "ocaml_configure")
# load("//ocaml/_bootstrap:obazl.bzl", _obazl_configure = "obazl_configure")
load("//ocaml/_rules:ocaml_repository.bzl"     , _ocaml_repository = "ocaml_repository")
# load("//ocaml/_rules:opam_configuration.bzl"     , _opam_configuration = "opam_configuration")

# obazl_configure    = _obazl_configure
ocaml_configure    = _ocaml_configure
ocaml_repository   = _ocaml_repository
# opam_configuration = _opam_configuration
