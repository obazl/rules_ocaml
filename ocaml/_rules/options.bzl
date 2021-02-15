load("//ocaml:providers.bzl", "PpxExecutableProvider")

def options(ws):
    return dict(
        opts             = attr.string_list(
            doc          = "List of OCaml options. Will override configurable default options."
        ),
        ## GLOBAL CONFIGURABLE DEFAULTS (all ppx_* rules)
        _debug           = attr.label(default = ws + "//debug"),
        _cmt             = attr.label(default = ws + "//cmt"),
        _keep_locs       = attr.label(default = ws + "//keep-locs"),
        _noassert        = attr.label(default = ws + "//noassert"),
        _opaque          = attr.label(default = ws + "//opaque"),
        _short_paths     = attr.label(default = ws + "//short-paths"),
        _strict_formats  = attr.label(default = ws + "//strict-formats"),
        _strict_sequence = attr.label(default = ws + "//strict-sequence"),
        _verbose         = attr.label(default = ws + "//verbose"),
    )

options_ppx = dict(
        ppx  = attr.label(
            doc = "Label of `ppx_executable` target to be used to transform source before compilation.",
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Options to pass to PPX executable passed by the `ppx` attribute.",
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. List of labels of files needed by the PPX executable passed via the `ppx` attribute when it is executed to transform the source file. For example, a source file using [ppx_optcomp](https://github.com/janestreet/ppx_optcomp) may import a file using extension `[%%import ]`; this file should be listed in this attribute.",
            allow_files = True,
        ),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform. Value must be one of '@ppx//print:binary', '@ppx//print:text'.  See [PPX Support](../ug/ppx.md#ppx_print) for more information",
            default = "@ppx//print"
        ),
        ppx_tags  = attr.string_list(
            doc = "DEPRECATED. List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
        )
)
