################################################################
def _OCamlNsResolverProvider_init(*,
                                  tag          =  None,
                                  files        = [],
                                  paths        = [],
                                  submodules   = [],
                                  import_as    = [],
                                  ns_import_as = [],
                                  ns_merge     = [],
                                  prefixes     = [],
                                  resolver_src = None,
                                  stem         = None,
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
        "import_as"    : import_as,
        "ns_import_as" : ns_import_as,
        "ns_merge"     : ns_merge,
        "prefixes"     : prefixes,
        "stem"         : stem,
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
        "import_as"    : "Label-keyed dict",
        "ns_import_as" : "Label-keyed dict",
        "ns_merge"     :  "Label list",
        "stem"         : "stem of .ml src file",
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
