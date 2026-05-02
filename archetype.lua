-- editor-config-library standalone / one-shot entry point.
--
-- Parents wanting to consume this library should depend on it with
-- `library: true` and call `require("editor-config").run(context, opts)`
-- — see the README. This script runs when the archetype is invoked
-- directly (`archetect render editor-config-library .`) or via plain
-- `catalog.render("editor-config", ctx)` without `library: true`.

local context = Context.new()
require("lib").run(context)
return context
