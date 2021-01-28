load( "//ocaml:rules.bzl", "ocaml_ns_init")

def ns_init(name="_ns_init", ns=None, srcs=[]):
    if ns == None:
        ocaml_ns_init(
            name = name,
            srcs = srcs
        )
    else:
        ocaml_ns_init(
            name = name,
            ns   = ns,
            srcs = srcs
        )
