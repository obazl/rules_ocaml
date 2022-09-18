"""Public Providers for rules_ocaml."""

load("//ocaml/_providers:ocaml.bzl",
     _OcamlProvider           = "OcamlProvider",
     # FIXME: choose one:
     _OcamlArchiveMarker     = "OcamlArchiveMarker",
     # _OcamlArchiveProvider   = "OcamlArchiveProvider",
     _OcamlNsResolverProvider = "OcamlNsResolverProvider",

     ## markers
     _OcamlExecutableMarker = "OcamlExecutableMarker",
     _OcamlImportMarker     = "OcamlImportMarker",
     _OcamlLibraryMarker    = "OcamlLibraryMarker",
     _OcamlModuleMarker     = "OcamlModuleMarker",
     _OcamlNsMarker         = "OcamlNsMarker",
     _OcamlNsSubmoduleMarker = "OcamlNsSubmoduleMarker",
     ## FIXME: choose one:
     _OcamlSignatureMarker  = "OcamlSignatureMarker",
     _OcamlSignatureProvider = "OcamlSignatureProvider",
     _OcamlTestMarker        = "OcamlTestMarker",
     _OcamlVmRuntimeProvider = "OcamlVmRuntimeProvider"
     )

load("//ppx:providers.bzl", # FIXME: //ppx/_providers.bzl?
     # _PpxCodepsProvider     = "PpxCodepsProvider",
     _PpxExecutableMarker = "PpxExecutableMarker"
     )

OcamlProvider                      = _OcamlProvider
OcamlArchiveMarker                 = _OcamlArchiveMarker
# OcamlArchiveProvider               = _OcamlArchiveProvider
OcamlNsResolverProvider            = _OcamlNsResolverProvider
# PpxCodepsProvider                = _PpxCodepsProvider

OcamlExecutableMarker                 = _OcamlExecutableMarker
OcamlImportMarker                  = _OcamlImportMarker
OcamlLibraryMarker                 = _OcamlLibraryMarker
OcamlModuleMarker                  = _OcamlModuleMarker
OcamlNsMarker                      = _OcamlNsMarker
OcamlNsSubmoduleMarker             = _OcamlNsSubmoduleMarker
OcamlSignatureMarker               = _OcamlSignatureMarker
OcamlSignatureProvider             = _OcamlSignatureProvider
OcamlTestMarker                    = _OcamlTestMarker
OcamlVmRuntimeProvider             = _OcamlVmRuntimeProvider

PpxExecutableMarker = _PpxExecutableMarker

################
OcamlVerboseFlagProvider = provider(
    doc = "Raw value of ocaml_verbose_flag",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

################################################################
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
