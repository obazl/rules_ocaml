load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:structs.bzl", "structs")

load("//build/_lib:utils.bzl", "capitalize_initial_char")
load("//build/_lib:module_naming.bzl",
     "normalize_module_label",
     "normalize_module_name")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCMAGBG", "CCCYN", "CCRESET",
     "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH",
     "CCWHTBG"
     )

XDEBUG = False

#######################################
def print_config_state(settings, attr):
    print("CONFIG State:")
    print("kind: %s" % attr._rule)
    print("nm: %s" % attr.name)
    print("{c}{n} attrs:{r}".format(
        c=CCYEL,n=attr.name,r=CCRESET))
    if hasattr(attr, "ns"):
        print("attr.ns: %s" % attr.ns)
    if hasattr(attr, "manifest"):
        print("attr.manifest: %s" % attr.manifest)
    if hasattr(attr, "resolver"):
        print("  attr.resolver: %s" % attr.resolver)

    if "@rules_ocaml//cfg/ns:prefixes" in settings:
        print("@rules_ocaml//cfg/ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])

    if "@rules_ocaml//cfg/ns:submodules" in settings:
        print("@rules_ocaml//cfg/ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
    print("/CONFIG State")

################################################################
# nslib out transition: sets the following, all string lists:
##  @rules_ocaml//cfg/ns:submodules
##  @rules_ocaml//cfg/ns:prefixes
##  @rules_ocaml//cfg/ns:manifest
## WARNING: lib manifest target labels may not match module names.
## This will happen when a submodule uses the 'module_name' attr.
## or when a precompiled sig dep forces a module name.
## So submod names must be derived accordingly.
def _ocaml_nslib_out_transition_impl(transition, settings, attr):
    # print("_ocaml_nslib_out_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["greek"]:
    #     debug = True

    if debug:
        print("")
        print("{c}>>> {t}{r}".format(
            c=CCWHTBG,t=transition,r=CCRESET))
        # print(">>> " + transition)
        print("attr.name: %s" % attr.name)
        print("attr.ns_name: %s" % attr.ns_name)
        print("attr.manifest: %s" % attr.manifest)
        print("attr.aliases: %s" % attr.aliases)
        print_config_state(settings, attr)
        # print("submodules: %s" % attr.manifest)
        # for submod in attr.manifest:
        #     print("submod: %s" % submod)

    # if attr.name == "libGreek":
    #     fail()

    if hasattr(attr, "ns_name"):
        if attr.ns_name:
            nslib_name = normalize_module_name(attr.ns_name)
        else:
            nslib_name = normalize_module_name(attr.name)
    else:
        nslib_name = normalize_module_name(attr.name)
    if debug: print("nslib_name: %s" % nslib_name)
    # ns attribute overrides default derived from rule name
    if hasattr(attr, "ns"):
        if attr.ns:
            nslib_name = normalize_module_name(attr.ns)
            if debug: print("nslib_name, overridden by ns attrib: %s" % nslib_name)

    ns_prefixes = []
    ns_prefixes.extend(settings["@rules_ocaml//cfg/ns:prefixes"])
    if debug: print("nslib prefixes: %s" % ns_prefixes)
    ns_submodules = settings["@rules_ocaml//cfg/ns:submodules"]

    ## convert submodules label list to module name list
    attr_submodules = []
    attr_submodule_labels = []

    ## submodules is a label list of targets, but since the targets
    ## have not yet been built the vals are labels not targets
    for submod_label in attr.manifest:
        submod = normalize_module_name(submod_label.name)
        attr_submodules.append(submod)
        attr_submodule_labels.append(str(submod_label))
    if debug: print("attr_submodules: %s" % attr_submodules)

    nslib_module = capitalize_initial_char(nslib_name) # not needed?
    if debug: print("nslib_module: %s" % nslib_module)

    if len(ns_prefixes) == 0 and ns_submodules == []:
        # print("X 1")
        ## this is a toplevel nslib, not a descendant of another nslib
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
        # "@rules_ocaml//cfg/manifest": attr_submodule_labels,
    }

################################################################
## ocaml_nslib transistions

################
def _ocaml_nslib_main_out_transition_impl(settings, attr):
    if XDEBUG:
        print("_ocaml_nslib_main_out_transition_impl %s" % attr.name)
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
        # "@rules_ocaml//cfg/manifest"
    ]
)

################
def _ocaml_nslib_submodules_out_transition_impl(settings, attr):
    if XDEBUG:
        print("{color}_ocaml_nslib_submodules_out_transition_impl{reset}: {s}".format(
        color=CCRED, reset=CCRESET, s = attr.name))

    ## NB: not affected by user-defined resolver in attr.resolver
    return _ocaml_nslib_out_transition_impl("ocaml_nslib_submodules_out_transition", settings, attr)

ocaml_nslib_submodules_out_transition = transition(
    implementation = _ocaml_nslib_submodules_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        # "@rules_ocaml//cfg/manifest",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

################
## called on HIDDEN nslib._ns_resolver
def _ocaml_nslib_resolver_out_transition_impl(settings, attr):
    if XDEBUG:
        print("{c}_ocaml_nslib_resolver_out_transition_impl{r}: {s}".format(
            c=CCRED, r = CCRESET, s = attr.name))

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
        # "@rules_ocaml//cfg/manifest"
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
#     for submod_label in attr.manifest:
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
    if XDEBUG:
        print("_ocaml_nslib_ns_out_transition_impl %s" % attr.name)
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
        # "@rules_ocaml//cfg/manifest"
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

#####################################################
def _ocaml_binary_deps_out_transition_impl(settings, attr):
    print(">>> OCAML_EXECUTABLE_DEPS_OUT_TRANSITION: %s" % attr.name)

    # if attr.mode:
    #     mode = attr.mode
    # else:
    #     mode = settings["@rules_ocaml//cfg/mode:mode"]

    return {
        "@rules_ocaml//cfg/xmo": True,
    }

################
ocaml_binary_deps_out_transition = transition(
    implementation = _ocaml_binary_deps_out_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/xmo"
    ],
    outputs = [
        "@rules_ocaml//cfg/xmo"
    ]
)

#####################################################
def _ocaml_module_deps_out_transition_impl(settings, attr):
    # print("_ocaml_module_deps_out_transition_impl %s" % attr.name)
    debug = False
    # if attr.name == "_Grammar":
    #     debug = True

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
def _ocaml_signature_deps_out_transition_impl(settings, attr):
    # print("_ocaml_signature_deps_out_transition_impl %s" % attr.name)
    debug = False # True
    # if attr.name == "":
    #     debug = True

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

###########################################################
# def _manifest_out_transition_impl(settings, attr):
#     debug = False
#     # if attr.name == ":_Plexing.cmi":
#     #     debug = True

#     if debug:
#         print(">>> manifest_out_transition")
#         print_config_state(settings, attr)

#     manifest = [str(lbl) for lbl in attr.manifest]
#     return {
#         "@rules_ocaml//cfg/manifest"  : manifest
#     }

# ################
# manifest_out_transition = transition(
#     implementation = _manifest_out_transition_impl,
#     inputs = [],
#     outputs = [
#         "@rules_ocaml//cfg/manifest",
#     ]
# )

###########################################################
## cc_deps out transition: reset config to initial state
## so cc_* targets will only be built once.
def _cc_deps_out_transition_impl(settings, attr):
    debug = False

    if debug:
        print(">>> cc_deps_out_transition")
        # print_config_state(settings, attr)

    return {
        "//command_line_option:compilation_mode": "opt",
        # "//command_line_option:host_platform": "",
        # "//command_line_option:platforms": [],
        # "@rules_ocaml//cfg/runtime": "std",
    }

################
cc_deps_out_transition = transition(
    implementation = _cc_deps_out_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:compilation_mode",
        # "//command_line_option:host_platform",
        # "//command_line_option:platforms",
        # "@rules_ocaml//cfg/runtime",
    ]
)

