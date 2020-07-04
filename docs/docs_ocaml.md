<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#ocaml_archive"></a>

## ocaml_archive

<pre>
ocaml_archive(<a href="#ocaml_archive-name">name</a>, <a href="#ocaml_archive-archive_name">archive_name</a>, <a href="#ocaml_archive-compile_strict_sequence">compile_strict_sequence</a>, <a href="#ocaml_archive-debug">debug</a>, <a href="#ocaml_archive-deps">deps</a>, <a href="#ocaml_archive-keep_locs">keep_locs</a>,
              <a href="#ocaml_archive-link_strict_sequence">link_strict_sequence</a>, <a href="#ocaml_archive-linkopts">linkopts</a>, <a href="#ocaml_archive-linkshared">linkshared</a>, <a href="#ocaml_archive-mode">mode</a>, <a href="#ocaml_archive-msg">msg</a>, <a href="#ocaml_archive-no_alias_deps">no_alias_deps</a>, <a href="#ocaml_archive-opaque">opaque</a>, <a href="#ocaml_archive-opts">opts</a>,
              <a href="#ocaml_archive-preprocessor">preprocessor</a>, <a href="#ocaml_archive-srcs">srcs</a>, <a href="#ocaml_archive-warnings">warnings</a>)
</pre>

Generates an OCaml archive file (.cmxa) and a C archive file (.a).

  Here is an example, from the 'digestif' library:

ocaml_archive(
    name = "common_archive",
    msg = "digestif, common",
    opts = ["-I", "src", "-open", "Digestif_by"],
    deps = [
        ":digestif_by",
        ":digestif_bi",
        ":digestif_conv",
        ":digestif_eq",
        ":digestif_hash",
        ":digestif_mli", # this will be ignored, archives do not understand cmi files
    ]
)




**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| archive_name |  -   | String | optional | "" |
| compile_strict_sequence |  -   | Boolean | optional | True |
| debug |  -   | Boolean | optional | True |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| keep_locs |  -   | Boolean | optional | True |
| link_strict_sequence |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| linkshared |  -   | Boolean | optional | False |
| mode |  -   | String | optional | "native" |
| msg |  -   | String | optional | "" |
| no_alias_deps |  -   | Boolean | optional | True |
| opaque |  -   | Boolean | optional | True |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| srcs |  OCaml source files   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ocaml_binary"></a>

## ocaml_binary

<pre>
ocaml_binary(<a href="#ocaml_binary-name">name</a>, <a href="#ocaml_binary-copts">copts</a>, <a href="#ocaml_binary-data">data</a>, <a href="#ocaml_binary-deps">deps</a>, <a href="#ocaml_binary-exe_name">exe_name</a>, <a href="#ocaml_binary-linkopts">linkopts</a>, <a href="#ocaml_binary-message">message</a>, <a href="#ocaml_binary-mode">mode</a>, <a href="#ocaml_binary-opts">opts</a>, <a href="#ocaml_binary-preprocessor">preprocessor</a>, <a href="#ocaml_binary-srcs">srcs</a>,
             <a href="#ocaml_binary-strip_data_prefixes">strip_data_prefixes</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| copts |  -   | List of strings | optional | [] |
| data |  Data files used by this executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| deps |  Dependencies. Do not include preprocessor (PPX) deps.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| exe_name |  -   | String | optional | "" |
| linkopts |  -   | List of strings | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  Preprocessor. Must be a single PPX executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| strip_data_prefixes |  Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -&gt; foo.data.   | Boolean | optional | False |


<a name="#ocaml_interface"></a>

## ocaml_interface

<pre>
ocaml_interface(<a href="#ocaml_interface-name">name</a>, <a href="#ocaml_interface-deps">deps</a>, <a href="#ocaml_interface-impl">impl</a>, <a href="#ocaml_interface-intf">intf</a>, <a href="#ocaml_interface-linkall">linkall</a>, <a href="#ocaml_interface-linkopts">linkopts</a>, <a href="#ocaml_interface-message">message</a>, <a href="#ocaml_interface-mode">mode</a>, <a href="#ocaml_interface-opts">opts</a>, <a href="#ocaml_interface-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| impl |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| intf |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| linkall |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| opts |  -   | List of strings | optional | [] |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a name="#ocaml_library"></a>

## ocaml_library

<pre>
ocaml_library(<a href="#ocaml_library-name">name</a>, <a href="#ocaml_library-compile_strict_sequence">compile_strict_sequence</a>, <a href="#ocaml_library-debug">debug</a>, <a href="#ocaml_library-depgraph">depgraph</a>, <a href="#ocaml_library-deps">deps</a>, <a href="#ocaml_library-dump_ast">dump_ast</a>, <a href="#ocaml_library-keep_locs">keep_locs</a>,
              <a href="#ocaml_library-link_strict_sequence">link_strict_sequence</a>, <a href="#ocaml_library-linkopts">linkopts</a>, <a href="#ocaml_library-mode">mode</a>, <a href="#ocaml_library-msg">msg</a>, <a href="#ocaml_library-no_alias_deps">no_alias_deps</a>, <a href="#ocaml_library-opaque">opaque</a>, <a href="#ocaml_library-opts">opts</a>, <a href="#ocaml_library-preprocessor">preprocessor</a>,
              <a href="#ocaml_library-short_paths">short_paths</a>, <a href="#ocaml_library-srcs">srcs</a>, <a href="#ocaml_library-strict_formats">strict_formats</a>, <a href="#ocaml_library-strict_sequence">strict_sequence</a>, <a href="#ocaml_library-warnings">warnings</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| compile_strict_sequence |  -   | Boolean | optional | True |
| debug |  -   | Boolean | optional | True |
| depgraph |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| dump_ast |  -   | Boolean | optional | True |
| keep_locs |  -   | Boolean | optional | True |
| link_strict_sequence |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| mode |  -   | String | optional | "native" |
| msg |  -   | String | optional | "" |
| no_alias_deps |  -   | Boolean | optional | True |
| opaque |  -   | Boolean | optional | True |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| short_paths |  -   | Boolean | optional | True |
| srcs |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| strict_formats |  -   | Boolean | optional | True |
| strict_sequence |  -   | Boolean | optional | True |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ocaml_module"></a>

## ocaml_module

<pre>
ocaml_module(<a href="#ocaml_module-name">name</a>, <a href="#ocaml_module-deps">deps</a>, <a href="#ocaml_module-impl">impl</a>, <a href="#ocaml_module-intf">intf</a>, <a href="#ocaml_module-linkall">linkall</a>, <a href="#ocaml_module-linkopts">linkopts</a>, <a href="#ocaml_module-message">message</a>, <a href="#ocaml_module-mode">mode</a>, <a href="#ocaml_module-opts">opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| impl |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| intf |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| linkall |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| opts |  -   | List of strings | optional | [] |


<a name="#ocaml_ns_archive"></a>

## ocaml_ns_archive

<pre>
ocaml_ns_archive(<a href="#ocaml_ns_archive-name">name</a>, <a href="#ocaml_ns_archive-archive_name">archive_name</a>, <a href="#ocaml_ns_archive-compile_strict_sequence">compile_strict_sequence</a>, <a href="#ocaml_ns_archive-debug">debug</a>, <a href="#ocaml_ns_archive-deps">deps</a>, <a href="#ocaml_ns_archive-keep_locs">keep_locs</a>,
                 <a href="#ocaml_ns_archive-link_strict_sequence">link_strict_sequence</a>, <a href="#ocaml_ns_archive-linkopts">linkopts</a>, <a href="#ocaml_ns_archive-linkshared">linkshared</a>, <a href="#ocaml_ns_archive-mode">mode</a>, <a href="#ocaml_ns_archive-msg">msg</a>, <a href="#ocaml_ns_archive-no_alias_deps">no_alias_deps</a>, <a href="#ocaml_ns_archive-opaque">opaque</a>, <a href="#ocaml_ns_archive-opts">opts</a>,
                 <a href="#ocaml_ns_archive-preprocessor">preprocessor</a>, <a href="#ocaml_ns_archive-srcs">srcs</a>, <a href="#ocaml_ns_archive-warnings">warnings</a>)
</pre>

Generates an OCaml archive file (.cmxa) and a C archive file (.a).

  Here is an example, from the 'digestif' library:

ocaml_archive(
    name = "common_archive",
    msg = "digestif, common",
    opts = ["-I", "src", "-open", "Digestif_by"],
    deps = [
        ":digestif_by",
        ":digestif_bi",
        ":digestif_conv",
        ":digestif_eq",
        ":digestif_hash",
        ":digestif_mli", # this will be ignored, archives do not understand cmi files
    ]
)




**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| archive_name |  -   | String | optional | "" |
| compile_strict_sequence |  -   | Boolean | optional | True |
| debug |  -   | Boolean | optional | True |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| keep_locs |  -   | Boolean | optional | True |
| link_strict_sequence |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| linkshared |  -   | Boolean | optional | False |
| mode |  -   | String | optional | "native" |
| msg |  -   | String | optional | "" |
| no_alias_deps |  -   | Boolean | optional | True |
| opaque |  -   | Boolean | optional | True |
| opts |  -   | List of strings | optional | [] |
| preprocessor |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| srcs |  OCaml source files   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| warnings |  -   | String | optional | "@1..3@5..28@30..39@43@46..47@49..57@61..62-40" |


<a name="#ocaml_ns_module"></a>

## ocaml_ns_module

<pre>
ocaml_ns_module(<a href="#ocaml_ns_module-name">name</a>, <a href="#ocaml_ns_module-deps">deps</a>, <a href="#ocaml_ns_module-impl">impl</a>, <a href="#ocaml_ns_module-intf">intf</a>, <a href="#ocaml_ns_module-linkall">linkall</a>, <a href="#ocaml_ns_module-linkopts">linkopts</a>, <a href="#ocaml_ns_module-message">message</a>, <a href="#ocaml_ns_module-mode">mode</a>, <a href="#ocaml_ns_module-opts">opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| deps |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| impl |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| intf |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| linkall |  -   | Boolean | optional | True |
| linkopts |  -   | List of strings | optional | [] |
| message |  -   | String | optional | "" |
| mode |  -   | String | optional | "native" |
| opts |  -   | List of strings | optional | [] |


