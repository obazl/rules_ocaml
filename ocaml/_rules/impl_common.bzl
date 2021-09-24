## ocaml/_rules/impl_common.bzl

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "PpxAdjunctsProvider",
     "CcDepsProvider",
     "OcamlArchiveProvider",
     # "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureMarker",
     "PpxArchiveMarker",
     "PpxLibraryMarker",
     "PpxModuleMarker",
     )

# load("//ocaml:providers.bzl",
#      "OcamlImportMarker",
#      "OcamlImportArchivesMarker",
#      "OcamlImportPluginsMarker",
#      "OcamlImportSignaturesMarker",
#      "OcamlImportPathsMarker",
#      "OcamlImportPpxAdjunctsMarker")

tmpdir = "" # "__obazl/"

dsorder = "postorder"

opam_lib_prefix = "external/ocaml/_lib"

module_sep = "__"

resolver_suffix = module_sep + "0Resolver"
