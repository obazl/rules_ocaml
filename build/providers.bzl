"""Public definitions for rules_ocaml providers.

All public providers imported and re-exported in this file.

Definitions outside this file are private unless otherwise noted, and
may change without notice. Really.
"""

load("//build/_providers:MergedDepsProvider.bzl",
     _MergedDepsProvider = "MergedDepsProvider")

load("//build/_providers:OCamlCcInfo.bzl",
     _OCamlCcInfo = "OCamlCcInfo")

load("//build/_providers:OCamlCodepsProvider.bzl",
     _OCamlCodepsProvider = "OCamlCodepsProvider")

load("//build/_providers:OCamlImportProvider.bzl",
     _OCamlImportProvider = "OCamlImportProvider")

load("//build/_providers:OCamlLibraryProvider.bzl",
     _OCamlLibraryProvider = "OCamlLibraryProvider")

load("//build/_providers:OCamlModuleProvider.bzl",
     _OCamlModuleProvider = "OCamlModuleProvider")

load("//build/_providers:OCamlNsResolverProvider.bzl",
     _OCamlNsResolverProvider = "OCamlNsResolverProvider")

load("//build/_providers:OCamlDepsProvider.bzl",
     _OCamlDepsProvider = "OCamlDepsProvider")

load("//build/_providers:OpamInstallProvider.bzl",
     _OpamInstallProvider = "OpamInstallProvider")

load("//build/_providers:OCamlRuntimeProvider.bzl",
     _OCamlRuntimeProvider = "OCamlRuntimeProvider")

load("//build/_providers:OCamlSignatureProvider.bzl",
     _OCamlSignatureProvider = "OCamlSignatureProvider")

load("//build/_providers:OCamlTestProvider.bzl",
     _OCamlTestProvider = "OCamlTestProvider")


OCamlCcInfo             = _OCamlCcInfo
OCamlCodepsProvider     = _OCamlCodepsProvider
MergedDepsProvider      = _MergedDepsProvider
OCamlDepsProvider       = _OCamlDepsProvider
OCamlImportProvider     = _OCamlImportProvider
OCamlLibraryProvider    = _OCamlLibraryProvider
OCamlModuleProvider     = _OCamlModuleProvider
OCamlNsResolverProvider = _OCamlNsResolverProvider
OpamInstallProvider     = _OpamInstallProvider
OCamlRuntimeProvider    = _OCamlRuntimeProvider
OCamlSignatureProvider  = _OCamlSignatureProvider
OCamlTestProvider       = _OCamlTestProvider

PpxExecutableMarker = provider(doc = "Ppx Executable Marker provider.")

PpxModuleMarker = provider(
    doc = "PPX module Marker.",
    # fields = {
    #     "name": "name of module"
    # }
)

OcamlArchiveMarker    = provider(doc = "OCaml Archive Marker provider.")
OcamlExecutableMarker = provider(doc = "OCaml Executable Marker provider.")
# OCamlModuleProvider    = provider(doc = "OCaml Module Marker provider.")
OcamlNsMarker        = provider(doc = "OCaml Namespace Marker provider.")
OcamlNsSubmoduleMarker = provider(
    doc = "OCaml NS Submodule Marker.",
    fields = {
        "ns_name": "ns name (joined prefixes)"
    }
)

OcamlSDK = provider(
    doc = "Contains information about the Ocaml SDK used in the toolchain",
    fields = {
        "path": "Absolute path to sdk",
        "ocamlos": "The host OS the SDK was built for.",
        "ocamlarch": "The host architecture the SDK was built for.",
        "root_file": "A file in the SDK root directory",
        "libs": ("List of pre-compiled .a files for the standard library " +
                 "built for the execution platform."),
        "headers": ("List of .h files from pkg/include that may be included " +
                    "in assembly sources."),
        "srcs": ("List of source files for importable packages in the " +
                 "standard library. Internal, vendored, and tool packages " +
                 "may not be included."),
        "package_list": ("A file containing a list of importable packages " +
                         "in the standard library."),
        "tools": ("List of executable files in the SDK built for " +
                  "the execution platform, excluding the ocaml binary file"),
        "ocaml": "The ocaml binary file",
    },
)
