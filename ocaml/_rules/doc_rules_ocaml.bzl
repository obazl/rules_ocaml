load("ocaml_archive.bzl"    , _ocaml_archive    = "ocaml_archive")
load("ocaml_executable.bzl" , _ocaml_executable = "ocaml_executable")
load("ocaml_interface.bzl"  , _ocaml_interface  = "ocaml_interface")
load("ocaml_library.bzl"    , _ocaml_library    = "ocaml_library")
load("ocaml_module.bzl"     , _ocaml_module     = "ocaml_module")
load("ocaml_ns_archive.bzl" , _ocaml_ns_archive = "ocaml_ns_archive")
load("ocaml_ns.bzl"  , _ocaml_ns  = "ocaml_ns")

ocaml_archive     = _ocaml_archive
ocaml_executable  = _ocaml_executable
ocaml_interface   = _ocaml_interface
ocaml_library     = _ocaml_library
ocaml_module      = _ocaml_module
ocaml_ns_archive  = _ocaml_archive
ocaml_ns   = _ocaml_module

