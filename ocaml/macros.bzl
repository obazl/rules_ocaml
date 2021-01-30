load( "//ocaml:rules.bzl", "ocaml_ns_resolver")

def ns(name="_ns_resolver", ns=None, srcs=[]):
    if ns == None:
        ocaml_ns_resolver(
            name = name,
            srcs = srcs
        )
    else:
        ocaml_ns_resolver(
            name = name,
            ns   = ns,
            srcs = srcs
        )
