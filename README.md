# skills

Publish, list and download Agent Skills on [mooncakes.io/skills](https://mooncakes.io/skills).
The root package builds the `skills` executable. Import
`moonbit-community/skills/skills` to use the client and archive validation library.

## Install and run

Run the published module directly:

```sh
moonx moonbit-community/skills list
```

Or install from the repository root:

```sh
moon install .
skills --help
moon login
skills publish ./my-skill --version 1.0.0
skills list
skills download alice/my-skill --extract ./downloaded-skill
```

The MoonBit bin directory must be on `PATH`. Publishing reads `credentials.json`
from `MOON_HOME` or `--moon-home`. The skill directory must contain a root
`SKILL.md` with `name` and `description` in its YAML frontmatter.

## Development

Point the CLI at a local Mooncakes instance:

```sh
export SKILLS_REGISTRY=http://mooncakes.test
moon run . -- list
```

Check and build the CLI from the repository root:

```sh
moon check --target native
moon build --target native --release
```

## Publishing

Set the repository or organization secret `MOONCAKES_MOONBIT_COMMUNITY_TOKEN`
to the Mooncakes `credentials.json` contents for the publishing account.
Push a `v<VERSION>` tag matching `moon.mod`, or run the `publish-package`
workflow with an existing tag. The workflow publishes to Mooncakes and creates
a GitHub Release.
