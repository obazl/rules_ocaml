"""Public Providers for obaz_rules_ocaml LSP."""

load("//ocaml/_providers:ocaml.bzl",
     _OcamlProvider           = "OcamlProvider",
     _OcamlArchiveProvider    = "OcamlArchiveProvider",
     _OcamlNsResolverProvider = "OcamlNsResolverProvider",

     ## markers
     _OcamlExecutableMarker = "OcamlExecutableMarker",
     _OcamlImportMarker     = "OcamlImportMarker",
     _OcamlLibraryMarker    = "OcamlLibraryMarker",
     _OcamlModuleMarker     = "OcamlModuleMarker",
     _OcamlNsMarker         = "OcamlNsMarker",
     ## FIXME: choose one:
     _OcamlSignatureMarker  = "OcamlSignatureMarker",
     _OcamlSignatureProvider  = "OcamlSignatureProvider",
     _OcamlTestMarker    = "OcamlTestMarker",
     )

load("//ocaml/_providers:ppx.bzl",
     _PpxAdjunctsProvider     = "PpxAdjunctsProvider",
     _PpxExecutableMarker = "PpxExecutableMarker"
     )

OcamlProvider                      = _OcamlProvider
OcamlArchiveProvider               = _OcamlArchiveProvider
OcamlNsResolverProvider            = _OcamlNsResolverProvider
PpxAdjunctsProvider                = _PpxAdjunctsProvider

OcamlExecutableMarker                 = _OcamlExecutableMarker
OcamlImportMarker                  = _OcamlImportMarker
OcamlLibraryMarker                 = _OcamlLibraryMarker
OcamlModuleMarker                  = _OcamlModuleMarker
OcamlNsMarker                      = _OcamlNsMarker
OcamlSignatureMarker               = _OcamlSignatureMarker
OcamlSignatureProvider             = _OcamlSignatureProvider
OcamlTestMarker                    = _OcamlTestMarker

PpxExecutableMarker = _PpxExecutableMarker

################ Config Settings ################
CompilationModeSettingProvider = provider(
    doc = "Raw value of compilation_mode_flag or setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

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
