load("ocaml_archive.bzl"    , _ocaml_archive    = "ocaml_archive")
load("ocaml_binary.bzl"     , _ocaml_binary     = "ocaml_binary")
load("ocaml_interface.bzl"   , _ocaml_interface  = "ocaml_interface")
load("ocaml_library.bzl"     , _ocaml_library    = "ocaml_library")
load("ocaml_module.bzl"      , _ocaml_module     = "ocaml_module")
load("ocaml_ns_archive.bzl"  , _ocaml_ns_archive = "ocaml_ns_archive")
load("ocaml_ns_module.bzl"   , _ocaml_ns_module  = "ocaml_ns_module")

ocaml_archive     = _ocaml_archive
ocaml_binary      = _ocaml_binary
ocaml_interface   = _ocaml_interface
ocaml_library     = _ocaml_library
ocaml_module      = _ocaml_module
ocaml_ns_archive  = _ocaml_archive
ocaml_ns_module   = _ocaml_module

