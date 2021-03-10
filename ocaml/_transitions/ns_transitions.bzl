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
    # print("  ns:trace: %s" % settings["@ocaml//ns:trace"])
    # print("  ns_resolver ws: %s" % attr._ns_resolver.workspace_name)
    print("  ns:prefix: %s" % settings["@ocaml//ns:prefix"])
    print("  ns:submodules: %s" % settings["@ocaml//ns:submodules"])
    if hasattr(attr, "submodules"):
        print("  attr.submodules: %s" % attr.submodules)

##############################################
def _nslib_in_transition_impl(settings, attr):
    return {
        "@ocaml//ns:prefix"        : "",
        "@ocaml//ns:submodules": [],
        # "@ppx//ns:prefix"          : "",
        # "@ppx//ns:submodules"  : []
    }

###################
nslib_in_transition = transition(
    ## """Reset ConfigState for both @ocaml and @ppx.""",
    implementation = _nslib_in_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ppx//ns:prefix",
        # "@ppx//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ppx//ns:prefix",
        # "@ppx//ns:submodules",
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

    nslib_name = attr.name
    ns_prefix = settings["@ocaml//ns:prefix"]
    ns_submodules = settings["@ocaml//ns:submodules"]
    ns_sublibs = settings["@ocaml//ns:sublibs"]

    ## convert submodules label list to module name list
    attr_submodules = []
    attr_submodule_labels = []
    for submod_label in attr.submodules:
        submod = normalize_module_name(submod_label.name)
        attr_submodules.append(submod)
        attr_submodule_labels.append(str(submod_label))
    # attr_submodules = attr.submodules

    attr_sublibs = []
    for sublib_label in attr.sublibs:
        sublib = normalize_module_name(sublib_label.name)
        attr_sublibs.append(sublib)
    if debug:
        print("SUBLIBS: %s" % attr_sublibs)

    if ns_prefix == "" and ns_submodules == []:
        ## new ns lib
        ns_prefix     = capitalize_initial_char(nslib_name)
        ns_submodules = attr_submodules
    # elif ns_prefix == "":
    #     ns_prefix = nslib_name
    elif capitalize_initial_char(nslib_name) in ns_submodules:
        ## this is an ns lib submodule of a parent nslib
        ns_prefix   = capitalize_initial_char(ns_prefix) + "__" + capitalize_initial_char(nslib_name)
        # ns_prefix   = nslib_name
    elif capitalize_initial_char(nslib_name) in attr_submodules: ## ns_submodules:
        ## this is an ns lib listed as one of its own submodules
        ## remove from submodule list?
        ns_prefix     = nslib_name
    # else: # not a submodule - params are inherited from remote ns lib

    # if attr.main:
    #     ns_resolver = capitalize_initial_char(nslib_name) + "__0Resolver"
    # elif capitalize_initial_char(nslib_name) in ns_submodules:
    #     ## this is an ns lib serving as a submodule
    # else:
    #     resolver = capitalize_initial_char(nslib_name)

    if debug:
        print(" setting ConfigState:")
        print("  @ocaml//ns:prefix: %s" % ns_prefix)
        print("  @ocaml//ns:submodules: %s" % attr_submodule_labels)
        print("  @ocaml//ns:sublibs: %s" % attr_sublibs)
        # print("  @ocaml//ns:trace: %s" % trace)

    return {
        "@ocaml//ns:prefix": ns_prefix,
        "@ocaml//ns:submodules": attr_submodule_labels,
        "@ocaml//ns:sublibs": attr_sublibs,
        # "@ocaml//ns:trace": trace
    }

################################################################
## ocaml_nslib transistions

################
def _ocaml_nslib_main_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_main_out_transition", settings, attr)

ocaml_nslib_main_out_transition = transition(
    implementation = _ocaml_nslib_main_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
    ]
)

################
def _ocaml_nslib_submodules_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_submodules_out_transition", settings, attr)

ocaml_nslib_submodules_out_transition = transition(
    implementation = _ocaml_nslib_submodules_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
    ]
)

################
def _ocaml_nslib_ns_out_transition_impl(settings, attr):
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_ns_out_transition", settings, attr)

ocaml_nslib_ns_out_transition = transition(
    implementation = _ocaml_nslib_ns_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs"
        # "@ocaml//ns:trace",
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
        # "@ocaml//ns:pkg": settings["@ocaml//ns:pkg"],
        "@ocaml//ns:prefix"        : "",
        "@ocaml//ns:submodules": []
    }

################
ocaml_module_cc_deps_out_transition = transition(
    implementation = _ocaml_module_cc_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ocaml//ns:trace"
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
    ]
)

################################################################
