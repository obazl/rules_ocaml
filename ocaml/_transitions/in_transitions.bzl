load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlSignatureProvider",
     "OcamlNsResolverProvider")

load("//ocaml/_functions:utils.bzl", "capitalize_initial_char")

load("//ocaml/_functions:module_naming.bzl",
     "derive_module_name_from_file_name",
     "label_to_module_name",
     "normalize_module_label",
     "normalize_module_name")

load("//ocaml/_rules:impl_common.bzl", "module_sep")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCCYN", "CCRESET",
     "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH"
     )

#######################################
def print_config_state(settings, attr):

    print("CONFIG State:")
    print("kind: %s" % attr._rule)
    print("nm: %s" % attr.name)
    print("{c}{n} attrs:{r}".format(
        c=CCYEL,n=attr.name,r=CCRESET))
    if hasattr(attr, "ns"):
        print("attr.ns: %s" % attr.ns)
    if hasattr(attr, "submodules"):
        print("attr.manifest: %s" % attr.manifest)

    print("pfxs: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    print("submods: %s" % settings["@rules_ocaml//cfg/ns:submodules"])

    print("/CONFIG State")

    # for d in dir(attr):
    #     print(" %s" % d)

    # if hasattr(attr, "_ns_resolver"):
    #     print("{c}hidden nsr:{r}".format(c=CCYEL,r=CCRESET))
    #     print(" nsr: %s" % attr._ns_resolver)
    #     print(" %s" % settings[str(attr._ns_resolver)])
    #     fail("xxxx")
        # for d in attr._ns_resolver[OcamlNsResolverProvider]:
        #     print(" %s" % d)
        # print("nsr ws: %s" % attr._ns_resolver.workspace_name)

    print("{c}settings:{r}".format(c=CCCYN,r=CCRESET))
    for item in settings.items():
        print("{k}: {v}".format(k=item[0],v=item[1]))

    # print("{c}settings:{r}".format(c=CCYEL,r=CCRESET))
    # print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    # print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])


##################################################
def _executable_in_transition_impl(transition, settings, attr):
    debug = False

    if debug:
        print("")
        print("{c}>>> {t}{r}".format(
            c=CCYELBGH,r=CCRESET,t=transition))
        print_config_state(settings, attr)
        print("{c}attrs:{r}".format(c=CCYEL,r=CCRESET))
        # for a in attr:
        print("  %s" % attr)

    if debug:
        print("nslib in OUT STATE:")
        print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])


    return {
        "@rules_ocaml//cfg/ns:prefixes"   : [],
        "@rules_ocaml//cfg/ns:submodules" : [],
    }

#######################################################
def _ppx_executable_in_transition_impl(settings, attr):
    return _executable_in_transition_impl("ppx_executable_in_transition", settings, attr)

ppx_executable_in_transition = transition(
    implementation = _ppx_executable_in_transition_impl,
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

#######################################################
def _ocaml_executable_in_transition_impl(settings, attr):
    return _executable_in_transition_impl("ocaml_executable_in_transition", settings, attr)

ocaml_executable_in_transition = transition(
    implementation = _ocaml_executable_in_transition_impl,
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

##############################################
    # if this-nslib in ns:submodules list
    #     pass on prefix but not ns:submodules
    # else
    #     set config from this's attributes

def _nslib_in_transition_impl(settings, attr):
    # print("_nslib_in_transition_impl %s" % attr.name)
    debug = False
    # if attr.name in ["ppx_optcomp_light"]:
    #     debug = True

    if debug:
        print("")
        print("{c}>>> nslib_in_transition{r}".format(
            c=CCYELBG,r=CCRESET))
        print_config_state(settings, attr)

        # print("{c}attrs:{r}".format(c=CCBLU,r=CCRESET))
        # print("  %s" % attr)

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
    for submod_label in attr.manifest:
        submod = normalize_module_name(submod_label.name)
        attr_submodules.append(submod)
        attr_submodule_labels.append(str(submod_label))

    nslib_module = capitalize_initial_char(nslib_name) # not needed?

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if nslib_name in settings["@rules_ocaml//cfg/ns:prefixes"]:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif nslib_name in submodules:
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        # reset to default values
        # prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        # submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        prefixes   = []
        submodules = []

    if debug:
        print("nslib in OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    return {
        "@rules_ocaml//cfg/ns:nonce"   : attr.name,
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
    }

###################
nslib_in_transition = transition(
    implementation = _nslib_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:nonce",
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
        # "@rules_ocaml//cfg/ns:prefixes",
        # "@rules_ocaml//cfg/ns:submodules",
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)

###############################################
def _module_in_transition_impl(settings, attr):
    debug = False

    # if attr.name in ["Source_map_io"]:
    #     # debug = True
    #     print("_module_in_transition_impl")
    #     print("target:{c}{t}{r}".format(c=CCRED,t=attr.name,r=CCRESET))

    if debug:
        print("{c}>>> module_in_transition{r}".format(
            c=CCYELBG,r=CCRESET))
        print_config_state(settings, attr)

    module = None

    ## NB: select() not yet resolved???

    # 1. derive this module name w/o ns prefix

    if hasattr(attr, "sig"):
        if debug: print("SIG: %s" % attr.sig)
        if attr.module:
            module = attr.module[:1].capitalize() + attr.module[1:]
        else:
            ## FIXME: label_to_module_name?
            module = attr.name[:1].capitalize() + attr.name[1:]
    else: ## singleton, no sig attribute
        if attr.module:
            ## must be a legal ocaml module name, so we can just upcase the first char
            module = attr.module[:1].capitalize() + attr.module[1:]
        else:
            if debug:
                print("{c} struct:{r} {m}".format(c=CCBLU,r=CCRESET,m=attr.struct))
            ## FIXME: label_to_module_name?
            (bn, ext) = paths.split_extension(attr.struct.name)
            module = bn[:1].capitalize() + bn[1:]

    if debug:
        print("{c} this module:{r} {m}".format(c=CCBLU,r=CCRESET,m=module))

    submodules = []
    ## derive module names from manifest labels. note that we only have labels to work with, not targets and so not file names.
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        # quasi-normalize. basenames of labels in ns:submodules may not be legal module names.
        # submodule = normalize_module_label(submodule_label)
        submodule = label_to_module_name(submodule_label)
        submodules.append(submodule)
    if debug: print("normalized submodules: %s" % submodules)

    ## FIXME: we derive a module name from label name, or from module attrib.
    ## but then we need to see if it is in the manifest.
    ## but manifest entries are just labels, which have no necessary
    ## connection to filename or module name.

    ## the rule must be: derive module names from manifest labels by stripping illegal chars,
    ## then test for module name inclusion

    ## the grammar for module names (https://v2.ocaml.org/manual/names.html):
    ## module-name       ::=	capitalized-ident
    ## capitalized-ident ::=	 (A…Z) { letter ∣ 0…9 ∣ _ ∣ ' } 

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
    if debug:
        print("IN STATE:")
        print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print("OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

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

