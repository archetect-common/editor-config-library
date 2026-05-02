# editor-config-library

Composable `.editorconfig` generator for Archetect. Ships per-language
section fragments (Rust, Java, JavaScript, Python, YAML, Markdown) and
renders a single `.editorconfig` by concatenating the selected ones,
plus an optional standard `.gitattributes`. Most often consumed by
parent archetypes; usable standalone to drop these files into an
existing project.

## Contract

### Inputs

| Key | Role |
|---|---|
| `editorconfig_languages` | List of language section names. Pre-set via `opts.languages`, context, or interactive prompt. |
| `editorconfig_gitattributes` | Bool. Pre-set via `opts.gitattributes`, context, or interactive prompt. |

### Outputs

When mounted as a library (i.e. `archetype.is_library()` is true), the
prompt phase contributes a `components.editor_config` entry to the
context:

| Field | Example | Notes |
|---|---|---|
| `components.editor_config.languages` | `["Rust", "YAML"]` | Echo of the chosen list |
| `components.editor_config.file` | `.editorconfig` | Where `finalize` will write |
| `components.editor_config.gitattributes_file` | `.gitattributes` (or absent) | Set when gitattributes was opted in |
| `components.editor_config.section_includes.<lang>` | `editor-config/editorconfig-rust.atl` | Include path for the language section, prefixed with the parent's chosen catalog map-key |
| `components.editor_config.section_includes.root` | `editor-config/editorconfig-root.atl` | The `[*]` defaults section |
| `components.editor_config.section_includes.gitattributes` | `editor-config/gitattributes.atl` | The `.gitattributes` partial |

The published `section_includes` paths use whatever catalog map-key the
parent mounted this library under — the library builds them via
`archetype.include_path(...)`, which auto-prefixes the mount key, so a
parent mounting under `editor-config:` sees `editor-config/...` and a
parent mounting under, say, `ec:` would see `ec/...`. No mount-key
duplication on either side.

In standalone runs `components.editor_config` is not published — there's
no parent to consume it.

The library's *side effect* is rendering `.editorconfig` (and optionally
`.gitattributes`) at the requested destination, regardless of mode.

## API

| Call | When to use it |
|---|---|
| `editor_config.prompt(context, opts?)` | Gather languages + gitattributes flag. `opts` wins, else prompt. No side effects |
| `editor_config.finalize(context, opts?)` | Render the files. `opts.destination` controls where (subdir under `Location.Destination`; default is root) |
| `editor_config.run(context, opts?)` | One-shot `prompt` + `finalize` |
| `editor_config.languages` | The list of supported language names (read-only) |

The three-phase API matches `scm-library` / `gitignore-library` so
parents can mix and match — prompt early with the other libraries,
render content, finalize at the end.

## Languages

`Rust`, `Java`, `JavaScript`, `Python`, `YAML`, `Markdown`.

Each language has a corresponding `includes/editorconfig-<name>.atl`
fragment. The `[*]` defaults live in `editorconfig-root.atl` and are
always emitted. Adding a new language is a two-step edit: drop a
fragment file and add the name to `M.languages` in `lib/init.lua`.

## Usage — parent archetype

```yaml
# parent archetype.yaml
catalog:
  editor-config:
    source: "https://github.com/archetect-common/editor-config-library.git#v1"
    library: true
```

```lua
-- parent archetype.lua
local editor_config = require("editor-config")

-- Single call: pick languages and render into the project dir.
editor_config.run(context, {
    destination   = context:get("project-name"),
    languages     = { "Rust", "YAML", "Markdown" },
    gitattributes = true,
})
```

Or split across phases for consistency with `scm.prompt` / `scm.finalize`:

```lua
local editor_config = require("editor-config")

editor_config.prompt(context, { languages = { "Rust", "YAML", "Markdown" } })
-- …content render in between…
editor_config.finalize(context, { destination = context:get("project-name") })
```

### Raw partials (advanced)

Parents that want full control over composition can compose their own
`.editorconfig` from the same partials the API uses internally. The
recommended path is to read the include paths off
`components.editor_config.section_includes` so the library's chosen
mount-key prefix is honored without hardcoding:

```
{# in a parent template — uses whatever catalog map-key the parent mounted
   editor-config-library under #}
{% include components.editor_config.section_includes.root %}
{% include components.editor_config.section_includes.Rust %}
{% include components.editor_config.section_includes.gitattributes %}
```

## Usage — standalone

Drop `.editorconfig` (and `.gitattributes`) into the current directory:

```sh
archetect render https://github.com/archetect-common/editor-config-library.git#v1 .
```

Non-interactive with explicit languages:

```sh
archetect render https://github.com/archetect-common/editor-config-library.git#v1 . \
    -a 'editorconfig_languages=[Rust, YAML, Markdown]' \
    -a editorconfig_gitattributes=true
```

Non-interactive with defaults (`Rust + JavaScript + YAML + Markdown`,
gitattributes on):

```sh
archetect render https://github.com/archetect-common/editor-config-library.git#v1 . -D
```

## Context keys

### Input

| Key | Values | Notes |
|---|---|---|
| `editorconfig_languages` | List of language names | Default (when prompted): `[Rust, JavaScript, YAML, Markdown]` |
| `editorconfig_gitattributes` | bool | Default (when prompted): `true` |

### Output

No context keys. The library writes files and returns.

## Testing locally

```sh
archetect render --local \
    /Users/jimmie/personal/archetect-common/editor-config-library .
```

When a parent archetype is under development, `--local` also causes
its library dependencies to resolve to the local checkouts configured
via `archetect config` — including this one — so changes here take
effect immediately without cutting a new tag.

## Release versioning

This library comes wired with the
[`archetect-actions/repository-release`](https://github.com/archetect-actions/repository-release)
action. Trigger a `minor_release` via the GitHub Actions tab to cut
`v1.0` and an auto-updating `v1` floating tag.
