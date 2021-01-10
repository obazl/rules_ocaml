load("@bazel_skylib//lib:structs.bzl", "structs")

def _ppx_mode_transition_impl(settings, attr):
    ppx_mode_val = settings["@ppx//mode:mode"]
    # ocaml_mode_val = settings["@ocaml//mode:mode"]

    # print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    # print("PPX_MODE_TRANSITION: ppx = {ppx}".format( #, ocaml = {ocaml}
    #     ppx = ppx_mode_val # , ocaml = ocaml_mode_val
    # ))
    attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    return {
        # "@ppx//mode": ppx_mode_val,
        "@ocaml//mode": ppx_mode_val,
    }

ppx_mode_transition = transition(
    implementation = _ppx_mode_transition_impl,
    inputs = ["@ppx//mode:mode"], # "@ocaml//mode:mode"],
    outputs = ["@ocaml//mode"]  #, "@ocaml//mode"]
)
