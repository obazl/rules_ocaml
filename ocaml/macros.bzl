load( "//ocaml:rules.bzl", "ocaml_ns_env", _ppx_ns_env = "ppx_ns_env")

def ns_env(name="_ns_env", prefix=None, sep="_", aliases=[]):
    """Expands to instance of rule [ocaml_ns_env](rules_ocaml.md#ocaml_ns_env), which initializes a namespace evaluation environment consisting of a pseudo-namespace prefix string and optionally an ns resolver module.

    Args:
        name: Name of the ns env.
        prefix: String to use as pseudo-namespace prefix for file renaming. Default (`None`) means prefix is to be formed from the package path, with '/' replaced by '_'.
        srcs:   List of source files to be accessible in ns environment. Meaningful only if resolver = True.
        resolver: If true, generate ns resolver module for this ns environment.

    """
    ocaml_ns_env(
        name    = name,
        prefix  = prefix,
        sep     = sep,
        aliases = aliases
    )

################################################################
def ppx_ns_env(name="_ppx_ns_env", prefix=None, sep="_", aliases=[]):
    """Expands to instance of rule [ppx_ns_env](rules_ppx.md#ppx_ns_env), which initializes a namespace evaluation environment consisting of a pseudo-namespace prefix string and optionally an ns resolver module.

    Args:
        name: Name of the ns env.
        prefix: String to use as pseudo-namespace prefix for file renaming. Default (`None`) means prefix is to be formed from the package path, with '/' replaced by '_'.
        srcs:   List of source files to be accessible in ns environment. Meaningful only if resolver = True.
        resolver: If true, generate ns resolver module for this ns environment.

    """
    _ppx_ns_env(
        name    = name,
        prefix  = prefix,
        sep     = sep,
        aliases = aliases
    )
