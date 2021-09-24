## ocaml/_rules/impl_common.bzl

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "PpxAdjunctsProvider",
     "OcamlArchiveProvider",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureMarker",
     )

tmpdir = "" # "__obazl/"

dsorder = "postorder"

opam_lib_prefix = "external/ocaml/_lib"

module_sep = "__"

resolver_suffix = module_sep + "0Resolver"
