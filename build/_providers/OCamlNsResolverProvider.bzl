################################################################
def _OCamlNsResolverProvider_init(*,
                                  tag          =  None,
                                  files        = [],
                                  paths        = [],
                                  submodules   = [],
                                  prefixes     = [],
                                  resolver_src = None,
                                  fs_prefix    = None,
                                  modname      = None,
                                  ns_fqn       = None,
                                  cmi          = None,
                                  struct       = None,
                                  ofile        = None,
                                  ):
    return {
        "tag"          : tag,
        "files"        : files,
        "paths"        : paths,
        "submodules"   : submodules,
        "prefixes"     : prefixes,
        "resolver_src" : resolver_src,
        "fs_prefix"    : fs_prefix,
        "modname"      : modname,
        "ns_fqn"       : ns_fqn,
        "cmi"          : cmi,
        "struct"       : struct,
        "ofile"        : ofile
    }

OCamlNsResolverProvider, _new_ocamlnsresolverprovider = provider(
    doc = "OCaml NS Resolver provider.",
    init = _OCamlNsResolverProvider_init,
    fields = {
        "tag"          : "For testing",
        "files"        : "Depset, instead of DefaultInfo.files",
        "paths"        :    "Depset of paths for -I params",
        "submodules"   : "String list of submodules in this ns",
        "resolver_src" : ".ml src file",
        "fs_prefix"    : "prefix to use in module renaming",
        "modname"      : "Name of resolver module.",
        "ns_fqn"       : "Fully-qualified name of ns",
        "prefixes"     : "List of alias prefix segs",

        "cmi"          : "file",
        "struct"       : "file",
        "ofile"        : "file"
    }
)
