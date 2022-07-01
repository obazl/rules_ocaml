# An Ocaml "fileset" is the set of files emitted by the Ocaml
# compiler. For modules: .cmx, .cmi, .o; for sigs, just .cmi.

# DefaultInfo.files == whatever is appropriate for the cmd line, e.g. .cmx for modules, .cmxa for archives, .cmi for sigs.

# OcamlProvider.filesets == filesets appropriate for target type. E.g.
# for ns archives, DefaultInfo.files contains the cmxa file, and
# OcamlProvider.filesets contains the filesets for the resolver and
# submodules. For libs, contains filesets for all modules, plus the
# resolver fileset if the lib is namespaced.

# Filesets allow us to extract elements (e.g. cmi files) from
# namespaced libs and archives.

OcamlProvider = provider(
    doc = "OCaml build provider; content depends on target rule type.",
    fields = {

        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx/.o files depending onn mode",
        "ofiles":    "depset of the .o files that go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of the .a files that go with .cmxa files",
        "astructs":  "depset of archived structs, added to link depgraph but not command line",
        "cmts":      "depset of cmt/cmti files",
        "srcs":      "depset of src files after renaming/symlinking, so tools can inspect",

        "xmo":  "boolean; cross-module optimization. False means -opaque was used.",

        "cc_libs" : "list of files",
        "ccinfo"  : "a single CcInfo provider",

        ## everything below is DEPRECATED

        # "fileset": "depset of files emitted by the Ocaml compiler. For modules: .cmx, .cmi, .o; for sigs, just .cmi; for libs and archives, filesets for submodules, plus resolver fileset if namespaced.",

        "cmi" : "Cmi files provided",

        # "closure"             : "File depset of transitive closure of deps",
        # "inputs"             : "file depset",
        # "cdeps"              : "file depset of compile deps",
        # "ldeps"              : "file depset of link deps",
        # "ldeps_n"            : "file depset of native link deps",
        # "ldeps_bc"           : "file depset of bytecode link deps",
        # "linkargs"           : "file depset",
        "paths"             : "string depset",

        # "files"             : "DEPRECATED",
        # "archives"          : "file depset",
        # "archive_deps"       : "file depset of archive deps",
        "ppx_codeps"      : "file depset",
        "ppx_codep_paths" : "string depset",
        "cc_deps"           : "dictionary depset",
        # "ns_resolver"       : "single target",
    }
)

# OcamlArchiveProvider = provider(
#     doc = """OCaml archive provider.

# Produced only by ocaml_archive, ocaml_ns_archive, ocaml_import.  Archive files are delivered in DefaultInfo; this provider holds deps of the archive, to serve as action inputs.
# """,
#     fields = {
#         "files": "file depset of archive's deps",
#         "paths": "string depset"
#     }
# )

# OcamlNsResolverMarker = provider(doc = "OCaml NsResolver Marker provider.")
OcamlNsResolverProvider = provider(
    doc = "OCaml NS Resolver provider.",
    fields = {
        "files"   : "Depset, instead of DefaultInfo.files",
        "paths":    "Depset of paths for -I params",
        "submodules": "String list of submodules in this ns",
        "resolver_src": ".ml src file",
        "module_name": "Name of resolver module.",
        "ns_name": "Name of ns",
        "prefixes": "List of alias prefix segs",

        "cmi"    : "file",
        "struct" : "file",
        "ofile"  : "file"
    }
)

OcamlNsSubmoduleMarker = provider(
    doc = "OCaml NS Submodule Marker.",
    fields = {
        "ns_name": "ns name (joined prefixes)"
    }
)

OcamlSignatureProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        # "deps": "sig deps",

        "mli": ".mli input file",
        "cmi": ".cmi output file",
        "xmo": "boolean: cross-module optimization. False: compile with -opaque",
        # "module_links":    "Depset of module files to be linked by executable or archive rules.",
        # "archive_links":    "Depset of archive files to be linked by executable or archive rules.",
        # "paths":    "Depset of paths for -I params",
        # "depgraph": "Depset containing transitive closure of deps",
        # "archived_modules": "Depset containing archive contents"
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

OcamlArchiveMarker    = provider(doc = "OCaml Archive Marker provider.")
OcamlExecutableMarker = provider(doc = "OCaml Executable Marker provider.")
OcamlImportMarker    = provider(doc = "OCaml Import Marker provider.")
OcamlLibraryMarker   = provider(doc = "OCaml Library Marker provider.")
OcamlModuleMarker    = provider(doc = "OCaml Module Marker provider.")
OcamlNsMarker        = provider(doc = "OCaml Namespace Marker provider.")
OcamlSignatureMarker = provider(doc = "OCaml Signature Marker provider.")
OcamlTestMarker      = provider(doc = "OCaml Test Marker provider.")
