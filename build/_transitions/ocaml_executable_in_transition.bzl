load("in_transitions.bzl", "executable_in_transition_impl")

#######################################################
def _ocaml_executable_in_transition_impl(settings, attr):
    r = executable_in_transition_impl("ocaml_executable_in_transition", settings, attr)
    # print(r)
    return r

ocaml_executable_in_transition = transition(
    implementation = _ocaml_executable_in_transition_impl,
    inputs = [
        # "@rules_ocaml//cfg/ns:prefixes",
        # "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ],
    outputs = [
        # "@rules_ocaml//cfg/ns:prefixes",
        # "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ]
)

