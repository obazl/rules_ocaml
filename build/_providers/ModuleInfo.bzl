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

