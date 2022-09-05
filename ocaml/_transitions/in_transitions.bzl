load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml:providers.bzl",
     "OcamlSignatureProvider")

load("//ocaml/_functions:utils.bzl", "capitalize_initial_char")

load("//ocaml/_functions:module_naming.bzl",
     "derive_module_name",
     "normalize_module_label",
     "normalize_module_name")

load("//ocaml/_rules:impl_common.bzl", "module_sep")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCCYAN", "CCRESET")

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

################################################################
def _module_in_transition_impl(settings, attr):
    debug = False

    # if attr.name in ["Source_map_io"]:
    #     # debug = True
    #     print("_module_in_transition_impl")
    #     print("target:{c}{t}{r}".format(c=CCRED,t=attr.name,r=CCRESET))

    if debug:
        print(">>> ocaml_module_in_transition")
        print_config_state(settings, attr)

    module = None

    ## NB: select() not yet resolved???

    # 1. derive this module name w/o ns prefix

    if attr.sig:
        if debug: print("SIG: %s" % attr.sig)
        if attr.module:
            module = attr.module[:1].capitalize() + attr.module[1:]
        else:
            module = attr.name[:1].capitalize() + attr.name[1:]
    else: ## singleton, no sig attribute
        if attr.module:
            module = attr.module[:1].capitalize() + attr.module[1:]
        else:
            if debug:
                print("{c} struct:{r} {m}".format(c=CCBLU,r=CCRESET,m=attr.struct))
            (bn, ext) = paths.split_extension(attr.struct.name)
            module = bn[:1].capitalize() + bn[1:]

    if debug:
        print("{c} this module:{r} {m}".format(c=CCBLU,r=CCRESET,m=module))

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

    # if prefixes == []:
    #     print("\n\n{c}NULL PFXS: {n}{r}  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n".format(
    #         c=CCRED,r=CCRESET,n=attr.name))
    # # if debug:
    #     print("IN STATE:")
    #     print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    #     print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
    #     print("OUT STATE:")
    #     print("  ns:prefixes: %s" % prefixes)
    #     print("  ns:submodules: %s" % submodules)

        # fail("xxxxxxxxxxxxxxxx")

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
# ## we need to reset submods list to null on inbound txn so that each
# ## module will only be built one. Example: half-diamond dep, where X
# ## is a dep of both a namespaced module and a non-namespaced module,
# ## and X itself is non-namespaced. we need X to have the same config
# ## state in all cases so it is only built once.
# def _bootstrap_module_in_transition_impl(settings, attr):
#     # print("_bootstrap_module_in_transition_impl %s" % attr.name)
#     debug = False
#     # if attr.name in ["Stdlib", "Stdlib_cmi", "Uchar"]:
#     #     debug = True

#     if debug:
#         print(">>> bootstrap_ocaml_module_in_transition")
#         print_config_state(settings, attr)
#         print(" resolver: %s" % settings["@rules_ocaml//cfg/bootstrap/ns:resolver"])
#         print("  t: %s" % type(settings["@rules_ocaml//cfg/bootstrap/ns:resolver"]))

#     module = None
#     ## if struct uses select() it will not be resolved yet, so we need to test
#     if hasattr(attr, "struct"):
#         if attr.struct:
#             structfile = attr.struct.name
#             (basename, ext) = paths.split_extension(structfile)
#             module = capitalize_initial_char(basename)

#     submodules = []
#     for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
#         submodule = normalize_module_label(submodule_label)
#         submodules.append(submodule)

#     ## We decide whether or not this module is namespaced, and whether
#     ## it needs to be renamed.

#     if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
#         # true if this module is user-provided resolver?
#         prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
#         submodules = settings["@rules_ocaml//cfg/ns:submodules"]
#     elif module in submodules:
#         prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
#         submodules = settings["@rules_ocaml//cfg/ns:submodules"]
#     else:
#         # reset to default values
#         prefixes   = []
#         submodules = []

#     if debug:
#         print("OUT STATE:")
#         print("  ns:prefixes: %s" % prefixes)
#         print("  ns:submodules: %s" % submodules)

#     if prefixes:
#         # no change
#         resolver = settings["@rules_ocaml//cfg/bootstrap/ns:resolver"]
#     else:
#         # reset to default
#         resolver = Label("@rules_ocaml//cfg/bootstrap/ns:ns_bootstrap")

#     return {
#         "@rules_ocaml//cfg/bootstrap/ns:resolver": resolver,
#         "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
#         "@rules_ocaml//cfg/ns:submodules" : submodules,
#     }

# ##############################
# bootstrap_module_in_transition = transition(
#     implementation = _bootstrap_module_in_transition_impl,
#     inputs = [
#         "@rules_ocaml//cfg/bootstrap/ns:resolver",
#         "@rules_ocaml//cfg/ns:prefixes",
#         "@rules_ocaml//cfg/ns:submodules",
#     ],
#     outputs = [
#         "@rules_ocaml//cfg/bootstrap/ns:resolver",
#         "@rules_ocaml//cfg/ns:prefixes",
#         "@rules_ocaml//cfg/ns:submodules",
#     ]
# )

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

################################################################
################################################################

################################################################
def _subsignature_in_transition_impl(settings, attr):
    # print("_subsignature_in_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["_Feedback"]:
    #     debug = True

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

##############################################
def _nsarchive_in_transition_impl(settings, attr):
    debug = False
    # if attr.name in ["tezos-protocol-compiler"]:
    #     debug = True

    if debug:
        print("")
        print(">>> nsarchive_in_transition")
        # if not settings["@rules_ocaml//cfg/ns:prefixes"]:
        print_config_state(settings, attr)
        if hasattr(attr, "submodules"):
            print("  attr.submodules: %s" % attr.submodules)
        print("ATTRS:")
        print(attr)

    # # if this in ns:submodules
    # #     pass on prefix but not ns:submodules
    # # else
    # #     reset ConfigState

    # pfx = ""
    # prefixes = []

    # if settings["@rules_ocaml//cfg/ns:transitivity"]:
    #     prefixes.extend(settings["@rules_ocaml//cfg/ns:prefixes"])
    #     for submod_lbl in settings["@rules_ocaml//cfg/ns:submodules"]:
    #         if attr.name == Label(submod_lbl).name:
    #             prefixes.append(normalize_module_name(attr.name))
    #             break

    return {
        # "@rules_ocaml//cfg/ns:prefixes"  : [],
        "@rules_ocaml//cfg/ns:prefixes"  : [],
        "@rules_ocaml//cfg/ns:submodules": [],
    }

###################
##FIXME: rename to ns_in_transition, it applies to all rule types
nsarchive_in_transition = transition(
    ## """Reset ConfigState for ocaml_ns_archive, ocaml_archive.""",
    implementation = _nsarchive_in_transition_impl,
    inputs = [
        # "@rules_ocaml//cfg/ns:resolver",  ##FIXME not available for executable
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)
