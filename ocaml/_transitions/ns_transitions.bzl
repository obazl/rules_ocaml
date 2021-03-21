load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_label",
     "normalize_module_name")

#######################################
def print_config_state(settings, attr):

    print("  rule name: %s" % attr.name)
    print("  ns:prefixes: %s" % settings["@ocaml//ns:prefixes"])
    print("  ns:submodules: %s" % settings["@ocaml//ns:submodules"])
    if hasattr(attr, "submodules"):
        print("  attr.submodules: %s" % attr.submodules)

##############################################
def _nsarchive_in_transition_impl(settings, attr):
    debug = False
    # if attr.name in ["color"]:
    #     debug = True

    if debug:
        print("")
        print(">>> nsarchive_in_transition")
        print_config_state(settings, attr)
        print(attr)

    # # if this in ns:submodules
    # #     pass on prefix but not ns:submodules
    # # else
    # #     reset ConfigState

    # pfx = ""
    # prefixes = []

    # if settings["@ocaml//ns:transitivity"]:
    #     prefixes.extend(settings["@ocaml//ns:prefixes"])
    #     for submod_lbl in settings["@ocaml//ns:submodules"]:
    #         if attr.name == Label(submod_lbl).name:
    #             prefixes.append(normalize_module_name(attr.name))
    #             break

    return {
        "@ocaml//ns:prefixes"  : [],
        "@ocaml//ns:submodules": [],
    }

###################
nsarchive_in_transition = transition(
    ## """Reset ConfigState for both @ocaml and @ppx.""",
    implementation = _nsarchive_in_transition_impl,
    inputs = [
        # "@ocaml//ns:transitivity",
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

##############################################
def _nslib_in_transition_impl(settings, attr):
    debug = False
    # if attr.name in ["color"]:
    #     debug = True

    if debug:
        print("")
        print(">>> nslib_in_transition")
        print_config_state(settings, attr)
        print(attr)

    # if this in ns:submodules
    #     pass on prefix but not ns:submodules
    # else
    #     reset ConfigState

    prefixes = []

    # if settings["@ocaml//ns:transitivity"]:
    #     prefixes.extend(settings["@ocaml//ns:prefixes"])
    #     for submod_lbl in settings["@ocaml//ns:submodules"]:
    #         if attr.name == Label(submod_lbl).name:
    #             prefixes.append(normalize_module_name(attr.name))
    #             break

    return {
        "@ocaml//ns:prefixes"  : [], # prefixes,
        "@ocaml//ns:submodules": [],
    }

###################
nslib_in_transition = transition(
    ## """Reset ConfigState for both @ocaml and @ppx.""",
    implementation = _nslib_in_transition_impl,
    inputs = [
        # "@ocaml//ns:transitivity",
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

################################################################
def _ocaml_nslib_out_transition_impl(transition, settings, attr):

    debug = False
    # if attr.name in ["color"]:
    #     debug = True

    if debug:
        print("")
        print(">>> " + transition)
        print_config_state(settings, attr)

    if attr.name.startswith("#"):
        nslib_submod = True
    else:
        nslib_submod = False
    nslib_name = normalize_module_name(attr.name)
    ns_prefixes = []
    ns_prefixes.extend(settings["@ocaml//ns:prefixes"])
    ns_submodules = settings["@ocaml//ns:submodules"]

    ## convert submodules label list to module name list
    attr_submodules = []
    attr_submodule_labels = []
    for submod_label in attr.submodules:
        submod = normalize_module_name(submod_label.name)
        attr_submodules.append(submod)
        attr_submodule_labels.append(str(submod_label))

    nslib_module = capitalize_initial_char(nslib_name)
    if len(ns_prefixes) == 0 and ns_submodules == []:
        ## new ns lib
        ns_prefixes.append(nslib_module)
        ns_submodules = attr_submodules
    elif nslib_module in ns_submodules:
        ## this is an ns lib submodule of a parent nslib
        ns_prefixes.append(nslib_module)
    elif nslib_module not in ns_prefixes:
        # not a submodule - params are inherited from remote ns lib
        ns_prefixes.append(nslib_module)
    # else:
        ## this is an ns lib submodule of a parent nslib
        ## no changes to ConfigState

    if debug:
        print(" setting ConfigState:")
        print("  @ocaml//ns:prefixes: %s" % ns_prefixes)
        print("  @ocaml//ns:submodules: %s" % attr_submodule_labels)

    return {
        "@ocaml//ns:prefixes": ns_prefixes,
        "@ocaml//ns:submodules": attr_submodule_labels,
    }

################################################################
## ocaml_nslib transistions

################
def _ocaml_nslib_main_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_main_out_transition", settings, attr)

ocaml_nslib_main_out_transition = transition(
    implementation = _ocaml_nslib_main_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

################
def _ocaml_nslib_submodules_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_submodules_out_transition", settings, attr)

ocaml_nslib_submodules_out_transition = transition(
    implementation = _ocaml_nslib_submodules_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

################
def _ocaml_nslib_ns_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_ns_out_transition", settings, attr)

ocaml_nslib_ns_out_transition = transition(
    implementation = _ocaml_nslib_ns_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

##############################################################
def _ocaml_module_cc_deps_out_transition_impl(settings, attr):

    debug = False
    if attr.name == "":
        debug = True
        print(">>> ocaml_module_ns_transition")
        print_config_state(settings, attr)

    return {
        "@ocaml//ns:prefixes"    : [],
        "@ocaml//ns:submodules": []
    }

################
ocaml_module_cc_deps_out_transition = transition(
    implementation = _ocaml_module_cc_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)
