################################################################
def _OCamlModuleProvider_init(*,
                              modname     = None,
                              label_name  = None,
                              namespaced  = None,
                              ns_resolver = None,
                              mlsrc       = None,
                              cmi         = None,
                              cmti        = None,
                              struct      = None,
                              cmt         = None,
                              xmo         = None):
    return {
        "modname"    : modname,
        "label_name" : label_name,
        "namespaced" : namespaced,
        "ns_resolver": ns_resolver,
        "mlsrc"      : mlsrc,
        "cmi"        : cmi,
        "cmti"       : cmti,
        "struct"     : struct,
        "cmt"        : cmt,
        "xmo"        : xmo,
    }

OCamlModuleProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml module provider",
    init   = _OCamlModuleProvider_init,
    fields = {
        "modname"     : "Normalized module name",
        "label_name"  : "Name component of target label",
        "namespaced"  : "True if namespaced",
        "ns_resolver" : "Ns resolver module",
        "mlsrc"       : "One .ml file",
        "cmi"         : "One .cmi file",
        "cmti"        : "One .cmti file",
        "struct"      : "One .cmo or .cmx file",
        "cmt"         : "One .cmt file",
        "xmo"         : "Bool"
    }
)

