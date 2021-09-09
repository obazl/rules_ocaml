"""Public Providers for obaz_rules_ocaml LSP."""

load("//ocaml/_providers:opam.bzl", _OpamConfig = "OpamConfig", _BuildConfig = "BuildConfig")

OpamConfig = _OpamConfig
BuildConfig = _BuildConfig

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

################################################################
# OcamlStdLib = provider()

# OcamlConfigInfo = provider()

# OcamlContextInfo = provider()

# CocamlContextInfo = provider()

# EXPLICIT_PATH = "explicit"

# INFERRED_PATH = "inferred"

# EXPORT_PATH = "export"

module_fields = {
        "name"    : "Module name",
        "module"  : "Module file",
    }

# OcamlDepsetProvider = provider(
#     doc = "A Provider struct used by OBazl rules to provide heterogenous dependencies. Not provided by rule.",
#     fields = {
#         "opam"   : "depset of OPAM deps (Labels) of target",
#         "nopam"  : "depset of non-OPAM deps (Files) of target",
#         "cc_deps"  : "depset of C/C++ lib deps",
#         "cc_linkall" : "string list of cc libs to link with `-force_load` (Clang) or `-whole-archive` (Linux). (Corresponds to `alwayslink` attribute of cc_library etc., and `-linkall` option for OCaml.)"
#    }
# )

# OcamlArchivePayload = provider(
#     doc = "A Provider struct used by [OcamlArchiveProvider](#ocamlarchiveprovider) and [PpxArchiveProvider](providers_ppx.md#ppxarchiveprovider). Not directly provided by any rule.",
#     fields = {
#         "archive": "Name of archive",
#         ## bytecode mode:
#         "cma"    : ".cma file produced by the target (bytecode mode)",
#         ## native mode:
#         "cmxa"   : ".cmxa file produced by the target (native mode)",
#         "a"      : ".a file produced by the target (native mode)",
#         ## -a and -shared are incompatible
#         # "cmxs"   : ".cmxs file produced by the target  (shared object)",
#     }
# )

AdjunctDepsProvider = provider(
    doc    = "Adjuct dependencies provider.",
    fields = {
        "nopam": "Depset of non-opam adjunct deps.",
        "nopam_paths": "Depset of paths of nopam adjunct deps",
        # "opam" : "Depset of opam adjunct deps."
    }
)

OcamlArchiveProvider = provider(
    doc = "OCaml archive provider.",
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = {
    #     "archives": "Depset of archive files.",
    #     "deps": "Depset of archive deps (components) excluding the archive files themselves. To be added to depgraph but not command line."
    # }
)

# OcamlImportProvider = provider(
#     doc = "OCaml import provider.",
#     fields = {
#         "payload": """A struct with the following fields:
#             cmx: .cmx file produced by the target
#             cma: .cma file produced by the target
#             cmxa: .cmxa file produced by the target
#             cmxs: .cmxs file produced by the target
#         """,
#             # ml:  .ml source file. without the source file, the cmi file will be ignored!
#         "indirect"   : "A depset of indirect deps."
#     }
# )

OcamlImportProvider = provider(
    doc = "OCaml import provider.",
    fields = {
        "deps_adjunct":    "Depset of adjunct deps, for ppxes",
        "paths":    "Depset of paths for -I params",
    }
)

OcamlExecutableProvider = provider(
    doc = "OCaml executable provider. Marker interface."
)

OcamlTestProvider = provider(
    doc = "ocaml_test provider. Marker interface."
)

OcamlLibraryProvider = provider(
    doc = """OCaml library provider. A library is a collection of modules, not to be confused with an archive.

Provided by rule: [ocaml_library](rules_ocaml.md#ocaml_library)
    """,
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }

    # fields = {
    #     "payload": """A struct with the following fields:
    #         library: Name of library
    #         modules : vector of modules in lib
    #     """,
    #     "deps"   : """A pair of depsets:
    #         opam : direct and transitive opam deps (Labels) of target
    #         nopam: direct and transitive non-opam deps (Files) of target
    #         cclib: c/c++ lib deps
    #     """
    # }
)

# OcamlInterfacePayload = provider(
#     doc = "OCaml interface payload.",
#     fields = {
#         "cmi"  : ".cmi file produced by the target",
#         "mli"  :  ".mli source file. without the source file, the cmi file will be ignored!"
#     }
# )

CcDepsProvider = provider(
    doc =" OPAM deps provider.",
    fields = {
        "libs": "List of dictionaries of cc deps. Keys: labels; values: linkmode (static | dynamic | default)."
    }
)

OcamlModuleProvider = provider(
    doc = "OCaml module provider.",
    # fields = module_fields
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

# OcamlNsEnvProvider = provider(
#     doc = "OCaml NS Environment provider.",
#     fields = {
#         "resolver": "Name of resolver module",
#         "ap": "Alias prefix",
#         "rp": "Resolver prefix",
#         "sep": "Path separator",
#         # "payload": "An [OcamlNsModulePayload](#ocamlnsmodulepayload) structure.",
#         # "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider)"
#     }
# )

OcamlNsResolverProvider = provider(
    doc = "OCaml NS Resolver provider.",
    fields = {
        "files"   : "Depset, instead of DefaultInfo.files",
        "paths":    "Depset of paths for -I params",
        "submodules": "List of submodules in this ns",
        "resolver": "Name of resolver module",
        "prefixes": "List of alias prefix segs",
    }
)

OcamlNsArchiveProvider = provider(
    doc = "OCaml NS Archive provider.",
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = module_fields
)

OcamlNsLibraryProvider = provider(
    doc = "OCaml NS Library provider.",
    # fields = module_fields
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

OcamlSignatureProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        "mli": ".mli input file",
        "cmi": ".cmi output file",
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = module_fields
    # {
    #     # "ns_module": "Name of ns module (string)",
    #     "paths"    : "Depset of search path strings",
    #     "resolvers": "Depset of resolver module names",
    #     "deps_opam" : "Depset of OPAM package names"

    #     # "payload": "An [OcamlInterfacePayload](#ocamlinterfacepayload) structure.",
    #     # "deps"   : "An [OcamlDepsetProvider](#ocamldepsetprovider)."
    # }
)

# OpamDepsProvider = provider(
#     doc =" OPAM deps provider.",
#     fields = {
#         "pkgs": "Depset of OPAM package name strings."
#     }
# )

################################################################
################################################################

PpxInfo = provider(fields=["ppx", "cmo", "o", "cmx", "a", "cmxa"])

################ Config Settings ################
PpxPrintSettingProvider = provider(
    doc = "Raw value of ppx_print_flag or setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

PpxCompilationModeSettingProvider = provider(
    doc = "Raw value of ppx_mode_flag or setting",
    fields = {
        "value": "The value of the build setting in the current configuration. " +
                 "This value may come from the command line or an upstream transition, " +
                 "or else it will be the build setting's default.",
    },
)

PpxNsArchiveProvider = provider(
    doc = "OCaml PPX NS Archive provider.",
    # fields = module_fields
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

PpxNsLibraryProvider = provider(
    doc = "OCaml PPX NS Library provider.",
    # fields = module_fields
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

# PpxNsModuleProvider = provider(
#     doc = "PPX module provider.",
#     fields = {
#         "payload": """A struct with the following fields:
#             ns : namespace
#             sep: separator
#             cmi: .cmi file produced by the target
#             cm : .cmx/cmo file produced by the target
#             o  : .o file produced by the target
#         """,
#         "deps"   : """A pair of depsets:
#             opam : direct and transitive opam deps (Labels) of target
#             nopam: direct and transitive non-opam deps (Files) of target
#         """
#     }
# )

################################################################
PpxDepsetProvider = provider(
    doc = "A Provider struct used by OBazl rules to provide heterogenous dependencies.",
    fields = {
        "opam"       : "depset of OPAM deps (Labels) of target",
        "opam_adjunct"  : "depset of adjunct OPAM deps; needed when transformed source is compiled",
        "nopam"      : "depset of non-OPAM deps (Files) of target",
        "nopam_adjunct" : "depset of adjunct non-OPAM deps; needed when transformed source is compiled",
        "cc_deps"  : "depset of C/C++ lib deps",
        "cc_linkall" : "string list of cc libs to link with `-force_load` (Clang) or `-whole-archive` (Linux). (Corresponds to `alwayslink` attribute of cc_library etc., and `-linkall` option for OCaml.)"
   }
)

PpxArchiveProvider = provider(
    doc = "OCaml PPX archive provider.",
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = {
    #     "payload": "An [OcamlArchivePayload](providers_ocaml.md#OcamlArchivePayload) provider",
    #     "deps"   : "A [PpxDepsetProvider](#ppxdepsetprovider) provider."
    # }
)

PpxExecutableProvider = provider(
    doc = "OCaml PPX binary provider.",
    fields = {
        "payload": "Executable file produced by the target.",
        "args"   : "Args to be passed when binary is invoked",
        "deps"   : """A triple of depsets:
            opam : direct and transitive opam deps (Labels) of target
            opam_adjunct : extension output deps; needed when transformed source is compiled
            nopam: direct and transitive non-opam deps (Files) of target
            nopam_adjunct : extension output deps; needed when transformed source is compiled
        """
    }
)

PpxLibraryProvider = provider(
    doc = "PPX library provider. A PPX library is a collection of ppx modules.",
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
    # fields = {
    #     "payload": """A struct with the following fields:
    #         name: Name of library
    #         modules : vector of modules in lib
    #     """,
    #     "deps"   : """A pair of depsets:
    #         opam : direct and transitive opam deps (Labels) of target
    #         opam_adjunct_deps : extension output deps; needed when transformed source is compiled
    #         nopam: direct and transitive non-opam deps (Files) of target
    #         nopam_adjunct_deps : extension output deps; needed when transformed source is compiled
    #     """
    # }
)

PpxModuleProvider = provider(
    doc = "OCaml PPX module provider.",
    # fields = module_fields
    fields = {
        "module_links":    "Depset of module files to be linked by executable or archive rules.",
        "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        "paths":    "Depset of paths for -I params",
        "depgraph": "Depset containing transitive closure of deps",
        "archived_modules": "Depset containing archive contents"
    }
)

