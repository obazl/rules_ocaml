################################################################
def _OCamlNsResolverProvider_init(*,
                                  tag    =  None,
                                  files = [],
                                  paths = [],
                                  submodules = [],
                                  prefixes = [],
                                  resolver_src = None,
                                  module_name  = None,
                                  ns_name = None,
                                  cmi = None,
                                  struct = None,
                                  ofile = None,
                                  ):
    return {
        "tag": tag,
        "files"   : files,
        "paths": paths,
        "submodules": submodules,
        "prefixes": prefixes,
        "resolver_src": resolver_src,
        "module_name": module_name,
        "ns_name": ns_name,
        "cmi"    : cmi,
        "struct" : struct,
        "ofile"  : ofile
    }

OCamlNsResolverProvider, _new_ocamlnsresolverprovider = provider(
    doc = "OCaml NS Resolver provider.",
    init = _OCamlNsResolverProvider_init,
    fields = {
        "tag": "For testing",
        "files"   : "Depset, instead of DefaultInfo.files",
        "paths":    "Depset of paths for -I params",
        "submodules": "String list of submodules in this ns",
        "resolver_src": ".ml src file",
        "module_name": "Name of resolver module.",
        "ns_name": "Name of ns",
        "prefixes": "List of alias prefix segs",

        "cmi"    : "file",
        "struct" : "file",
        "ofile"  : "file"
    }
)
