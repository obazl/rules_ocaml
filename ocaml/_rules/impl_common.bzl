## ocaml/_rules/impl_common.bzl

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsEnvProvider",
     "OcamlNsLibraryProvider",
     "OpamDepsProvider",
     "OpamPkgInfo")
     # "PpxArchiveProvider",
     # "PpxExecutableProvider",
     # "PpxNsLibraryProvider")

tmpdir = "_obazl_/"

#########################################
def merge_deps(deps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps):

    for dep in deps:
        if OpamPkgInfo in dep:
            fail("OPAM DEP: %s" % dep)

        indirect_file_depsets.append(dep[DefaultInfo].files)
        indirect_path_depsets.append(dep[DefaultMemo].paths)

        ## FIXME: use OcamlNsProvider to pass resolvers
        indirect_resolver_depsets.append(dep[DefaultMemo].resolvers)

        if AdjunctDepsProvider in dep:
            indirect_adjunct_depsets.append(dep[AdjunctDepsProvider].nopam)
            indirect_adjunct_path_depsets.append(dep[AdjunctDepsProvider].nopam_paths)
            indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].opam)

        if OpamDepsProvider in dep:
            indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

        if CcDepsProvider in dep:
            # print("CC DEPS PROVIDER: %s" % dep[CcDepsProvider].libs)
            indirect_cc_deps.extend(dep[CcDepsProvider].libs)
