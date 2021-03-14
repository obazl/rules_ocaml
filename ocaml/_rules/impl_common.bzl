## ocaml/_rules/impl_common.bzl

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "DefaultMemo",
     "OcamlNsResolverProvider",
     "OpamDepsProvider")

tmpdir = "__obazl/"

#########################################
def merge_deps(deps,
               indirect_file_depsets,
               indirect_path_depsets,
               # indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps):

    ccdeps_labels = {}
    ccdeps = {}

    for dep in deps:

        indirect_file_depsets.append(dep[DefaultInfo].files)
        indirect_path_depsets.append(dep[DefaultMemo].paths)

        if OcamlNsResolverProvider in dep:
            indirect_file_depsets.append(dep[DefaultInfo].files)
            indirect_path_depsets.append(dep[DefaultMemo].paths)

        if AdjunctDepsProvider in dep:
            indirect_adjunct_depsets.append(dep[AdjunctDepsProvider].nopam)
            indirect_adjunct_path_depsets.append(dep[AdjunctDepsProvider].nopam_paths)
            indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].opam)

        if OpamDepsProvider in dep:
            indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

        if CcDepsProvider in dep:
            for [dep, linkmode] in dep[CcDepsProvider].libs.items():  ## ccdict.items():
                if dep.label in ccdeps_labels.keys():
                    if linkmode != ccdeps_labels[dep.label]:
                        fail("CCDEP: same key {k}, different vals: {v1}, {v2}".format(
                            k = dep,
                            v1 = ccdeps_labels[dep.label], v2 = linkmode
                        ))
                    # else:
                    #     print("Removing DUP ccdep: {k}: {v}".format(
                    #         k = dep, v = linkmode
                    #     ))
                else:
                    ccdeps_labels.update({dep.label: linkmode})
                    ccdeps.update({dep: linkmode})
            indirect_cc_deps.update(ccdeps)
