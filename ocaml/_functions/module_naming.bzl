load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_rules:impl_common.bzl", "tmpdir", "module_sep")

load("//ocaml:providers.bzl", "OcamlNsResolverProvider")

# load("//ocaml:providers.bzl",
#      # "OcamlSDK",
#      # "OcamlArchiveProvider",
#      # "OcamlSignatureProvider",
#      # "OcamlLibraryMarker",
#      # "OcamlModuleMarker",
#      # "PpxArchiveProvider",
#      "PpxExecutableProvider",
#      "PpxModuleProvider")

###############################
def submodule_from_label_string(s):
    """Derive module name from label string."""
    lbl = Label(s)
    target = lbl.name
    # (segs, sep, basename) = s.rpartition(":")
    # (basename, ext) = paths.split_extension(basename)
    basename = target.strip("_")
    submod = basename[:1].capitalize() + basename[1:]
    return lbl.package, submod

################################
def normalize_module_label(lbl):
    """Normalize module label: remove leading path segs, extension and prefixed underscores, capitalize first char."""
    # print("NORMALIZING LBL: %s" % lbl.label.name)
    (segs, sep, basename) = lbl.rpartition(":")
    (basename, ext) = paths.split_extension(basename)
    basename = basename.strip("_")
    result = basename[:1].capitalize() + basename[1:]
    # print("Normalized: %s" % result)
    return result

###############################
def normalize_module_name(s):
    """Normalize module name: remove leading path segs, extension and prefixed underscores, capitalize first char."""

    (segs, sep, basename) = s.rpartition("/")
    (basename, ext) = paths.split_extension(basename)

    basename = basename.lstrip("_")
    basename = basename.replace("'", "")

    result = basename[:1].capitalize() + basename[1:]

    return result

################################
## FIXME: rename normalize_module_name
def module_name_from_label(lbl):
    """Remove leading _, validate and normalize label.name"""
## allows use of ' decoration in target names
# module name grammar:
# module-name ::= capitalized-ident  
# capitalized-ident ::= (A … Z) { letter ∣  0 … 9 ∣  _ ∣  ' }  

    basename = lbl.name.lstrip("_") # remove leading _
    verify = basename.replace("'", "")
    # verify = verify.replace("_", "")

    if not verify.isalnum():
        fail("name part of label %s not a valid module name (must be alphanumeric, \"'\", or \"_\")" % lbl)

    if not basename[:1].isalpha():
        fail("name part {n} of label {l} not a valid module name (must start with alpha char)".format(
            n = basename, l = lbl
        ))

    result = basename[:1].capitalize() + basename[1:]
    # print("Normalized: %s" % result)
    return result

###########################
def file_to_lib_name(file):
    if file.extension == "so":
        libname = file.basename[:-3]
        if libname.startswith("lib"):
            libname = libname[3:]
        else:
            fail("Found '.so' file without 'lib' prefix: %s" % file)
        return libname
    elif file.extension == "dylib":
        libname = file.basename[:-6]
        if libname.startswith("lib"):
            libname = libname[3:]
        else:
            fail("Found '.so' file without 'lib' prefix: %s" % file)
        return libname
    elif file.extension == "a":
        libname = file.basename[:-2]
        if libname.startswith("lib"):
            libname = libname[3:]
        else:
            fail("Found '.a' file without 'lib' prefix: %s" % file)
        return libname

######################################################
def _src_module_in_submod_list(ctx, src, submodules):
    # src: File
    # submodules: list of strings (bottomup) or labels (topdown)
    # print("_src_module_in_submod_list src: %s" % src)
    # print("_src_module_in_submod_list submodules: %s" % submodules)
    (src_module, ext) = paths.split_extension(src) # .basename)
    src_module = src_module[:1].capitalize() + src_module[1:]
    # print("src module: %s" % src_module)
    # print("src owner: %s" % src.owner)

    # if type(ctx.attr._ns_resolver) == "list":
    #     ns_resolver = ctx.attr._ns_resolver[0][OcamlNsResolverProvider]
    # else:
    #     ns_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]

    result = False
    submods = []
    for lbl_string in submodules:
        # print("submod str: %s" % lbl_string)
        submod = Label(lbl_string + ".ml")
        # print("submod label pkg: %s" % submod.package)

        (submod_path, submod_name) = submodule_from_label_string(lbl_string)
        # print("submod_name: %s" % submod_name)
        if src_module == submod_name:
            result = True
            ## WARNING: rule and src may be in different packages!
            # if src.owner.package == submod.package:
            #     result = True

    return result

###################################
## FIXME: we don't need this for executables (including test rules)
# if this is a submodule, add the prefix
# otherwise, if ppx, rename
# derive module name from ns prefixes
def derive_module_name(ctx, src): # src: string
    debug = False

    # if debug:
    # print("derive_module_name: %s" % src)
    ## src: string ## for modules, ctx.file.struct, for sigs, ctx.file.src

    # we get prefix list from ns_resolver module. they're also in the
    # config state (@rules_ocaml//cfg/ns:prefixes), which is how ns_resolver
    # gets them. they are also available in hidden _ns_prefixes for
    # all *_ns_* rules, but those could be changed by transitions.
    # only the ones in the ns_resolver module are reliable.(?)

    # _ns_resolver for modules, sigs has out transition, which forces this
    # to a list:

    ns_resolver = False
    bottomup = False
    ## bottom-up submodules have explicit ns_resolver attribute
    # if hasattr(ctx.attr, "ns_resolver"):
    if ctx.attr.ns_resolver:
        if debug: print("BOTTOMUP renaming")
        # print("BOTTOMUP: ctx.attr.ns_resolver %s" % ctx.attr.ns_resolver)
        bottomup = True
        ns_resolver = ctx.attr.ns_resolver
        # resolver either ocaml_ns_resolver or ocaml_module
        if hasattr(ctx.attr.ns_resolver[OcamlNsResolverProvider],
                   "ns_name"):
            prefix = ctx.attr.ns_resolver[OcamlNsResolverProvider].ns_name
        else:
            (prefix, extension) = paths.split_extension(
                ctx.file.ns_resolver.basename)
            # print("prefix xxxx %s" % prefix)
    else:
        if debug: print("TOPDOWN renaming")
        if type(ctx.attr._ns_resolver) == "list":
            ns_resolver = ctx.attr._ns_resolver[0]
            # print("NSR: %s" % ns_resolver)
        else:
            ns_resolver = ctx.attr._ns_resolver
        if debug: print("_ns_resolver: %s" % ns_resolver)
        if OcamlNsResolverProvider in ns_resolver:
            ns_resolver = ns_resolver[OcamlNsResolverProvider]
            # print("OcamlNsResolverProvider: %s" % nsresp)
        else:
            print("MISSING OcamlNsResolverProvider")

    # if debug:
    # print("ns_resolver: %s" % ns_resolver)

    ns     = None
    # module_sep = "__"

    ##WARN: this_module == src_module (src may be in difference dir/pkg);
    # (this_module, extension) = paths.split_extension(src) # .basename)
    this_module = src[:1].capitalize() + src[1:]

    # if ctx.label.name == "Char_cmi":
    #     print("this_module: %s" % this_module)

    # if bottomup:
    #     print("BOTTOMUP")
    # else:
    #     print("TOPDOWN")

    if bottomup:
        out_module = prefix + module_sep + this_module
    elif hasattr(ns_resolver, "prefixes"): # "prefix"):
        # print("hasattr prefixes: %s" % ns_resolver.prefixes)
        ns_prefixes = ns_resolver.prefixes # .prefix
        if len(ns_prefixes) == 0:
            out_module = this_module
        elif this_module == ns_prefixes[-1]:
            # print("this is a main ns module: %s" % this_module)
            out_module = this_module
        else:
            if len(ns_resolver.submodules) > 0:
                if bottomup:
                    # print("sm: %s" % ns_resolver.submodules)
                    # print("this_module: %s" % this_module)
                    if this_module in ns_resolver.submodules:
                        fs_prefix = module_sep.join(ns_prefixes) + "__"
                        out_module = fs_prefix + this_module
                    # else:
                else:
                    # print("topdown this: %s" % this_module)
                    if _src_module_in_submod_list(ctx,
                                                  src,
                                                  ns_resolver.submodules):
                        # print("%s in submod list" % this_module)
                        # if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
                        #     fs_prefix = get_fs_prefix(str(ctx.label)) + "__"
                        # else:
                        fs_prefix = module_sep.join(ns_prefixes) + "__"
                        out_module = fs_prefix + this_module
                    else:
                        out_module = this_module
            else:
                out_module = this_module
    else: ## not a submodule
        out_module = this_module

    # if ctx.label.name == "Std_exit":
    #     out_module = "std_exit"
    # if ctx.label.name == "Stdlib":
    #     out_module = "stdlib"

    # if this_module == out_module:
    # print("THIS: %s" % this_module)
    # print("OUT: %s" % out_module)

    return this_module, out_module

