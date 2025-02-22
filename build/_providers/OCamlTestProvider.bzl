def _OCamlTestProvider_init(*,
                               name = None,
                               ):
    return {
        "name"  : name,
    }

OCamlTestProvider, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlTestProvider_init,
    fields = {
        "name": "String",
    }
)

