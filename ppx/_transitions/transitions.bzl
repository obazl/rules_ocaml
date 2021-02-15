load("@bazel_skylib//lib:structs.bzl", "structs")

def _ppx_mode_transition_impl(settings, attr):
    ppx_mode_val = settings["@ppx//mode:mode"]
    # print("PPX_MODE_TRANSITION: ppx = {ppx}".format( #, ocaml = {ocaml}
    #     ppx = ppx_mode_val # , ocaml = ocaml_mode_val
    # ))
    return {
        "@ocaml//mode": ppx_mode_val,
    }

ppx_mode_transition = transition(
    implementation = _ppx_mode_transition_impl,
    inputs = ["@ppx//mode:mode"],
    outputs = [
        "@ocaml//mode"
    ]
)
