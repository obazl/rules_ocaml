load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//build:providers.bzl",
     "OCamlModuleProvider",
     "OCamlSignatureProvider",
     "OCamlNsResolverProvider")

load("//build/_lib:module_naming.bzl",
     "derive_module_name_from_file_name",
     "label_to_module_name",
     "normalize_module_label",
     "normalize_module_name")

load("//build/_lib:utils.bzl", "module_sep")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCCYN", "CCRESET",
     "CCYEL", "CCUYEL", "CCYELBG", "CCYELBGH"
     )

##################################################
def executable_in_transition_impl(transition, settings, attr):
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


    # host, tgt = _get_tc(settings)
    # if host == None:
    #     return {
    #         "@rules_ocaml//cfg/ns:prefixes"   : [],
    #         "@rules_ocaml//cfg/ns:submodules" : [],
    #         # "//command_line_option:host_platform": settings[
    #         #     "//command_line_option:host_platform"],
    #         # "//command_line_option:platforms": settings[
    #         #     "//command_line_option:platforms"]
    #     }
    # else:
    # return {
    #     "@rules_ocaml//cfg/ns:prefixes"   : [],
    #     "@rules_ocaml//cfg/ns:submodules" : [],
    #     # "//command_line_option:host_platform": host,
    #     # "//command_line_option:platforms": tgt
    # }

    build_host  = settings["//command_line_option:host_platform"]
    target_host = settings["//command_line_option:platforms"]
    tc = settings["@rules_ocaml//toolchain"]
    # print("\nppx: %s" % attr.name)
    # print("\nTC: %s" % tc)
    # print("\nBUILDHOST: %s" % build_host)
    # print("\nTARGETHOST: %s" % target_host)

    if tc == "nop":
        host = build_host
        tgt  = target_host
    else:
        if  Label(build_host) == Label("@@bazel_tools//tools:host_platform"):
            if Label(build_host) == target_host[0]:
                host, tgt = get_tc(settings, attr)
            else:
                # ?
                host, tgt = get_tc(settings, attr)
        elif Label(build_host) == target_host[0]:
            if build_host.name == "ocamlc.opt":
                # set sys>vm => vm>vm
                host = build_host
                # tgt  = ["@rules_ocaml//platform:vm>any"]
                tgt  = ["@rules_ocaml//platform:ocamlc.byte"]
            elif build_host.name == "ocamlopt.byte":
                # set vm>sys => sys>sys
                host = build_host
                # tgt  = ["@rules_ocaml//platform:sys>any"]
                tgt  = ["@rules_ocaml//platform:ocamlopt.opt"]
            else:
                host = build_host
                tgt  = target_host
        else:
            host, tgt = get_tc(settings, attr)
    # fail("HOST {}, TGT {}".format(host, tgt))

    # return configs.update({
    #     "@rules_ocaml//toolchain": "ocamlopt"
    # })
    # if host != None:
    # host = "@rules_ocaml//platform:ocamlopt.opt"
    # tgt  = "@rules_ocaml//platform:ocamlopt.opt"
    # why nop?
    configs = {
        "@rules_ocaml//toolchain" : tc, # "nop", # "ocamlopt",
        "//command_line_option:host_platform": host,
        "//command_line_option:platforms": tgt
    }
    # print("CONFIGS: %s" % configs)
    return configs

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
        # for d in attr._ns_resolver[OCamlNsResolverProvider]:
        #     print(" %s" % d)
        # print("nsr ws: %s" % attr._ns_resolver.workspace_name)

    print("{c}settings:{r}".format(c=CCCYN,r=CCRESET))
    for item in settings.items():
        print("{k}: {v}".format(k=item[0],v=item[1]))

    # print("{c}settings:{r}".format(c=CCYEL,r=CCRESET))
    # print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
    # print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])


################
# Purpose: set host_platform and platforms based on
# @rules_ocaml//toolchain
def get_tc(settings, attr):
    build_host  = settings["//command_line_option:host_platform"]
    target_host = settings["//command_line_option:platforms"]
    tc = settings["@rules_ocaml//toolchain"]

    # print("target: %s" % attr.name)
    # print("INBH %s" % build_host)
    # print("INTH %s" % target_host)
    # print("INTC %s" % tc)

    if build_host.name == tc:
        if target_host[0].name == tc:
            # endo-compiler, no change
            return build_host, target_host
        else:
            ## exo-compiler, target should already be set
            return build_host, target_host
    else:
        # print("Transition from %s to %s" % (
        #     build_host.name, tc))
        if tc == "nop":
            host = build_host
            tgt  = target_host
        elif tc == "ocamlopt":
            host = "@rules_ocaml//platform:ocamlopt.opt"
            tgt  = "@rules_ocaml//platform:ocamlopt.opt"
        elif tc == "ocamlopt.opt":
            host = "@rules_ocaml//platform:ocamlopt.opt"
            tgt  = "@rules_ocaml//platform:ocamlopt.opt"
        elif  tc == "ocamlc":
            host = "@rules_ocaml//platform:ocamlc.opt"
            tgt  = "@rules_ocaml//platform:ocamlc.byte"
        elif  tc == "ocamlc.byte":
            host = "@rules_ocaml//platform:ocamlc.byte"
            tgt  = "@rules_ocaml//platform:ocamlc.byte"
        elif  tc == "ocamlc.opt":
            host = "@rules_ocaml//platform:ocamlc.opt"
            # ocaml_imports select archive based on
            # //platform:emitter, which defaults to sys
            # this means the target emitter, since by
            # default build targets are built for the
            # target platform.

            # (which means ocaml_import *should* select
            # on build emitter)

            # since vm>any does not set //platform:emitter,
            # using it as target platform means the default
            # sys will be used, which is not what we need.
            # we need to override the default emitter
            # to match
            tgt  = "@rules_ocaml//platform:vm>any"
            # tgt  = "@rules_ocaml//platform:ocamlc.byte"
            # or vm>sys
            # tgt  = "@rules_ocaml//platform:ocamlopt.byte"
        elif  tc == "ocamlopt.byte":
            host = "@rules_ocaml//platform:ocamlopt.byte"
            # but when build emitter is sys, the default
            # will work so we can use sys>any
            tgt  = "@rules_ocaml//platform:sys>any"
            # tgt  = "@rules_ocaml//platform:ocamlopt.opt"
            # or
            # tgt  = "@rules_ocaml//platform:ocamlc.opt"
        else:
            fail("""

Unrecognized toolchain: {}
Available toolchains: ocamlopt, ocamlc, ocamlopt.opt, ocamlc.byte, ocamlopt.byte, ocamlc.opt
            """.format(tc))

        return host, tgt

##############################################
    # if this-nslib in ns:submodules list
    #     pass on prefix but not ns:submodules
    # else
    #     set config from this's attributes

def _nslib_in_transition_impl(settings, attr):
    debug = False
    # if attr.name in ["alcotest_stdlib_ext"]:
    #     debug = True

    if debug:
        print("")
        print("{c}>>> nslib_in_transition{r}".format(
            c=CCYELBG,r=CCRESET))
        print("attr.name: %s" % attr.name)
        print("ns prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("ns submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print("attr.manifest: %s" % attr.manifest)
        # print_config_state(settings, attr)

        # print("{c}attrs:{r}".format(c=CCBLU,r=CCRESET))
        # print("  %s" % attr)

    # tc = settings["@rules_ocaml//toolchain"]

    if settings["@rules_ocaml//cfg/ns:submodules"] == []:
        if debug: print("null submodules: resetting config")
        # print("nonce: %s" % settings["@rules_ocaml//cfg/ns:nonce"])
        # print("pfxs:  %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        # print("submodules:  %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        # return {}
        # print("LIBTC: %s" % tc)
        # if tc == "nop":
        #     host = None
        # else:
        #     host, tgt = get_tc(settings, attr)
        # fail("HOST {}, TGT {}".format(host, tgt))

        prefixes = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # if host == None:
        #     # print("%s %s NULL TC TRANSITION" % (attr._rule,attr.name))
        #     return {
        #         "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        #         "@rules_ocaml//cfg/ns:submodules" : submodules,
        #         # "//command_line_option:host_platform": settings[
        #         #     "//command_line_option:host_platform"],
        #         # "//command_line_option:platforms": settings[
        #         #     "//command_line_option:platforms"]
        #     }
        # else:
        #     # print("%s %s TC TRANSITION" % (attr._rule, attr.name))
        #     return {
        #         "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        #         "@rules_ocaml//cfg/ns:submodules" : submodules,
        #         # "//command_line_option:host_platform": host,
        #         # "//command_line_option:platforms": tgt
        #     }

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

    nslib_module = nslib_name[:1].capitalize() + nslib_name[1:]

    submodules = []
    for submodule_label in settings["@rules_ocaml//cfg/ns:submodules"]:
        submodule = normalize_module_label(submodule_label)
        submodules.append(submodule)

    if nslib_name in settings["@rules_ocaml//cfg/ns:prefixes"]:
        # nonce = attr.name
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    elif nslib_name in submodules:
        # nonce = attr.name
        prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
    else:
        # reset to default values
        # prefixes     = settings["@rules_ocaml//cfg/ns:prefixes"]
        # submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # nonce      = ""
        prefixes   = []
        submodules = []

    if debug:
        print("nslib in OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

    tc = settings["@rules_ocaml//toolchain"]
    if tc == "nop":
        host = None
    else:
        host, tgt = get_tc(settings, attr)
    # fail("HOST {}, TGT {}".format(host, tgt))

    if host == None:
        # print("%s %s NULL TC TRANSITION" % (attr._rule,attr.name))
        return {
            "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
            "@rules_ocaml//cfg/ns:submodules" : submodules,
            "//command_line_option:host_platform": settings[
                "//command_line_option:host_platform"],
            "//command_line_option:platforms": settings[
                "//command_line_option:platforms"]
        }
    else:
        # print("%s %s TC TRANSITION" % (attr._rule, attr.name))
        return {
            "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
            "@rules_ocaml//cfg/ns:submodules" : submodules,
            "//command_line_option:host_platform": host,
            "//command_line_option:platforms": tgt
        }


    # return {
    #     # "@rules_ocaml//cfg/ns:nonce"      : nonce,
    #     "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
    #     "@rules_ocaml//cfg/ns:submodules" : submodules,
    # }

###################
nslib_in_transition = transition(
    implementation = _nslib_in_transition_impl,
    inputs = [
        # "@rules_ocaml//cfg/ns:nonce",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
    ],
    outputs = [
        # "@rules_ocaml//cfg/ns:nonce",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        # "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
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
## module_in_transition
## called once per ocaml_module
## Checks for an ns submodules manifest
## If found, checks to see if "this" module is in the submodules list.
## If it is, adds ns prefix to this module name.
## Checks to see if this module is in prefix list

##  - The prefix list is for "chained" namespaces, e.g. when on ns lib
##  - contains another ns lib. Then the submodules in the latter will
##  - be named with both prefixes, e.g. A__B__C, not B__C.

## If this module not in prefix list and not in submodules list,
## then reset:
##     "@rules_ocaml//cfg/ns:prefixes",
##     "@rules_ocaml//cfg/ns:submodules",

def _module_in_transition_impl(settings, attr):
    debug = False

    if debug:
        print("{c}>>> module_in_transition{r}".format(
            c=CCYELBG,r=CCRESET))
        print("module: %s" % attr.name)
        print("prefixes cfg: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("submodules cfg: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print_config_state(settings, attr)


    module = None

    ## NB: select() not yet resolved???

    # 1. derive this module name w/o ns prefix

    if hasattr(attr, "sig"):
    # if attr.sig:
        if debug: print("SIG: %s" % attr.sig)
        if attr.module_name:
            module = attr.module_name[:1].capitalize() + attr.module_name[1:]
        else:
            ## FIXME: label_to_module_name?
            module = attr.name[:1].capitalize() + attr.name[1:]
    else: ## singleton, no sig attribute
        if attr.module_name:
            ## must be a legal ocaml module name, so we can just upcase the first char
            module = attr.module_name[:1].capitalize() + attr.module_name[1:]
        else:
            if debug:
                print("{c} struct:{r} {m}".format(c=CCBLU,r=CCRESET,m=attr.struct))
            ## FIXME: label_to_module_name?
            if hasattr(attr, "struct"): # ocaml_module
                (bn, ext) = paths.split_extension(attr.struct.name)
                module = bn[:1].capitalize() + bn[1:]
            elif hasattr(attr, "src"): # ocaml_signature
                (bn, ext) = paths.split_extension(attr.src.name)
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
        prefixes   = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # manifest   = settings["@rules_ocaml//cfg/manifest"]
    elif module in submodules:
        prefixes   = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # manifest   = settings["@rules_ocaml//cfg/manifest"]
    else:
        # reset to default values
        prefixes   = []
        submodules = []
        # manifest   = []

    # if prefixes == []:
    #     print("\n\n{c}NULL PFXS: {n}{r}  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n".format(
    #         c=CCRED,r=CCRESET,n=attr.name))
    if debug:
        print("module IN STATE:")
        print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print("module OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

        # fail("xxxxxxxxxxxxxxxx")

    # print("module: %s" % attr.name)
    # build_host  = settings["//command_line_option:host_platform"]
    # print("BH: %s" % build_host)
    # target_host = settings["//command_line_option:platforms"]
    # print("TH: %s" % target_host)

    tc = settings["@rules_ocaml//toolchain"]
    # print("TC: %s" % tc)
    if tc == "nop":
        host = None
    else:
        host, tgt = get_tc(settings, attr)
    # fail("HOST {}, TGT {}".format(host, tgt))

    if host == None:
        # print("%s %s NULL TC TRANSITION" % (attr._rule,attr.name))
        return {
            "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
            "@rules_ocaml//cfg/ns:submodules" : submodules,
            "//command_line_option:host_platform": settings[
                "//command_line_option:host_platform"],
            "//command_line_option:platforms": settings[
                "//command_line_option:platforms"]
        }
    else:
        # print("%s %s TC TRANSITION" % (attr._rule, attr.name))
        return {
            "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
            "@rules_ocaml//cfg/ns:submodules" : submodules,
            "//command_line_option:host_platform": host,
            "//command_line_option:platforms": tgt
        }

####################
module_in_transition = transition(
    implementation = _module_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ]
)

################################
def _sig_in_transition_impl(settings, attr):
    debug = False

    if debug:
        print("{c}>>> sig_in_transition{r}".format(
            c=CCYELBG,r=CCRESET))
        print("module: %s" % attr.name)
        print("prefixes cfg: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("submodules cfg: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print_config_state(settings, attr)


    module = None

    ## NB: select() not yet resolved???

    # 1. derive this module name w/o ns prefix

    if hasattr(attr, "sig"):
    # if attr.sig:
        if debug: print("SIG: %s" % attr.sig)
        if attr.module_name:
            module = attr.module_name[:1].capitalize() + attr.module_name[1:]
        else:
            ## FIXME: label_to_module_name?
            module = attr.name[:1].capitalize() + attr.name[1:]
    else: ## singleton, no sig attribute
        if attr.module_name:
            ## must be a legal ocaml module name, so we can just upcase the first char
            module = attr.module_name[:1].capitalize() + attr.module_name[1:]
        else:
            if debug:
                print("{c} struct:{r} {m}".format(c=CCBLU,r=CCRESET,m=attr.struct))
            ## FIXME: label_to_module_name?
            if hasattr(attr, "struct"): # ocaml_module
                (bn, ext) = paths.split_extension(attr.struct.name)
                module = bn[:1].capitalize() + bn[1:]
            elif hasattr(attr, "src"): # ocaml_signature
                (bn, ext) = paths.split_extension(attr.src.name)
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

    ## NB: this is topdown-ns stuff:
    if module in settings["@rules_ocaml//cfg/ns:prefixes"]:
        prefixes   = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # manifest   = settings["@rules_ocaml//cfg/manifest"]
    elif module in submodules:
        prefixes   = settings["@rules_ocaml//cfg/ns:prefixes"]
        submodules = settings["@rules_ocaml//cfg/ns:submodules"]
        # manifest   = settings["@rules_ocaml//cfg/manifest"]
    else:
        # reset to default values
        prefixes   = []
        submodules = []
        # manifest   = []

    # if prefixes == []:
    #     print("\n\n{c}NULL PFXS: {n}{r}  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n".format(
    #         c=CCRED,r=CCRESET,n=attr.name))
    if debug:
        print("module IN STATE:")
        print("ns:prefixes: %s" % settings["@rules_ocaml//cfg/ns:prefixes"])
        print("ns:submodules: %s" % settings["@rules_ocaml//cfg/ns:submodules"])
        print("module OUT STATE:")
        print("  ns:prefixes: %s" % prefixes)
        print("  ns:submodules: %s" % submodules)

        # fail("xxxxxxxxxxxxxxxx")

    # print("module: %s" % attr.name)
    # build_host  = settings["//command_line_option:host_platform"]
    # print("BH: %s" % build_host)
    # target_host = settings["//command_line_option:platforms"]
    # print("TH: %s" % target_host)

    # tc = settings["@rules_ocaml//toolchain"]
    # # print("TC: %s" % tc)
    # if tc == "nop":
    #     host = None
    # else:
    #     host, tgt = get_tc(settings, attr)
    # fail("HOST {}, TGT {}".format(host, tgt))

    # if host == None:
    #     # print("%s %s NULL TC TRANSITION" % (attr._rule,attr.name))
    #     return {
    #         "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
    #         "@rules_ocaml//cfg/ns:submodules" : submodules,
    #         "//command_line_option:host_platform": settings[
    #             "//command_line_option:host_platform"],
    #         "//command_line_option:platforms": settings[
    #             "//command_line_option:platforms"]
    #     }
    # else:
    #     # print("%s %s TC TRANSITION" % (attr._rule, attr.name))
    #     return {
    #         "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
    #         "@rules_ocaml//cfg/ns:submodules" : submodules,
    #         "//command_line_option:host_platform": host,
    #         "//command_line_option:platforms": tgt
    #     }

    host = "@rules_ocaml//platform:ocamlopt.opt"
    tgt  = "@rules_ocaml//platform:ocamlopt.opt"
    tc   = "ocamlopt"
    # if settings["@rules_ocaml//cfg/library/linkage:level"] > 0:
    linklevel = 1
    linkage = "static"

    return {
        "@rules_ocaml//cfg/ns:prefixes"   : prefixes,
        "@rules_ocaml//cfg/ns:submodules" : submodules,
        "@rules_ocaml//cfg/library/linkage:linkage" : linkage,
        "@rules_ocaml//cfg/library/linkage:level" : linklevel,
        "@rules_ocaml//toolchain": tc,
        "//command_line_option:host_platform": host,
        "//command_line_option:platforms": tgt
    }

####################
sig_in_transition = transition(
    implementation = _sig_in_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//cfg/library/linkage:linkage",
        "@rules_ocaml//cfg/library/linkage:level",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ],
    outputs = [
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
        "@rules_ocaml//cfg/library/linkage:linkage",
        "@rules_ocaml//cfg/library/linkage:level",
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ]
)

################################################################
# Purpose: set host_platform and platforms based on
# @rules_ocaml//toolchain
def _toolchain_in_transition_impl(settings, attr):
    debug = False

    tc = settings["@rules_ocaml//toolchain"]
    if tc == "nop":
        return {}
    host, tgt = get_tc(settings, attr)

    if host == None:
        # print("%s %s NULL TC TRANSITION" % (attr._rule, attr.name))
        return {}
    else:
        # print("%s %s TC TRANSITION" % (attr._rule, attr.name))
        return {
            "//command_line_option:host_platform": host,
            "//command_line_option:platforms": tgt
    }

###################
toolchain_in_transition = transition(
    implementation = _toolchain_in_transition_impl,
    inputs = [
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"],
    outputs = [
        "//command_line_option:host_platform",
        "//command_line_option:platforms"
    ]
)

##################################################
# Purpose: set compilation_mode to opt, so
# that external deps will be optimized.
# Probably not a good idea.
def _test_in_transition_impl(settings, attr):
    debug = False

    tc = _toolchain_in_transition_impl(settings, attr)

    return tc.update({
            "//command_line_option:compilation_mode": "opt"
    })

###################
test_in_transition = transition(
    implementation = _test_in_transition_impl,
    inputs = [
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms"],
    outputs = [
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
        "//command_line_option:compilation_mode"
    ]
)

