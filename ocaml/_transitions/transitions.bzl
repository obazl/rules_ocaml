load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_label")

#######################################
def print_config_state(settings, attr):

    print("  rule name: %s" % attr.name)
    print("  ns_resolver ws: %s" % attr._ns_resolver.workspace_name)
    print("  @ocaml//ns:prefixes: %s" % settings["@ocaml//ns:prefixes"])
    print("  @ocaml//ns:submodules: %s" % settings["@ocaml//ns:submodules"])
    if hasattr(attr, "submodules"):
        print("  attr.submodules: %s" % attr.submodules)

##################################################
def _executable_in_transition_impl(settings, attr):
    ## FIXME: ppx_executable uses @ppx//mode to set @ocaml//mode
    return {
        "@ocaml//mode"          : settings["@ocaml//mode:mode"],
        "@ppx//mode"            : settings["@ocaml//mode:mode"],
        "@ocaml//ns:prefixes"   : [],
        "@ocaml//ns:submodules" : [],
    }

#######################
executable_in_transition = transition(
    implementation = _executable_in_transition_impl,
    inputs = [
        "@ocaml//mode:mode",
        "@ppx//mode:mode",
    ],
    outputs = [
        "@ocaml//mode",
        "@ppx//mode",
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

#####################################################
def _ocaml_executable_deps_out_transition_impl(settings, attr):
    # print(">>> OCAML_EXECUTABLE_DEPS_OUT_TRANSITION: %s" % attr.name)

    if attr.mode:
        mode = attr.mode
    else:
        mode = settings["@ocaml//mode:mode"]

    return {
        "@ppx//mode": mode,
        "@ocaml//ns:prefixes": [],
        "@ocaml//ns:submodules": []
    }

################
ocaml_executable_deps_out_transition = transition(
    implementation = _ocaml_executable_deps_out_transition_impl,
    inputs = [
        "@ocaml//mode:mode",
    ],
    outputs = [
        "@ppx//mode",
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules"
    ]
)

################################################################
def _module_in_transition_impl(settings, attr):

    debug = False
    # if attr.name in ["_Main"]:
    #     debug = True

    if debug:
        print(">>> ocaml_module_in_transition")
        print_config_state(settings, attr)

    module = None
    ## if struct uses select() it will not be resolved yet, so we need to test
    if hasattr(attr, "struct"):
        structfile = attr.struct.name
        (basename, ext) = paths.split_extension(structfile)
        module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in settings["@ocaml//ns:prefixes"]:
        prefixes     = settings["@ocaml//ns:prefixes"]
        submodules = settings["@ocaml//ns:submodules"]
    elif module in submodules:
        prefixes     = settings["@ocaml//ns:prefixes"]
        submodules = settings["@ocaml//ns:submodules"]
    else:
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefixes"   : prefixes,
        "@ocaml//ns:submodules" : submodules,
    }


####################
module_in_transition = transition(
    implementation = _module_in_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

#####################################################
def _ocaml_module_deps_out_transition_impl(settings, attr):

    debug = False
    if attr.name == "":
        debug = True

    if debug:
        print(">>> ocaml_module_deps_out_transition")
        print_config_state(settings, attr)

    srcfile = attr.struct.name if hasattr(attr, "struct") else attr.src.name
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        ## this is an nslib submodule; we need to propagate configstate set by nslib,
        ## in case we depend on a sibling.
        # print("OUT_T mod: %s" % module)
        # print("OUT_T pfx: %s" % settings["@ocaml//ns:prefixes"])
        # if module == settings["@ocaml//ns:prefixes"][-1]:
        prefixes   = settings["@ocaml//ns:prefixes"]
        submodules = settings["@ocaml//ns:submodules"]
    else:
        ## we're not in an nslib context
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefixes"        : prefixes,
        "@ocaml//ns:submodules": submodules
    }

#####################
ocaml_module_deps_out_transition = transition(
    implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

###########################################################
def _ocaml_signature_deps_out_transition_impl(settings, attr):

    debug = False
    if attr.name == "":
        debug = True
        print(">>> ocaml_signature_deps_out_transition")
        print_config_state(settings, attr)

    srcfile = attr.src.name
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        prefixes     = settings["@ocaml//ns:prefixes"]
        submodules = settings["@ocaml//ns:submodules"]
    else:
        prefix     = ""
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefixes"      : prefixes,
        "@ocaml//ns:submodules": submodules
    }

################
ocaml_signature_deps_out_transition = transition(
    # implementation = _ocaml_signature_deps_out_transition_impl,
    implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ],
    outputs = [
        "@ocaml//ns:prefixes",
        "@ocaml//ns:submodules",
    ]
)

##############################################
def _ppx_mode_transition_impl(settings, attr):
    ppx_mode_val = settings["@ppx//mode:mode"]
    return {
        "@ocaml//mode": ppx_mode_val,
    }

ppx_mode_transition = transition(
    implementation = _ppx_mode_transition_impl,
    inputs = [
        "@ppx//mode:mode",
    ],
    outputs = [
        "@ocaml//mode",
    ]
)
