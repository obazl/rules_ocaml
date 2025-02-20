def _OCamlCcInfo_init(*,
                      direct = None,
                      archived = None
                      ):
    return {
        "direct"   : direct,
        "archived" : archived
    }

OCamlCcInfo, _new_ocamlmoduleinfo = provider(
    doc    = "OCaml runtime provider",
    init   = _OCamlCcInfo_init,
    fields = {
        "direct": "CcInfo",
        "archived": "CcInfo",
    }
)

