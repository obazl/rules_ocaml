package(default_visibility = ["//visibility:public"])

constraint_setting(name = "mode")
constraint_value(constraint_setting = ":mode", name = "bytecode")
constraint_value(constraint_setting = ":mode", name = "native",)
