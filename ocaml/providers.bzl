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

     _OcamlRuntimeMarker    = "OcamlRuntimeMarker",

     ## FIXME: choose one:
     _OCamlSigInfo          = "OCamlSigInfo",
     _OcamlSignatureMarker  = "OcamlSignatureMarker",
     _OcamlSignatureProvider = "OcamlSignatureProvider",
     _OcamlTestMarker        = "OcamlTestMarker",
     _OcamlVmRuntimeProvider = "OcamlVmRuntimeProvider",
     _OpamInstallProvider = "OpamInstallProvider"

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
OcamlRuntimeMarker                 = _OcamlRuntimeMarker
OCamlSigInfo                       = _OCamlSigInfo
OcamlSignatureMarker               = _OcamlSignatureMarker
OcamlSignatureProvider             = _OcamlSignatureProvider
OcamlTestMarker                    = _OcamlTestMarker
OcamlVmRuntimeProvider             = _OcamlVmRuntimeProvider
OpamInstallProvider                = _OpamInstallProvider

PpxExecutableMarker = _PpxExecutableMarker

################################################################
##########################
## MAYBE: add stdlib list, so we can easily add stdlib deps to
## runfiles when needed?
def _OCamlProvider_init(*,
                   sigs          = [],
                   structs       = [],
                   cli_link_deps = [],
                   afiles        = [],
                   ofiles        = [],
                   archived_cmx  = [],
                   mli           = [],
                   paths         = [],
                   # ofiles      = [],
                   # archives    = [],
                   # astructs    = [],
                   # cmts        = [],
                        ):
    return {
        "sigs"          : sigs,
        "structs"       : structs,
        "cli_link_deps" : cli_link_deps,
        "afiles"        : afiles,
        "ofiles"        : ofiles,
        "archived_cmx"  : archived_cmx,
        "mli"           : mli,
        "paths"         : paths,
    }

OCamlProvider, _new_ocamlocamlinfo = provider(
    doc = "foo",
    fields = {
        "sigs"          : "Depset of .cmi files. always added to inputs, never to cmd line.",
        "structs"       : "Depset of unarchived .cmo or .cmx files.",
        "cli_link_deps" : "Depset of cm[x]a and cm[x|o] files to be added to inputs and link cmd line (executables and archives).",
        "afiles"        : "Depset of the .a files that go with .cmxa files",
        "ofiles"        : "Depset of the .o files that go with .cmx files",
        "archived_cmx"  : "Depset of archived .cmx and .o files. always added to inputs, never to cmd line.",
        "mli"           : ".mli files needed for .ml compilation",
        "paths"         : "string depset, for efficiency",
        # "ofiles"        :    "depset of the .o files that go with .cmx files",
        # "archives"      :  "depset of .cmxa and .cma files",
        # "cma"           :       "depset of .cma files",
        # "cmxa"          :       "depset of .cmxa files",
        # "astructs"      :  "depset of archived structs, added to link depgraph but not command line.",
        # "cmts"          :      "depset of cmt/cmti files",
    },
    init = _OCamlProvider_init
)

def dump_ocamlinfo(bi):
    print("sigs: %s" % bi.sigs)
    print("structs: %s" % bi.structs)
    print("linkdeps: %s" % bi.cli_link_deps)

##########################
# DepsAggregator = provider(
#     fields = {
#         "deps"    : "struct of OCamlProvider providers",
#         "ccinfos" : "list of CcInfo providers",
#         "ccinfos_archived" : "list of ccinfos whose metadata is archived",
#     }
# )

# def new_deps_aggregator():
#     return DepsAggregator(
#         deps = OCamlProvider(
#             sigs          = [],
#             structs       = [],
#             cli_link_deps = [],
#             afiles        = [],
#             ofiles        = [],
#             archived_cmx  = [],
#             mli           = [],
#             paths         = [],
#             # ofiles      = [],
#             # archives    = [],
#             # astructs    = [], # archived cmx structs, for linking
#             # cmts        = [],
#         ),
#         ccinfos           = [],
#         ccinfos_archived  = []
#     )

################################################################
## LEGACY
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
