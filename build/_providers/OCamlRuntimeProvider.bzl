def _OCamlRuntimeProvider_init(*,
                               name = None,
                               sys  = False,
                               rt   = None,
                               deps = None
                               ):
    return {
        "name"  : name,
        "sys"   : sys,
        "rt"    : rt,
        "deps"  : deps
    }

OCamlRuntimeProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlRuntimeProvider_init,
    fields = {
        "name": "String",
        "sys": "Boolean. Sys runtimes are std, debug, instrumented. Non-sys runtimes are built using ocaml_runtime rule.",
        "rt" : "Label of the runtime file",
        "deps": "Labels of cclib-carrying deps"
    }
)

