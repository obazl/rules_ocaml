
def ocaml_compile(ctx, env, pgm, args, inputs, outputs, tools,
                  progress_message):
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      tools = tools,
      mnemonic = "OcamlCompile",
      progress_message = "ocaml_compile {}: {}".format(
        progress_message, ctx.label.name
      )
  )
