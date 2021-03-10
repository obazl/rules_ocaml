load("@bazel_skylib//lib:paths.bzl", "paths")
# load("@bazel_skylib//lib:structs.bzl", "structs")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_label")

#######################################
def print_config_state(settings, attr):

    print("  rule name: %s" % attr.name)
    # print("  ns:trace: %s" % settings["@ocaml//ns:trace"])
    print("  ns_resolver ws: %s" % attr._ns_resolver.workspace_name)
    print("  @ocaml//ns:prefix: %s" % settings["@ocaml//ns:prefix"])
    print("  @ocaml//ns:submodules: %s" % settings["@ocaml//ns:submodules"])
    if hasattr(attr, "submodules"):
        print("  attr.submodules: %s" % attr.submodules)
    print("  @ocaml//ns:sublibs: %s" % settings["@ocaml//ns:sublibs"])

##################################################
def _executable_in_transition_impl(settings, attr):
    # if attr.mode:
    #     mode = attr.mode
    # else:
    mode = settings["@ocaml//mode:mode"]

    return {
        # "@ppx//mode"            : mode,
        "@ocaml//mode"          : mode,
        "@ocaml//ns:prefix"         : "",
        "@ocaml//ns:submodules" : [],
        # "@ppx//ns:prefix"           : "",
        # "@ppx//ns:submodules"   : []
    }

#######################
executable_in_transition = transition(
    implementation = _executable_in_transition_impl,
    inputs = [
        "@ocaml//mode:mode",
    ],
    outputs = [
        # "@ppx//mode",
        "@ocaml//mode",
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ppx//ns:prefix",
        # "@ppx//ns:submodules"
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
        "@ocaml//ns:prefix": "",
        "@ocaml//ns:submodules": []
    }

ocaml_executable_deps_out_transition = transition(
    implementation = _ocaml_executable_deps_out_transition_impl,
    inputs = [
        "@ocaml//mode:mode",
    ],
    outputs = [
        "@ppx//mode",
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules"
    ]
)

################################################################
def _module_in_transition_impl(settings, attr):

    debug = False
    # if attr.name in ["_Red"]:
    #     debug = True

    if debug:
        print(">>> ocaml_module_in_transition")
        print_config_state(settings, attr)

    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    # if hasattr(attr, "pkg"):
    #     if attr.pkg == None:
    #         pkg = ""
    #     else:
    #         print("PKG: %s" % attr.pkg.package)
    #         pkg = attr.pkg.package
    # else:
    #     pkg = ""

    # scenario: Color.Red depends on Color.Green
    # Green will be transitioned twice, once by Color (ns lib), once by Color.Red (module).
    # In the former but not the latter case it should reset config state.

    ## if struct uses select() it will not be resolved yet
    module = None
    if hasattr(attr, "struct"):
        structfile = attr.struct.name
        # print("STRUCTFILE: %s" % structfile)
        (basename, ext) = paths.split_extension(structfile)
        module = capitalize_initial_char(basename)
        # print("MODULE: %s" % module)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        # print("SUBMODULE_LABEL: %s" % submodule_label)
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        # if module == settings["@ocaml//ns:prefix"]:
        #     ## this is a user-compiled main module, also listed as a submodule
        #     prefix     = ""
        #     submodules = []
        # else:
            prefix     = settings["@ocaml//ns:prefix"]
            submodules = settings["@ocaml//ns:submodules"]
            sublibs = settings["@ocaml//ns:sublibs"]
            # trace      = settings["@ocaml//ns:trace"]
    else:
        prefix     = ""
        submodules = []
        sublibs = []
        # trace      = ""

    if debug:
        print("OUT STATE:")
        print("  ns:prefix: %s" % prefix)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefix"     : prefix,
        "@ocaml//ns:submodules" : submodules,
        "@ocaml//ns:sublibs"    : sublibs,
        # "@ocaml//ns:trace"     : trace
    }

    # return {
    #     "@ocaml//ns:prefix": "", # attr.name,
    #     "@ocaml//ns:submodules": []
    # }

module_in_transition = transition(
    implementation = _module_in_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs",
        # "@ocaml//ns:trace"
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        "@ocaml//ns:sublibs",
        # "@ocaml//ns:trace"
    ]
)

#####################################################
def _ocaml_module_deps_out_transition_impl(settings, attr):

    debug = False
    if attr.name == "":
        debug = True
        print(">>> ocaml_module_deps_out_transition")
        print_config_state(settings, attr)

    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    if hasattr(attr, "pkg"):
        if attr.pkg == None:
            pkg = ""
        else:
            print("PKG: %s" % attr.pkg.package)
            pkg = attr.pkg.package
    else:
        pkg = ""

    # scenario: Color.Red depends on Color.Green
    # Green will be transitioned twice, once by Color (ns lib), once by Color.Red (module).
    # In the former but not the latter case it should reset config state.

    structfile = attr.struct.name
    # print("STRUCTFILE: %s" % structfile)
    (basename, ext) = paths.split_extension(structfile)
    module = capitalize_initial_char(basename)
    # print("MODULE: %s" % module)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        # print("SUBMODULE_LABEL: %s" % submodule_label)
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        prefix     = settings["@ocaml//ns:prefix"]
        submodules = settings["@ocaml//ns:submodules"]
    else:
        prefix     = ""
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefix: %s" % prefix)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefix"        : prefix,
        "@ocaml//ns:submodules": submodules
    }

#####################
ocaml_module_deps_out_transition = transition(
    implementation = _ocaml_module_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ocaml//ns:trace"
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ocaml//ns:trace"
    ]
)


###########################################################
def _ocaml_signature_deps_out_transition_impl(settings, attr):

    debug = False
    if attr.name == "":
        debug = True
        print(">>> ocaml_signature_deps_out_transition")
        print_config_state(settings, attr)

    # attrs = structs.to_dict(attr)
    # for k in sorted(attrs.keys()):
    #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

    if hasattr(attr, "pkg"):
        if attr.pkg == None:
            pkg = ""
        else:
            print("PKG: %s" % attr.pkg.package)
            pkg = attr.pkg.package
    else:
        pkg = ""

    # scenario: Color.Red depends on Color.Green
    # Green will be transitioned twice, once by Color (ns lib), once by Color.Red (module).
    # In the former but not the latter case it should reset config state.

    srcfile = attr.src.name
    # print("SRCFILE: %s" % srcfile)
    (basename, ext) = paths.split_extension(srcfile)
    module = capitalize_initial_char(basename)
    # print("MODULE: %s" % module)

    submodules = []
    for submodule_label in settings["@ocaml//ns:submodules"]:
        print("SUBMODULE_LABEL: %s" % submodule_label)
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if module in submodules:
        prefix     = settings["@ocaml//ns:prefix"]
        submodules = settings["@ocaml//ns:submodules"]
    else:
        prefix     = ""
        submodules = []

    if debug:
        print("OUT STATE:")
        print("  ns:prefix: %s" % prefix)
        print("  ns:submodules: %s" % submodules)

    return {
        "@ocaml//ns:prefix"        : prefix,
        "@ocaml//ns:submodules": submodules
    }

ocaml_signature_deps_out_transition = transition(
    implementation = _ocaml_signature_deps_out_transition_impl,
    inputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ocaml//ns:trace"
    ],
    outputs = [
        "@ocaml//ns:prefix",
        "@ocaml//ns:submodules",
        # "@ocaml//ns:trace"
    ]
)

# ##############################################
# def _ocaml_module_deps_out_transition_impl(settings, attr):
#     print(">>> OCAML_MODULE_DEPS_OUT_TRANSITION: %s" % attr.name)
#     return {
#         "@ppx//mode": settings["@ocaml//mode:mode"]
#     }

# ocaml_module_deps_out_transition = transition(
#     implementation = _ocaml_module_deps_out_transition_impl,
#     inputs  = ["@ocaml//mode:mode"],
#     outputs = ["@ppx//mode"]
# )

################################################
# def _ocaml_test_deps_out_transition_impl(settings, attr):
#     ocaml_mode_val = settings["@ocaml//mode:mode"]
#     # ppx_mode_val = settings["@ppx//mode:mode"]

#     # print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
#     # print("OCAML_TEST_DEPS_OUT_TRANSITION_IN: ocaml mode = {ocaml}, ppx mode = {ppx}".format( #, ocaml = {ocaml}
#     #     ocaml = ocaml_mode_val, ppx = ppx_mode_val
#     # ))
#     # attrs = structs.to_dict(attr)
#     # for k in sorted(attrs.keys()):
#     #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

#     return {
#         "@ocaml//mode": ocaml_mode_val,
#         "@ppx//mode": ocaml_mode_val
#     }

# ocaml_test_deps_out_transition = transition(
#     implementation = _ocaml_test_deps_out_transition_impl,
#     inputs = ["@ocaml//mode:mode"], # "@ppx//mode:mode"],
#     outputs = [
#         "@ocaml//mode",
#         "@ppx//mode"
#     ]  #, "@ocaml//mode"]
# )

################################################################
# def _ocaml_mode_transition_out_impl(settings, attr):

#     print("")
#     print("TRANSITION: ocaml_mode")

#     ocaml_mode_val = settings["@ocaml//mode:mode"]
#     # ppx_mode_val = settings["@ppx//mode:mode"]

#     # print("////////////////////////////////////////////////////////////////")
#     # print("OCAML_MODE_TRANSITION_OUT: ocaml mode = {ocaml}, ppx mode = {ppx}".format( #, ocaml = {ocaml}
#     #     ocaml = ocaml_mode_val, ppx = ppx_mode_val
#     # ))
#     # attrs = structs.to_dict(attr)
#     # for k in sorted(attrs.keys()):
#     #     print("ATTR: {k} = {v}".format(k = k, v = attrs[k]))

#     return {
#         "@ocaml//mode": ocaml_mode_val,
#         "@ppx//mode": ocaml_mode_val,
#     }

# ocaml_mode_transition_out = transition(
#     implementation = _ocaml_mode_transition_out_impl,
#     inputs = ["@ocaml//mode:mode"], #, "@ppx//mode:mode"],
#     outputs = [
#         "@ocaml//mode",
#         "@ppx//mode"
#     ]
# )

##############################################
def _ppx_mode_transition_impl(settings, attr):
    ppx_mode_val = settings["@ppx//mode:mode"]
    return {
        "@ocaml//mode": ppx_mode_val,
        # "@ppx//ns:prefix": ""
    }

ppx_mode_transition = transition(
    implementation = _ppx_mode_transition_impl,
    inputs = [
        "@ppx//mode:mode",
        # "@ppx//ns:prefix"
    ],
    outputs = [
        "@ocaml//mode",
        # "@ppx//ns:prefix"
    ]
)
