load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

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
    # print("NORMALIZING LBL: %s" % lbl)
    (segs, sep, basename) = lbl.rpartition(":")
    (basename, ext) = paths.split_extension(basename)
    basename = basename.strip("_")
    result = basename[:1].capitalize() + basename[1:]
    # print("RESULT: %s" % result)
    return result

###############################
def normalize_module_name(s):
    """Normalize module name: remove leading path segs, extension and prefixed underscores, capitalize first char."""

    (segs, sep, basename) = s.rpartition("/")
    (basename, ext) = paths.split_extension(basename)

    basename = basename.strip("_")

    result = basename[:1].capitalize() + basename[1:]

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
