#######################
def _OCamlDepsProvider_init(*,
                            modname         = None,
                            cmi             = None,
                            sig             = None,
                            struct          = None,
                            cli_link_deps   = None,
                            link_archives_deps = None,
                            submodule       = None,
                            sigs            = None,
                            structs         = None,
                            ofiles          = None,
                            archives        = None,
                            afiles          = None,
                            astructs        = None,
                            cmxs            = None,
                            cmts            = None,
                            cmtis           = None,
                            srcs            = None,
                            cc_dsos         = None,
                            jsoo_runtimes   = None,
                            resolvers       = None,
                            xmo             = None,
                            paths           = None,
                            ppx_codeps      = None,
                            ppx_codep_paths = None):
    return {
        "modname"         : modname,
        "cmi"             : cmi,
        "sig"             : sig,
        "struct"          : struct,
        "cli_link_deps"   : cli_link_deps,
        "link_archives_deps": link_archives_deps,
        "submodule"       : submodule,
        "sigs"            : sigs,
        "structs"         : structs,
        "ofiles"          : ofiles,
        "archives"        : archives,
        "afiles"          : afiles,
        "astructs"        : astructs,
        "cmxs"            : cmxs,
        "cmts"            : cmts,
        "cmtis"           : cmtis,
        "srcs"            : srcs,
        "cc_dsos"         : cc_dsos,
        "jsoo_runtimes"   : jsoo_runtimes,
        "resolvers"       : resolvers,
        "xmo"             : xmo,
        "paths"           : paths,
        "ppx_codeps"      : ppx_codeps,
        "ppx_codep_paths" : ppx_codep_paths
    }

OCamlDepsProvider, _new_ocamlprovider = provider(
    doc = "OCaml build provider; content depends on target rule type.",
    init = _OCamlDepsProvider_init,
    fields = {
        # "ws"  : "Workspace ID for provided artifacts (not fully implemented)",
        "modname": "Module name",
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

        "cli_link_deps": "depset of modules w/o archives to be added to link cmd line",

        "link_archives_deps": "depset of archives and modules to be added to link cmd line",

        "submodule": "name of module without ns prefix",
        "sigs":      "depset of .cmi files",
        # NB: structs should exclude archive_deps. Its for freestanding
        # deps of <this> target (?)
        "structs":   "depset of .cmo or .cmx files depending on mode",
        "ofiles":    "depset of the .o files that go with .cmx files",
        "archives":  "depset of .cmxa or .cma files",
        "afiles":    "depset of the .a files that go with .cmxa files",
        "astructs":  "depset of archived structs, added to link depgraph but not command line.",
        "cmxs":      "cmxs shared libs",
        "cmts":      "depset of cmt files",
        "cmtis":      "depset of cmti files",
        "srcs":      "depset of src files after renaming/symlinking, so tools can inspect",
        "cc_dsos":   "list of depsets of .so files",
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

