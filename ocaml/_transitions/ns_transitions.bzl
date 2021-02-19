load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char")

################################################################
def _ocaml_ns_transition_reset_impl(settings, attr):
    ocaml_ns_val = settings["@ocaml//ns:ns"]

    print("Incoming NS: %s" % ocaml_ns_val)

    # print("////////////////////////////////////////////////////////////////")
    # print("ns OUTGOING: {ns}".format(
    #     ns = ocaml_ns_val
    # ))
    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    # ns_string = attrs["ns"]
    # print("NS: %s" % ns_string)

    return { "@ocaml//ns:ns": "RESET" }

## out transistion
ocaml_ns_transition_reset = transition(
    implementation = _ocaml_ns_transition_reset_impl,
    inputs = ["@ocaml//ns:ns"], # "@ppx//:ns"],
    outputs = ["@ocaml//ns:ns"]  #, "@ppx//:ns"]
)

################################################################
def _ocaml_ns_transition_impl(settings, attr):
    ocaml_ns_val = settings["@ocaml//ns:ns"]

    # print("////////////////////////////////////////////////////////////////")
    # print("ns OUTGOING: {ns}".format(
    #     ns = ocaml_ns_val
    # ))
    attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))
    ns_string = attrs["ns"]
    print("NS: %s" % ns_string)

    return { "@ocaml//ns:ns": ns_string }

## out transistion
ocaml_ns_transition = transition(
    implementation = _ocaml_ns_transition_impl,
    inputs = ["@ocaml//ns:ns"], # "@ppx//:ns"],
    outputs = ["@ocaml//ns:ns"]  #, "@ppx//:ns"]
)

################################################################
def _ocaml_ns_transition_incoming_impl(settings, attr):
    _ignore = settings, attr
    # ocaml_ns_val = settings["@ocaml//:ns"]
    # # ppx_ns_val = settings["@ppx//:ns"]

    # print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
    # print("ns INCOMING: {ns}".format(
    #     ns = ocaml_ns_val
    # ))
    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    return { "@ocaml//ns:ns": "RESET" }

## incoming transistion
ocaml_ns_transition_incoming = transition(
    implementation = _ocaml_ns_transition_incoming_impl,
    inputs = ["@ocaml//ns:ns"], # "@ppx//:ns"],
    outputs = ["@ocaml//ns:ns"]  #, "@ppx//:ns"]
)

################################################################
def _ocaml_ns_submodules_transition_impl(settings, attr):

    print("tsn ns_env: %s" % attr.ns_env)
    pfx = settings["@ocaml//ns:prefix"]
    if pfx != "": pfx = pfx + "__"
    print("tsn ns:prefix: %s" % pfx)
    submodules = attr.submodules.values()
    print("txn SUBMODS: %s" % submodules)

    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    if hasattr(attr, "pkg"):
        if attr.pkg == None:
            pkg = ""
        else:
            print("PKG: %s" % attr.pkg.package)
            pkg = attr.pkg.package
    else:
        pkg = ""

    if attr.main:
        resolver = attr.name + "__0Resolver"
    else:
        resolver = capitalize_initial_char(attr.name)

    return {
        "@ocaml//ns:pkg": pkg,
        "@ocaml//ns:prefix": attr.name,
        "@ocaml//ns:resolver": pfx + resolver,
        "@ocaml//ns:submodules": submodules
    }

## incoming transistion
ocaml_ns_submodules_transition = transition(
    implementation = _ocaml_ns_submodules_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
    ],
    outputs = [
        "@ocaml//ns:pkg",
        "@ocaml//ns:prefix",
        "@ocaml//ns:resolver",
        "@ocaml//ns:submodules"
    ]
)

################################################################
def _ocaml_module_ns_transition_impl(settings, attr):

    print("SETTINGS %s" % settings)
    # print("xSUBMODS %s" % attr._ns_submodules)

    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    if hasattr(attr, "pkg"):
        if attr.pkg == None:
            pkg = ""
        else:
            print("PKG: %s" % attr.pkg.package)
            pkg = attr.pkg.package
    else:
        pkg = ""

    return {
        "@ocaml//ns:pkg": pkg,
        # "@ocaml//ns:prefix": attr.name,
        "@ocaml//ns:resolver": attr.name,
        # "@ocaml//ns:submodules": submods
    }

## incoming transistion
ocaml_module_ns_transition = transition(
    implementation = _ocaml_module_ns_transition_impl,
    inputs = ["@ocaml//ns:submodules"],
    outputs = [
        "@ocaml//ns:pkg",
        # "@ocaml//ns:prefix",
        "@ocaml//ns:resolver",
        # "@ocaml//ns:submodules"
    ]
)
