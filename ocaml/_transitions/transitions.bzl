load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl", "capitalize_initial_char")
load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_label",
     "normalize_module_name")

load("//ocaml/_rules:impl_common.bzl", "module_sep")

#######################################
def print_config_state(settings, attr):

    print("  rule name: %s" % attr.name)
    print("  ns_resolver ws: %s" % attr._ns_resolver.workspace_name)
    print("  @rules_ocaml//cfg/ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    print("  @rules_ocaml//cfg/ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
    if hasattr(attr, "submodules"):
        print("  attr.submodules: %s" % attr.submodules)

##################################################
def _executable_in_transition_impl(settings, attr):
    ## FIXME: ppx_executable uses @ppx//mode to set @rules_ocaml//cfg/mode
    return {
        # "@rules_ocaml//cfg/mode"          : settings["@rules_ocaml//cfg/mode:mode"],
        # "@ppx//mode"            : settings["@rules_ocaml//cfg/mode:mode"], ## Why?
        "@rules_ocaml//cfg/ns:prefixes"   : ["foo"],
        "@rules_ocaml//cfg/ns:submodules" : [],
    }

#######################
executable_in_transition = transition(
    implementation = _executable_in_transition_impl,
    inputs = [
        # "@rules_ocaml//cfg/mode:mode",
        # "@ppx//mode:mode",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        # "@rules_ocaml//cfg/mode",
        # "@ppx//mode",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

#####################################################
def _ocaml_executable_deps_out_transition_impl(settings, attr):
    print(">>> OCAML_EXECUTABLE_DEPS_OUT_TRANSITION: %s" % attr.name)

    # if attr.mode:
    #     mode = attr.mode
    # else:
    #     mode = settings["@rules_ocaml//cfg/mode:mode"]

    return {
        "@rules_ocaml//cfg/xmo": True,
    }

################
ocaml_executable_deps_out_transition = transition(
    implementation = _ocaml_executable_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/xmo"
    ],
    outputs = [
        "@rules_ocaml//cfg/xmo"
    ]
)

################################################################
def _module_in_transition_impl(settings, attr):
    # print("_module_in_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["_Util"]:
    #     debug = True

    if debug:
        print(">>> ocaml_module_in_transition")
        print_config_state(settings, attr)

    module = None
    ## if struct uses select() it will not be resolved yet, so we need to test
    if hasattr(attr, "struct"):
        if attr.struct:
            structfile = attr.struct.name
            (basename, ext) = paths.split_extension(structfile)
            module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        # reset to default values
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
    }


####################
module_in_transition = transition(
    implementation = _module_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################################################################
################################################################
################################################################
## we need to reset submods list to null on inbound txn so that each
## module will only be built one. Example: half-diamond dep, where X
## is a dep of both a namespaced module and a non-namespaced module,
## and X itself is non-namespaced. we need X to have the same config
## state in all cases so it is only built once.
def _bootstrap_module_in_transition_impl(settings, attr):
    # print("_bootstrap_module_in_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["Stdlib", "Stdlib_cmi", "Uchar"]:
    #     debug = True

    if debug:
        print(">>> bootstrap_ocaml_module_in_transition")
        print_config_state(settings, attr)
        print(" resolver: %s" % settings["@rules_ocaml//cfg/bootstrap/ns:resolver"])
        print("  t: %s" % type(settings["@rules_ocaml//cfg/bootstrap/ns:resolver"]))

    module = None
    ## if struct uses select() it will not be resolved yet, so we need to test
    if hasattr(attr, "struct"):
        if attr.struct:
            structfile = attr.struct.name
            (basename, ext) = paths.split_extension(structfile)
            module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    ## We decide whether or not this module is namespaced, and whether
    ## it needs to be renamed.

    if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
        # true if this module is user-provided resolver?
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        # reset to default values
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    if prefixes:
        # no change
        resolver = settings["@rules_ocaml//cfg/bootstrap/ns:resolver"]
    else:
        # reset to default
        resolver = Label("@rules_ocaml//cfg/bootstrap/ns:ns_bootstrap")

    return {
        "@rules_ocaml//cfg/bootstrap/ns:resolver": resolver,
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
    }

##############################
bootstrap_module_in_transition = transition(
    implementation = _bootstrap_module_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/bootstrap/ns:resolver",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/bootstrap/ns:resolver",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

##############################################
    # if this nslib in ns:submodules list
    #     pass on prefix but not ns:submodules
    # else
    #     reset ConfigState

def _nslib_in_transition_impl(settings, attr):
    # print("_nslib_in_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["color"]:
    #     debug = True

    if debug:
        print("")
        print(">>> nslib_in_transition")
        print_config_state(settings, attr)
        print(attr)

    module = normalize_module_name(attr.name)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        # reset to default values
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
    }

###################
nslib_in_transition = transition(
    implementation = _nslib_in_transition_impl,
    inputs = [
        # "@rules_ocaml//cfg/ns:transitivity",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

#####################################################
def _ocaml_module_deps_out_transition_impl(settings, attr):
    # print("_ocaml_module_deps_out_transition_impl %s" % attr.name)
    debug = False
    if attr.name == "_Grammar":
        debug = True

    if debug:
        print(">>> ocaml_module_deps_out_transition")
        print_config_state(settings, attr)

    srcfile = attr.struct.name if hasattr(attr, "struct") else attr.src.name
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        ## this is an nslib submodule; we need to propagate
        ## configstate set by nslib, in case we depend on a sibling.
        # print("OUT_T mod: %s" % module)
        # print("OUT_T pfx: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        # if module == settings["@rules_ocaml//cfg/ns:prefixes"][-1]:
        prefixes   = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        ## we're not in an nslib context; reset to defaults
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"  : prefixes,
        "@rules_ocaml//cfg/ns:submodules": submodules
    }

#####################
ocaml_module_deps_out_transition = transition(
    implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

#####################
ocaml_module_sig_out_transition = transition(
    implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################################################################
################################################################

################################################################
def _subsignature_in_transition_impl(settings, attr):
    # print("_subsignature_in_transition_impl %s" % attr.name)
    debug = False
    if attr.name in ["_Feedback"]:
        debug = True

    if debug:
        print(">>> ocaml_subsignature_in_transition")
        print_config_state(settings, attr)

    module = None
    ## if struct uses select() it will not be resolved yet, so we need to test
    if hasattr(attr, "struct"):
        structfile = attr.struct.name
        (basename, ext) = paths.split_extension(structfile)
        module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
    }


####################
subsignature_in_transition = transition(
    implementation = _subsignature_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################################################################
def _ocaml_signature_deps_out_transition_impl(settings, attr):
    # print("_ocaml_signature_deps_out_transition_impl %s" % attr.name)
    debug = False # True
    if attr.name == "":
        debug = True

    if debug:
        print(">>> ocaml_signature_deps_out_transition")
        print_config_state(settings, attr)

    srcfile = attr.src.name
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        prefix     = ""
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"      : prefixes,
        "@rules_ocaml//cfg/ns:submodules": submodules
    }

################
ocaml_signature_deps_out_transition = transition(
    implementation = _ocaml_signature_deps_out_transition_impl,
    # implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

###########################################################
def _ocaml_subsignature_deps_out_transition_impl(settings, attr):
    # print("_ocaml_subsignature_deps_out_transition_impl %s" % attr.name)
    debug = False
    # if attr.name == ":_Plexing.cmi":
    #     debug = True

    if debug:
        print(">>> ocaml_subsignature_deps_out_transition")
        print_config_state(settings, attr)

    srcfile = attr.src.name
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        prefixes   = []
        submodules = []

    if attr.name == "_Plexing.cmi":
        prefixes   = []
        submodules = []

    if debug:
        print("OUT STATE: %s" % attr.name)
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:prefixes"  : prefixes,
        "@rules_ocaml//cfg/ns:submodules": submodules
    }

################
ocaml_subsignature_deps_out_transition = transition(
    implementation = _ocaml_subsignature_deps_out_transition_impl,
    # implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

##############################################
def _reset_in_transition_impl(settings, attr):
    return {
        "@rules_ocaml//cfg/ns:prefixes"   : [],
        "@rules_ocaml//cfg/ns:submodules" : [],
    }

reset_in_transition = transition(
    implementation = _reset_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

##############################################
def _ppx_mode_transition_impl(settings, attr):
    ppx_mode_val = settings["@ppx//mode:mode"]
    return {
        "@rules_ocaml//cfg/mode": ppx_mode_val,
    }

ppx_mode_transition = transition(
    implementation = _ppx_mode_transition_impl,
    inputs = [
        "@ppx//mode:mode",
    ],
    outputs = [
        "@rules_ocaml//cfg/mode",
    ]
)
