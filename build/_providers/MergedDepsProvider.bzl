def _MergedDepsProvider_init(*,
                             sigs          = [],
                             cli_link_deps = [],
                             archives      = [],
                             afiles        = [],
                             astructs      = [],
                             structs       = [],
                             ofiles        = [],
                             mli           = [],
                             cmxs          = [],
                             cmts          = [],
                             cmtis         = [],
                             srcs          = [],
                             cc_dsos       = [],
                             paths         = [],
                             jsoo_runtimes = [],
                             runfiles      = []
                             ):
    return {
        "sigs"          : sigs,
        "cli_link_deps" : cli_link_deps,
        "archives"      : archives,
        "afiles"        : afiles,
        "astructs"      : astructs,
        "structs"       : structs,
        "ofiles"        : ofiles,
        "mli"           : mli,
        "cmxs"          : cmxs,
        "cmts"          : cmts,
        "cmtis"         : cmtis,
        "srcs"          : srcs,
        "cc_dsos"       : cc_dsos,
        "paths"         : paths,
        "jsoo_runtimes" : jsoo_runtimes,
        "runfiles"      : runfiles
    }

# RENAME: MergedDepsProvider
MergedDepsProvider, _new_ocamlocamlinfo = provider(
    init = _MergedDepsProvider_init,
    doc = "foo",
    fields = {
        "sigs"          : "Depset of .cmi files. always added to inputs, never to cmd line.",
        "cli_link_deps" : "Depset of cm[x]a and cm[x|o] files to be added to inputs and link cmd line (executables and archives).",
        "archives"      : "Depset of archives.",
        "astructs"      : "Depset of archived .cmx files.",
        "structs"       : "Depset of unarchived .cmo or .cmx files.",
        "afiles"        : "Depset of the .a files that go with .cmxa files",
        "ofiles"        : "Depset of the .o files that go with .cmx files",
        "mli"           : ".mli files needed for .ml compilation",
        "cmxs"          : ".cmxs files",
        "cmts"          : ".cmt files",
        "cmtis"         : ".cmti files",
        "srcs"          : "source files",
        "cc_dsos"       : ".so files",
        "paths"         : "string depset, for efficiency",
        "jsoo_runtimes" : "depset of runtime.js files",
        "runfiles"      : "one merged Runfiles object"
    }
)
