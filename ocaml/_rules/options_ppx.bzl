options_ppx = dict(
    opts = attr.string_list(),
    ## CONFIGURABLE DEFAULTS
    _debug           = attr.label(default = "@ppx//debug"),
    _cmt             = attr.label(default = "@ppx//cmt"),
    _keep_locs       = attr.label(default = "@ppx//keep-locs"),
    _noassert        = attr.label(default = "@ppx//noassert"),
    _opaque          = attr.label(default = "@ppx//opaque"),
    _short_paths     = attr.label(default = "@ppx//short-paths"),
    _strict_formats  = attr.label(default = "@ppx//strict-formats"),
    _strict_sequence = attr.label(default = "@ppx//strict-sequence"),
    _verbose         = attr.label(default = "@ppx//verbose"),
)
