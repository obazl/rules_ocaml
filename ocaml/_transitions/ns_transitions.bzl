load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl", "capitalize_initial_char")
load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_label",
     "normalize_module_name")

load("//ocaml/_debug:colors.bzl", "CCRED", "CCMAG", "CCRESET")

#######################################
def print_config_state(settings, attr):
    print("CONFIG State:")
    print("  rule name: %s" % attr.name)
    # print("  rule x: %s" % attr.transitive_configsx)
    if hasattr(attr, "resolver"):
        print("  attr.resolver: %s" % attr.resolver)
    # print("  ns: %s" % settings["@"])
    print("  ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    print("  ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
    print("/CONFIG State")

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

################################################################
def _ocaml_nslib_out_transition_impl(transition, settings, attr):
    # print("_ocaml_nslib_out_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["greek"]:
    #     debug = True

    if debug:
        print("")
        print(">>> " + transition)
        print("attr.name: %s" % attr.name)
        # print_config_state(settings, attr)
        # print("attr: %s" % attr)
        print("submodules: %s" % attr.submodules)
        for submod in attr.submodules:
            print("submod: %s" % submod)

    nslib_name = normalize_module_name(attr.name)
    # ns attribute overrides default derived from rule name
    if hasattr(attr, "ns"):
        if attr.ns:
            nslib_name = normalize_module_name(attr.ns)

    ns_prefixes = []
    ns_prefixes.extend(settings["@rules_ocaml//cfg/ns:prefixes"])
    if debug: print("ns_prefixes: %s" % ns_prefixes)
    ns_submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    if debug: print("ns_submodules: %s" % ns_submodules)

    ## convert submodules label list to module name list
    attr_submodules = []
    attr_submodule_labels = []

    ## submodules is a label list of targets, but since the targets
    ## have not yet been build the vals are labels not targets
    for submod_label in attr.submodules:
        submod = normalize_module_name(submod_label.name)
        attr_submodules.append(submod)
        attr_submodule_labels.append(str(submod_label))

    nslib_module = capitalize_initial_char(nslib_name)
    if len(ns_prefixes) == 0 and ns_submodules == []:
        # print("X 1")
        ## this is a toplevelnslib, not a descendant of another nslib
        ns_prefixes.append(nslib_module)
        ns_submodules = attr_submodules
    elif nslib_module in ns_submodules:
        # print("X 2")
        ## this is nslib is a submodule of a parent nslib
        ns_prefixes.append(nslib_module)
    elif nslib_module not in ns_prefixes:
        # print("X 3")
        # this is a descendant of another nslib, but it is not a
        # submodule; e.g. child of a submodule
        # - params are inherited from remote ns lib
        ns_prefixes.append(nslib_module)
    # else:
        ## this is an ns lib submodule of a parent nslib
        ## no changes to ConfigState

    # user-defined resolver in attr.resolver overrides ns name
    if hasattr(attr, "resolver"):
        ns_name = capitalize_initial_char(attr.resolver.name)
        print("RESOLVER name: %s" % ns_name)
        ns_prefixes = [ns_name]

    if debug:
        print(" setting ConfigState:")
        print("  @rules_ocaml//cfg/ns:prefixes: %s" % ns_prefixes)
        print("  @rules_ocaml//cfg/ns:submodules: %s" % attr_submodule_labels)

    return {
        "@rules_ocaml//cfg/ns:prefixes": ns_prefixes,
        "@rules_ocaml//cfg/ns:submodules": attr_submodule_labels,
    }

################################################################
## ocaml_nslib transistions

################
def _ocaml_nslib_main_out_transition_impl(settings, attr):
    # print("_ocaml_nslib_main_out_transition_impl %s" % attr.name)
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_main_out_transition", settings, attr)

ocaml_nslib_main_out_transition = transition(
    implementation = _ocaml_nslib_main_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################
def _ocaml_nslib_submodules_out_transition_impl(settings, attr):
    # print("{color}_ocaml_nslib_submodules_out_transition_impl{reset}: {s}".format(
    #     color=CCRED, reset=CCRESET, s = attr.name))

    ## NB: not affected by user-defined resolver in attr.resolver
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_submodules_out_transition", settings, attr)

ocaml_nslib_submodules_out_transition = transition(
    implementation = _ocaml_nslib_submodules_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        # "@rules_ocaml//cfg/ns:name",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################
## called on HIDDEN nslib._ns_resolver
def _ocaml_nslib_resolver_out_transition_impl(settings, attr):
    # print("{c}_ocaml_nslib_resolver_out_transition_impl{r}: {s}".format(
    #     c=CCRED, r = CCRESET, s = attr.name))

    ## if user explicitly provides 'resolver' attrib then cancel this;
    ## renaming of submodules not affected.
    # if attr.resolver:
    #     print("{c}user-defined resolver:{r}: {s}".format(
    #         c=CCMAG, r=CCRESET, s=attr.resolver))
    #     return {
    #         "@rules_ocaml//cfg/ns:name": attr.resolver.name,
    #         "@rules_ocaml//cfg/ns:prefixes": [],
    #         "@rules_ocaml//cfg/ns:submodules": [],
    #     }
    # else:
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_resolver_out_transition", settings, attr)

####
ocaml_nslib_resolver_out_transition = transition(
    implementation = _ocaml_nslib_resolver_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        # "@rules_ocaml//cfg/ns:name",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################################################################

# ################
# def _bootstrap_nslib_submodules_out_transition_impl(settings, attr):
#     print("_bootstrap_nslib_submodules_out_transition_impl %s" % attr.name)

#     debug = False
#     if debug:
#         print("")
#         print(">>> bootstrap_nslib_submodules_out_transition_impl")
#         if attr.resolver:
#             print("user-provided resolver: %s" % attr.resolver)
#         print_config_state(settings, attr)

#     # if attr.name.startswith("#"):
#     #     nslib_submod = True
#     # else:
#     #     nslib_submod = False

#     nslib_name = normalize_module_name(attr.name)
#     if attr.ns:
#         nslib_name = normalize_module_name(attr.ns)
#     ns_prefixes = []
#     ns_prefixes.extend(settings["@rules_ocaml//cfg/ns:prefixes"])
#     ns_submodules = settings["@rules_ocaml//cfg/ns:submodules"]

#     # print("nslib_name: %s" % nslib_name)

#     ## convert submodules label list to module name list
#     attr_submodules = []
#     attr_submodule_labels = []

#     ## submodules is a label list of targets, but since the targets
#     ## have not yet been built the vals are labels not targets
#     for submod_label in attr.submodules:
#         submod = normalize_module_name(submod_label.name)
#         attr_submodules.append(submod)
#         attr_submodule_labels.append(str(submod_label))

#     nslib_module = capitalize_initial_char(nslib_name)
#     if len(ns_prefixes) == 0 and ns_submodules == []:
#         ## this is a toplevelnslib, not a descendant of another nslib
#         ns_prefixes.append(nslib_module)
#         ns_submodules = attr_submodules
#     elif nslib_module in ns_submodules:
#         ## this is nslib is a submodule of a parent nslib
#         ns_prefixes.append(nslib_module)
#     elif nslib_module not in ns_prefixes:
#         # this is a descendant of another nslib, but it is not a
#         # submodule; e.g. child of a submodule
#         # - params are inherited from remote ns lib
#         ns_prefixes.append(nslib_module)
#     # else:
#         ## this is an ns lib submodule of a parent nslib
#         ## no changes to ConfigState

#     if debug:
#         print(" setting ConfigState:")
#         print("  @rules_ocaml//cfg/ns:prefixes: %s" % ns_prefixes)
#         print("  @rules_ocaml//cfg/ns:submodules: %s" % attr_submodule_labels)

#     if attr.resolver:
#         resolver = attr.resolver
#     else:
#         resolver = settings["@rules_ocaml//cfg/bootstrap/ns:resolver"]

#     return {
#         "@rules_ocaml//cfg/bootstrap/ns:resolver": resolver,
#         "@rules_ocaml//cfg/ns:prefixes": ns_prefixes,
#         "@rules_ocaml//cfg/ns:submodules": attr_submodule_labels,
#     }

#########################################
# bootstrap_nslib_submodules_out_transition = transition(
#     implementation = _bootstrap_nslib_submodules_out_transition_impl,
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

################
def _ocaml_nslib_ns_out_transition_impl(settings, attr):
    # print("_ocaml_nslib_ns_out_transition_impl %s" % attr.name)
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_ns_out_transition", settings, attr)

ocaml_nslib_ns_out_transition = transition(
    implementation = _ocaml_nslib_ns_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

##############################################################
def _ocaml_module_cc_deps_out_transition_impl(settings, attr):
    # we do not want to do this - build cc deps in same ns as depender?
    debug = False
    if attr.name == "":
        debug = False
        print(">>> ocaml_module_ns_transition")
        print_config_state(settings, attr)

    return {
        "@rules_ocaml//cfg/ns:prefixes"    : [],
        "@rules_ocaml//cfg/ns:submodules": []
    }

################
ocaml_module_cc_deps_out_transition = transition(
    implementation = _ocaml_module_cc_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)
