-- editor-config-library main module.
--
-- Composes a `.editorconfig` file from a curated list of per-language
-- fragments shipped under `includes/`, and optionally a standard
-- `.gitattributes`. Callers pick languages via opts, pre-set context,
-- or an interactive multi-select.
--
-- Consumers that mount this archetype with `library: true` under the
-- catalog key `editor-config` reach this module via
-- `require("editor-config")`. The archetype's own shim script reaches
-- it via `require("lib")`.
--
-- Usage from a parent archetype (most common):
--
--     local editor_config = require("editor-config")
--     editor_config.run(context, {
--         destination   = context:get("project-name"),
--         languages     = { "Rust", "YAML", "Markdown" },
--         gitattributes = true,
--     })
--
-- Standalone — drops files into the destination root:
--
--     archetect render .../editor-config-library.git#v1 .
--
-- The three-phase API (`prompt` + `finalize` + `run`) mirrors
-- scm-library / gitignore-library for consistency.

local M = {}

-- The set of language section fragments this library ships. Adding a
-- new language is a two-step edit: drop a fragment under
-- `includes/editorconfig-<name>.atl` and add the name here.
M.languages = {
    "Rust",
    "Java",
    "JavaScript",
    "Python",
    "YAML",
    "Markdown",
}

-- Maps a Title-cased language name (the value we store in
-- `editorconfig_languages`) to its include filename. Used by the
-- `components.editor_config.section_includes` publication below —
-- `archetype.include_path(...)` auto-prefixes with the parent's chosen
-- catalog map-key so consumer templates can reference the partials
-- without knowing the prefix.
local SECTION_FILENAMES = {
    Rust       = "editorconfig-rust.atl",
    Java       = "editorconfig-java.atl",
    JavaScript = "editorconfig-javascript.atl",
    Python     = "editorconfig-python.atl",
    YAML       = "editorconfig-yaml.atl",
    Markdown   = "editorconfig-markdown.atl",
}

-- Gather the language sections and the gitattributes flag. Prefers
-- (in order): `opts` passed by the caller → values already in context
-- → interactive prompt. Pure context, no side effects.
function M.prompt(context, opts)
    opts = opts or {}

    if opts.languages then
        context:set("editorconfig_languages", opts.languages)
    end
    if opts.gitattributes ~= nil then
        context:set("editorconfig_gitattributes", opts.gitattributes)
    end

    if not context:get("editorconfig_languages") then
        context:prompt_multiselect("EditorConfig Languages:", "editorconfig_languages",
            M.languages, {
                help = "Select the language sections to compose into the generated .editorconfig.",
                default = { "Rust", "JavaScript", "YAML", "Markdown" },
            })
    end

    if context:get("editorconfig_gitattributes") == nil then
        context:prompt_confirm("Include .gitattributes?", "editorconfig_gitattributes", {
            help = "Render a standard .gitattributes alongside .editorconfig.",
            default = true,
        })
    end

    -- Publish a `components.editor_config` entry only when we're being
    -- mounted as a library — standalone runs have no parent that would
    -- read the structured component map. The published `section_includes`
    -- carry the parent's catalog map-key as a prefix, so consumer
    -- templates can `{% include components.editor_config.section_includes.rust %}`
    -- without knowing the mount name.
    if archetype.is_library() then
        local section_includes = {
            root          = archetype.include_path("editorconfig-root.atl"),
            gitattributes = archetype.include_path("gitattributes.atl"),
        }
        for lang, filename in pairs(SECTION_FILENAMES) do
            section_includes[lang] = archetype.include_path(filename)
        end

        local components = context:get("components") or {}
        components.editor_config = {
            languages          = context:get("editorconfig_languages"),
            file               = ".editorconfig",
            gitattributes_file = context:get("editorconfig_gitattributes")
                                 and ".gitattributes" or nil,
            section_includes   = section_includes,
        }
        context:set("components", components)
    end

    return context
end

-- Render the files. `opts.destination` is a subdirectory under
-- `Location.Destination`; omit to render at the destination root.
-- Parent archetypes typically pass their project directory:
-- `{ destination = context:get("project-name") }`.
function M.finalize(context, opts)
    opts = opts or {}

    local prefix = (opts.destination and opts.destination ~= "")
                   and (opts.destination .. "/") or ""

    file.render(archetype.include_path(".editorconfig.atl"), context,
                { destination = prefix .. ".editorconfig" })

    if context:get("editorconfig_gitattributes") then
        file.render(archetype.include_path(".gitattributes.atl"), context,
                    { destination = prefix .. ".gitattributes" })
    end

    return context
end

-- Convenience: prompt + finalize. Used by the standalone shim and by
-- parents that don't need to insert work between the two phases.
function M.run(context, opts)
    M.prompt(context, opts)
    M.finalize(context, opts)
    return context
end

return M
