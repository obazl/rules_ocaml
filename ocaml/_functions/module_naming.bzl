load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

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

    basename = basename.strip("_")

    result = basename[:1].capitalize() + basename[1:]

    return result

################################
def module_name_from_label(lbl):
    """Remove leading _, validate and normalize label.name"""
# module name grammar:
# module-name ::= capitalized-ident  
# capitalized-ident ::= (A … Z) { letter ∣  0 … 9 ∣  _ ∣  ' }  

    basename = lbl.name.lstrip("_") # remove leading _
    verify = basename.replace("'", "")
    verify = verify.replace("_", "")

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
