load("@bazel_skylib//lib:structs.bzl", "structs")

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
