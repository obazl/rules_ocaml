load("@bazel_skylib//lib:structs.bzl", "structs")

def _ocaml_mode_transition_impl(settings, attr):
    ocaml_mode_val = settings["@ocaml//mode:mode"]
    ppx_mode_val = settings["@ppx//mode:mode"]

    # print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    # print("OCAML_MODE_TRANSITION_IN: ocaml mode = {ocaml}, ppx mode = {ppx}".format( #, ocaml = {ocaml}
    #     ocaml = ocaml_mode_val, ppx = ppx_mode_val
    # ))
    attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    return {
        # "@ocaml//mode": ocaml_mode_val,
        "@ocaml//mode": ocaml_mode_val,
    }

ocaml_mode_transition_incoming = transition(
    implementation = _ocaml_mode_transition_impl,
    inputs = ["@ocaml//mode:mode", "@ppx//mode:mode"],
    outputs = ["@ocaml//mode"]  #, "@ocaml//mode"]
)

################################################################
def _ocaml_mode_transition_out_impl(settings, attr):
    ocaml_mode_val = settings["@ocaml//mode:mode"]
    ppx_mode_val = settings["@ppx//mode:mode"]

    # print("////////////////////////////////////////////////////////////////")
    # print("OCAML_MODE_TRANSITION_OUT: ocaml mode = {ocaml}, ppx mode = {ppx}".format( #, ocaml = {ocaml}
    #     ocaml = ocaml_mode_val, ppx = ppx_mode_val
    # ))
    attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))
    

    return {
        # "@ocaml//mode": ocaml_mode_val,
        "@ocaml//mode": ocaml_mode_val,
    }

ocaml_mode_transition_outgoing = transition(
    implementation = _ocaml_mode_transition_out_impl,
    inputs = ["@ocaml//mode:mode", "@ppx//mode:mode"],
    outputs = ["@ocaml//mode"]  #, "@ocaml//mode"]
)
