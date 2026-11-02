---
name: meta-skill
description: "Find, download, use, create, and publish Agent Skills on mooncakes.io. Use when the user mentions mooncakes.io/skills, mooncakesio skills, or managing skill bundles through moonbit-community/skills. Excludes installing and publishing ordinary MoonBit library dependencies."
---

# Mooncakes Meta Skill

Manage complete skill directories containing `SKILL.md` and supporting resources. Browse the marketplace at [mooncakes.io/skills](https://mooncakes.io/skills).

## Invoke the CLI

Use `moonx moonbit-community/skills` without a CLI version suffix. This avoids relying on a globally installed `skills` executable. Check the available commands and options through help:

```sh
moonx moonbit-community/skills --help
moonx moonbit-community/skills download --help
moonx moonbit-community/skills publish --help
```

The documented CLI provides `list`, `download`, and `publish`; it has no `search`, `install`, `init`, or `validate` subcommand. Pass arguments directly after the module coordinate without inserting an extra `--`.

Select a particular skill release with a version suffix on the download reference:

```sh
moonx moonbit-community/skills download Yoorkin/handoff@0.1.0 --extract ./downloaded-handoff
```

Here, `0.1.0` is the downloaded skill's release version. Skill references use `OWNER/NAME[@VERSION]`, rather than MoonBit package paths. Preserve the owner's letter case.

## Find and download skills

List available skills and filter the results by owner, name, or description:

```sh
moonx moonbit-community/skills list
moonx moonbit-community/skills list --json
```

Open the returned `detail_url` to inspect content or choose a previous release. Resolve relative URLs against `https://mooncakes.io`. The marketplace also displays `SKILL.md` and available versions.

Choose one download command based on the requested output:

```sh
# Save a ZIP; the default filename is handoff-0.1.0.zip.
moonx moonbit-community/skills download Yoorkin/handoff@0.1.0

# Save to a new ZIP file at a chosen path.
moonx moonbit-community/skills download Yoorkin/handoff@0.1.0 --output ./handoff.zip

# Extract the complete skill directory, including supporting resources.
moonx moonbit-community/skills download Yoorkin/handoff@0.1.0 --extract ./downloaded-handoff
```

- Pin the downloaded skill's version when reproducibility matters. Omitting it selects the highest stable SemVer on the server. Do not assume `@latest` is supported as a skill release selector.
- The CLI verifies the archive SHA-256, ZIP structure, and root metadata before writing files.
- `--output` and `--extract` are mutually exclusive. The destination ZIP file or extraction directory must not exist; its parent directory must already exist.
- To update an installed skill, download into a new directory, inspect it, and replace the old copy according to the user's intent. Do not delete the original directory merely to bypass a path conflict.
- Report the resolved `OWNER/NAME@VERSION` and the actual download location.

## Use a downloaded skill

Downloading and enabling a skill are separate actions. Follow the user's agent, scope, or destination directory when provided. For a download-only request, save to the requested location or a new project directory. If enabling is required and the destination cannot be inferred, ask which agent and scope to use.

Read the root `SKILL.md` before use, confirm that it applies to the task, and follow its links to relevant references. Resolve relative resource paths from the skill directory. Keep the complete directory, including supporting files.

Prepare dependencies, run scripts, or invoke tools as directed by the skill. Extracted files may not retain executable permissions; run scripts through their declared interpreter when appropriate. If a skill invokes a tool through `moonx`, use the executable module coordinate documented by that skill. A marketplace skill reference does not necessarily identify an executable module.

Downloading does not require executing bundled scripts. Keep subsequent actions within the user's current task. Verify activation through the target agent's discovery or explicit invocation mechanism before reporting that the agent has loaded the skill.

## Create and publish skills

A skill bundle is a directory of instructions and resources. Include a MoonBit project or Wasm executable only when the skill needs one.

For creation-only requests, deliver the local directory. When the user requests uploading or publishing and the account, directory, and release version are clear, complete the checks and run `publish`. It uploads the complete directory, takes the skill name from the root `SKILL.md`, and uses `--version` for the release version.

### Create a minimal directory

Respect the user's chosen location. The minimal structure is:

```text
notes-summary/
└── SKILL.md
```

Start from this complete example if useful, then adapt the name, activation criteria, and instructions to the user's task:

```markdown
---
name: notes-summary
description: Organize user-provided meeting or work notes into a summary, confirmed decisions, and action items. Use when the user asks to summarize notes or extract follow-up actions.
---

# Summarize notes

Read the user's notes and organize the result into a summary, confirmed decisions, and action items.
Preserve explicitly stated owners and deadlines; mark missing details as unspecified.
Distinguish confirmed decisions from proposals under discussion. Do not invent conclusions.
Use the requested language, or the notes' primary language when none is specified.
```

Add supporting resources only when they serve the workflow:

- `references/`: Detailed guidance loaded as needed. Link it from `SKILL.md` and explain when to read it.
- `scripts/`: Executable helpers for repeated operations. Run new or changed scripts to verify their behavior.
- `assets/`: Templates or other materials used in generated output.
- `agents/`: Interface metadata for the target agent. Mooncakes does not require it for publishing.

The description should explain when to use the skill. Keep task-specific knowledge that affects execution in the body. Avoid copying generic tutorials or creating empty files just to fill a directory structure.

### Check the format and archive contents

The documented client validates these requirements:

| Item | Requirement |
| --- | --- |
| Entry point | UTF-8 `SKILL.md` directly at the ZIP root, without an enclosing directory |
| Frontmatter | First line is `---`, followed by a single YAML mapping and a closing delimiter line |
| `name` | 1–64 lowercase letters, digits, or hyphens; no leading, trailing, or consecutive hyphens |
| `description` | Nonblank string of at most 1024 characters |
| `SKILL.md` size | At most 256 KiB |
| Archive size | ZIP at most 20 MiB; total expanded size at most 50 MiB |
| Entry count | At most 2000 file and directory entries combined |
| File types | Regular files and directories only; no symbolic links, devices, or other special files |
| Paths | Relative paths using `/`, at most 1024 characters; no empty components, `.`, `..`, backslashes, colons, or control characters; components cannot end in a dot or space |
| Path conflicts | No case-insensitive duplicates or paths used as both a file and a directory |
| ZIP format | ZIP64 is unsupported |

The CLI packs the supplied directory directly; a manually created ZIP is unnecessary. It recursively includes hidden files and skips only entries named `.git`, `.mooncakes`, or `_build` at any depth. It does not filter through `.gitignore`. Use a dedicated skill directory and check that it contains no unintended `.env` files, credentials, caches, or unrelated build outputs. Replace symbolic links with actual files.

Check frontmatter, resource links, and supporting scripts locally. Use a skill format validator if one is available. The documented CLI has no local `validate` command or publishing `--dry-run`; do not use a real upload as a substitute for local checks.

### Authenticate and publish

Reuse an existing login. When valid publishing credentials are missing, run:

```sh
moon login
```

The documented CLI locates `credentials.json` through `--moon-home` or `MOON_HOME`, without supplying a default home directory. Pass the existing Moon home explicitly, for example:

```sh
moonx moonbit-community/skills \
  --moon-home "${MOON_HOME:-$HOME/.moon}" \
  publish ./notes-summary --version 1.0.0
```

- `--version 1.0.0` selects this skill's release version.
- Use a complete, canonical SemVer such as `1.0.0`; `v1.0.0` and `1.0` are invalid.
- The authenticated account determines the owner. The `name` in `SKILL.md` determines the skill name. Do not infer either from the directory name.
- Publishing requires the API token generated by Moon login; a login JWT is not a substitute. Do not print tokens or include credentials in the skill directory.
- Releases are immutable. Publish changed content under a new version rather than trying to overwrite an existing release.

### Verify the release and handle failures

Successful output looks like `Published OWNER/NAME@VERSION`. Keep the actual returned coordinate. Inspect that release on its marketplace detail page, or download the exact version into a new temporary directory:

```sh
moonx moonbit-community/skills download OWNER/NAME@VERSION --extract ./release-verification
```

Replace `OWNER/NAME@VERSION` with the actual published coordinate. Downloading verifies the archive SHA-256. Also compare `SKILL.md` and supporting files with the prepared release contents. Report the actual coordinate, detail link, and verification result.

| Situation | Action |
| --- | --- |
| Missing or invalid credentials | Check Moon home and log in to Mooncakes again if needed. Do not repeatedly upload. |
| HTTP 409 / version already exists | Download the exact release to inspect its state. Use an explicit new version for changed content. |
| Upload timeout or interrupted connection with an unknown result | Inspect the detail page or download the exact version to determine whether publication succeeded. Stop upload retries until the state is clear; do not automatically increment the version. |
| Download SHA-256 or archive validation failure | Stop using the result and report the coordinate and error. Do not bypass verification. |
| Download destination already exists | Choose a new file or directory and preserve the existing contents. |
