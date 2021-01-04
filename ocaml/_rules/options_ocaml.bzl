options_ocaml = dict(
    opts             = attr.string_list(
        doc          = "List of OCaml options. Will override global default options."
    ),
    ## GLOBAL CONFIGURABLE DEFAULTS (all rules)
    _debug           = attr.label(default = "@ocaml//debug"),
    _cmt             = attr.label(default = "@ocaml//cmt"),
    _keep_locs       = attr.label(default = "@ocaml//keep-locs"),
    _noassert        = attr.label(default = "@ocaml//noassert"),
    _opaque          = attr.label(default = "@ocaml//opaque"),
    _short_paths     = attr.label(default = "@ocaml//short-paths"),
    _strict_formats  = attr.label(default = "@ocaml//strict-formats"),
    _strict_sequence = attr.label(default = "@ocaml//strict-sequence"),
    _verbose         = attr.label(default = "@ocaml//verbose"),
)
