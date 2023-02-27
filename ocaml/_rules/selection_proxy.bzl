load("@rules_ocaml//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlProvider",
     "OcamlSignatureProvider",
     "OcamlNsResolverProvider")

################################################################
def _ocaml_selection_proxy_impl(ctx):
    print(ctx.attr.selection)
    print("ct: %s" % len(ctx.attr.selection))
    for s in ctx.attr.selection:
        print("DefaultInfo: %s" % s[DefaultInfo])
        if OcamlSignatureProvider in s:
            print("OcamlSignatureProvider: %s" % s[OcamlSignatureProvider])

    providers = []
    s = ctx.attr.selection[0]
    if OcamlProvider in s:
        providers.append(s[OcamlProvider])
        if OcamlSignatureProvider in s:
            providers.append(s[OcamlSignatureProvider])
            providers.append(s[DefaultInfo])
    else:
        ## input is a source file
        providers = [DefaultInfo(files = s.files, executable = None)]

    return providers

_ocaml_selection_proxy = rule(
    implementation = _ocaml_selection_proxy_impl,
    doc = "Workaround for using transitions with selectable attributes",
    attrs = dict(
        selection = attr.label_list(
            allow_files = True
        )
    ),
    executable = False
)

def ocaml_selection_proxy(name, selectors, no_match_error_msg):

    # if no_match_error:
    #     selectors = "select({sel}),no_match_error = \"{nomatch}\")".format(
    #         sel = selectors, nomatch = no_match_error)
    # else:
    #     selectors = "select({sel})".format(
    #         sel = selectors, nomatch = no_match_error)

    if no_match_error_msg:
        _ocaml_selection_proxy(
            name = name,
            selection = select(
                selectors,
                no_match_error=no_match_error_msg
            )
        )
    else:
        _ocaml_selection_proxy(
            name = name,
            selection = select(selectors, no_match_error="foo")
        )

################################################################
def _cc_selection_proxy_impl(ctx):
    # print(ctx.attr.selection)
    # print("ct: %s" % len(ctx.attr.selection))

    cc_infos = []
    for s in ctx.attr.selection:
        # print("DefaultInfo: %s" % s[DefaultInfo])
        # print("CcInfo: %s" % s[CcInfo])
        cc_infos.append(s[CcInfo])

    ccInfo = cc_common.merge_cc_infos(cc_infos = cc_infos)

    providers = []
    s = ctx.attr.selection[0]
    providers = [DefaultInfo(files = s.files, executable = None),
                 ccInfo]

    return providers

cc_selection_proxy = rule(
    implementation = _cc_selection_proxy_impl,
    doc = "Workaround for using transitions with selectable attributes",
    attrs = dict(
        selection = attr.label_list(
            allow_files = True,
            providers = [CcInfo]
        ),
        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        _cc_toolchain = attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        ),
    ),
    executable = False,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"]
)

# def Xcc_selection_proxy(name, selectors, no_match_error_msg):

#     # if no_match_error:
#     #     selectors = "select({sel}),no_match_error = \"{nomatch}\")".format(
#     #         sel = selectors, nomatch = no_match_error)
#     # else:
#     #     selectors = "select({sel})".format(
#     #         sel = selectors, nomatch = no_match_error)

#     if no_match_error_msg:
#         _cc_selection_proxy(
#             name = name,
#             selection = select(
#                 selectors,
#                 no_match_error=no_match_error_msg
#             )
#         )
#     else:
#         _cc_selection_proxy(
#             name = name,
#             selection = select(selectors, no_match_error="foo")
#         )
