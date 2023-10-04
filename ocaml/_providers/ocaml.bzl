################################################################
def _ModuleInfo_init(*,
                     name = None,
                     sig = None,
                     sig_src = None,
                     cmti = None,
                     struct = None,
                     struct_src = None,
                     structfile = None,  #original basename, unnormalized
                     cmt = None,
                     ofile = None,
                     files = None):
    return {
        "name": name,           # normalized module name
        "sig" : sig,            # .cmi
        "sig_src": sig_src,
        "cmti": cmti,
        "struct": struct,         # .cmo or .cmx
        "struct_src": struct_src, # original src
        "structfile": structfile, # symlinked src
        "cmt": cmt,
        "ofile": ofile,
        "files": files
    }

ModuleInfo, _new_moduleinfo = provider(
    doc = "foo",
    fields = {
        "name": "Normalized module name",
        "sig"   : "One .cmi file",
        "sig_src"   : "One .mli file",
        "cmti"  : "One .cmti file",
        "struct": "One .cmo or .cmx file",
        "struct_src": "One .ml file, normalized, in workdir",
        "structfile": "Original .ml file basename, non-normalized",
        "cmt"  : "One .cmt file",
        "ofile" : "One .o file if struct is .cmx",
        "files": "Depset of the above"
    },
    init = _ModuleInfo_init
)

################################################################
def _OCamlSigInfo_init(*,
                       cmi  = None,
                       cmti = None,
                       ##FIXME: rename sig_src,
                       ##for consistency with ModuleInfo
                       mli  = None,
                       xmo  = False):
    return {
        "cmi"  : cmi,
        "cmti" : cmti,
        "mli"  : mli,
        "xmo"  : xmo
    }

OCamlSigInfo, _new_ocamlsiginfo = provider(
    doc = "OCaml signature provider",
    fields = {
        "cmi"  : "One .cmi file",
        "cmti" : "One .cmti file",
        "mli"  : "One .mli file",
        "xmo"  : "Boolean, false if compiled with -opaque"
    },
    init = _OCamlSigInfo_init
)

################################################################

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
        "ws"  : "Workspace ID for provided artifacts (not fully implemented)",
        "cmi" : "Cmi file provided",
        "sig" : "Cmi file provided",
        "struct" : "Structure file (.cmo or .cmx) provided",

        ## cli link deps: the other fields are not sufficient, since
        ## they are strictly typed (archives v. structs), but actual
        ## deps may be mixed. E.g. a module A in archive foo may
        ## depend on a free-standing module B that depends on an
        ## archive bar. In that case dep order is bar B foo. Using
        ## only the archives, structs, and astructs fields we would
        ## not be able to express this. We would get either bar foo B
        ## or B bar foo.

        "cli_link_deps": "depset of files (targets?) to be added to link cmd line",

        "submodule": "name of module without ns prefix",
        "sigs":      "depset of .cmi files",
        # NB: structs should exclude archive_deps. Its for freestanding
        # deps of <this> target (?)
        "structs":   "depset of .cmo or .cmx files depending on mode",
        "ofiles":    "depset of the .o files that go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of the .a files that go with .cmxa files",
        "astructs":  "depset of archived structs, added to link depgraph but not command line.",
        "cmts":      "depset of cmt files",
        "cmtis":      "depset of cmti files",
        "srcs":      "depset of src files after renaming/symlinking, so tools can inspect",

        "jsoo_runtimes": "depset of runtime.js files",
        # "archive_deps": "deps of archives, that must be listed before the archives in cmd line to link executable. cmx/cmo only, for cmd line",

        # NB: resolvers is just for cmdline args, so we can control where
        # they are listed relative to the ns archive/library on the cli
        "resolvers":   "depset of .cmo or .cmx files depending on mode; CLI protocol",

        "xmo":  "boolean; cross-module optimization. False means -opaque was used.",

        ## OBSOLETE: cc deps passed in separate CcInfo
        # "cc_libs" : "list of files",
        # "ccinfo"  : "a single CcInfo provider, merged",
        # "cc_deps"           : "dictionary depset",

        ## everything below is DEPRECATED

        # "fileset": "depset of files emitted by the Ocaml compiler. For modules: .cmx, .cmi, .o; for sigs, just .cmi; for libs and archives, filesets for submodules, plus resolver fileset if namespaced.",

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

        # OBSOLETE: codeps passed separately by PpxCodepsProvider
        "ppx_codeps"      : "file depset",
        "ppx_codep_paths" : "string depset",
        # "ns_resolver"       : "single target",
    }
)

def _OpamInstallProvider_init(*,
                              archives = None,
                              sigs     = None,
                              structs  = None,
                              cmts     = None,
                              srcs     = None,
                              ccinfo   = None):
    return {
        "archives": archives,
        "sigs": sigs,
        "structs": structs,
        "cmts": cmts,
        "srcs": srcs,
        "ccinfo": ccinfo
    }

OpamInstallProvider, _new_opaminstallprovider = provider(
    doc = "Provides artifacts for OPAM pkg installation",
    fields = {
        "archives":  "depset of .cma or .cmxa files (plus .a)",
        "sigs":      "depset of .cmi files",
        "structs":   "depset of .cmo or .cmx files (plus .o)",

        "cmts":      "depset of cmt/cmti files",
        "srcs":      "depset of src files",

        "ccinfo"  : "a single CcInfo provider",
    },
    init = _OpamInstallProvider_init
)

OcamlVmRuntimeProvider = provider(
    doc = "OCaml VM Runtime provider",
    fields = {
        "kind": "string: dynamic (default), static, or standalone"
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

OcamlNsSubmoduleMarker = provider(
    doc = "OCaml NS Submodule Marker.",
    fields = {
        "ns_name": "ns name (joined prefixes)"
    }
)

# OcamlNsResolverMarker = provider(doc = "OCaml NsResolver Marker provider.")
################################################################
def _OCamlNsResolverProvider_init(*,
                                  tag    =  None,
                                  files = [],
                                  paths = [],
                                  submodules = [],
                                  prefixes = [],
                                  resolver_src = None,
                                  module_name  = None,
                                  ns_name = None,
                                  cmi = None,
                                  struct = None,
                                  ofile = None,
                                  ):
    return {
        "tag": tag,
        "files"   : files,
        "paths": paths,
        "submodules": submodules,
        "prefixes": prefixes,
        "resolver_src": resolver_src,
        "module_name": module_name,
        "ns_name": ns_name,
        "cmi"    : cmi,
        "struct" : struct,
        "ofile"  : ofile
    }

OcamlNsResolverProvider, _new_OcamlNsResolverProvider = provider(
    doc = "OCaml NS Resolver provider.",
    fields = {
        "tag": "For testing",
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
    },
    init = _OCamlNsResolverProvider_init
)

################################################################
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

OcamlRuntimeMarker = provider(
    doc = "OCaml Runtime Variant Marker.",
    fields = {
        "variant": "d or i"
    }
)


OcamlSignatureMarker = provider(doc = "OCaml Signature Marker provider.")
OcamlTestMarker      = provider(doc = "OCaml Test Marker provider.")
