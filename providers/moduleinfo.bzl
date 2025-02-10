################################################################
def _OCamlModuleInfo_init(*,
                          name       = None,
                          label_name = None,
                          namespaced = False,
                          ns_resolver = None,
                          sig        = None,
                          sig_src    = None,
                          cmti       = None,
                          struct     = None,
                          struct_src = None,
                          structfile = None,  #original basename, unnormalized
                          cmt        = None,
                          ofile      = None,
                          files      = None):
    return {
        "name"       : name,
        "label_name" : label_name,
        "namespaced" : namespaced,
        "ns_resolver": ns_resolver,
        "sig"        : sig,
        "sig_src"    : sig_src,
        "cmti"       : cmti,
        "struct"     : struct,
        "struct_src" : struct_src,
        "structfile" : structfile,
        "cmt"        : cmt,
        "ofile"      : ofile,
        "files"      : files
    }

OCamlModuleInfo, _new_ocamlmoduleinfo = provider(
    doc = "foo",
    init = _OCamlModuleInfo_init,
    fields = {
        "name": "Normalized module name",
        "label_name": "Name component of target label",
        "namespaced": "True if namespaced",
        "ns_resolver": "Ns resolver module",
        "sig"   : "One .cmi file",
        "sig_src"   : "One .mli file",
        "cmti"  : "One .cmti file",
        "struct": "One .cmo or .cmx file",
        "struct_src": "One .ml file, normalized, in workdir",
        "structfile": "Original .ml file basename, non-normalized",
        "cmt"  : "One .cmt file",
        "ofile" : "One .o file if struct is .cmx",
        "files": "Depset of the above"
    }
)

