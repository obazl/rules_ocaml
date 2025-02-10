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

#######################
def _OcamlProvider_init(*,
                        cmi = None,
                        sig = None,
                        struct = None,
                        cli_link_deps = None,
                        submodule = None,
                        sigs = None,
                        structs = None,
                        ofiles = None,
                        archives = None,
                        afiles = None,
                        astructs = None,
                        cmts = None,
                        cmtis = None,
                        srcs = None,
                        jsoo_runtimes = None,
                        resolvers = None,
                        xmo = None,
                        paths = None,
                        ppx_codeps = None,
                        ppx_codep_paths = None):
    return {
        "cmi"             : cmi,
        "sig"             : sig,
        "struct"          : struct,
        "cli_link_deps"   : cli_link_deps,
        "submodule"       : submodule,
        "sigs"            : sigs,
        "structs"         : structs,
        "ofiles"          : ofiles,
        "archives"        : archives,
        "afiles"          : afiles,
        "astructs"        : astructs,
        "cmts"            : cmts,
        "cmtis"           : cmtis,
        "srcs"            : srcs,
        "jsoo_runtimes"   : jsoo_runtimes,
        "resolvers"       : resolvers,
        "xmo"             : xmo,
        "paths"           : paths,
        "ppx_codeps"      : ppx_codeps,
        "ppx_codep_paths" : ppx_codep_paths
    }

OcamlProvider, _new_ocamlprovider = provider(
    doc = "OCaml build provider; content depends on target rule type.",
    init = _OcamlProvider_init,
    fields = {
        # "ws"  : "Workspace ID for provided artifacts (not fully implemented)",
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
        # NB: resolvers is just for cmdline args, so we can control where
        # they are listed relative to the ns archive/library on the cli
        "resolvers":   "depset of .cmo or .cmx files depending on mode; CLI protocol",

        "xmo":  "boolean; cross-module optimization. False means -opaque was used.",

        "paths"             : "string depset",
        "ppx_codeps"      : "file depset",
        "ppx_codep_paths" : "string depset",
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
OCamlSignatureProvider = provider(
    doc = "OCaml interface provider.",
    fields = {
        "cmi": ".cmi output file",
        "cmti": ".cmti output file",
        "mli": ".mli input file",
        "xmo": "boolean: cross-module optimization. False: compile with -opaque",
    }
)

OcamlArchiveMarker    = provider(doc = "OCaml Archive Marker provider.")
OcamlExecutableMarker = provider(doc = "OCaml Executable Marker provider.")
OcamlImportMarker    = provider(doc = "OCaml Import Marker provider.")
OcamlLibraryMarker   = provider(doc = "OCaml Library Marker provider.")
OcamlModuleMarker    = provider(doc = "OCaml Module Marker provider.")
OcamlNsMarker        = provider(doc = "OCaml Namespace Marker provider.")

# OcamlRuntimeMarker = provider(
#     doc = "OCaml Runtime Variant Marker.",
#     fields = {
#         "variant": "d or i"
#     }
# )

OcamlTestMarker      = provider(doc = "OCaml Test Marker provider.")
