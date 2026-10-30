///|
async fn main {
  let matches = skills_command().parse(env=@env.get_env_vars())
  let client = @client.Client(
    registry=matches.values["registry"][0],
    moon_home?=matches.values.get("moon-home").map(values => values[0]),
  )
  @async.with_timeout(120000, () => {
    match matches.subcommand {
      Some(("publish", args)) => {
        let result = client.publish(
          args.values["directory"][0],
          args.values["version"][0],
        )
        println("Published \{result.owner}/\{result.name}@\{result.version}")
      }
      Some(("list", args)) => {
        let skills = client.list()
        if args.flags.get("json").unwrap_or(false) {
          println(Json(skills).stringify())
        } else {
          for skill in skills {
            println(
              "\{skill.owner}/\{skill.name}@\{skill.version}\n  \{skill.description}",
            )
          }
          println("\{skills.length()} skills")
        }
      }
      Some(("download", args)) => {
        let result = client.download(
          args.values["reference"][0],
          output?=args.values.get("output").map(values => values[0]),
          extract?=args.values.get("extract").map(values => values[0]),
        )
        let skill = result.skill
        println(
          "Downloaded \{skill.owner}/\{skill.name}@\{skill.version} to \{result.path}",
        )
      }
      _ => ()
    }
  })
}

///|
fn skills_command() -> @argparse.Command {
  Command(
    "skills",
    about="Publish, list and download Agent Skills on mooncakes.io.",
    arg_required_else_help=true,
    subcommand_required=true,
    options=[
      OptionArg(
        "registry",
        about="Registry origin (HTTP is supported for local development).",
        env="SKILLS_REGISTRY",
        default_values=["https://mooncakes.io"],
        global=true,
      ),
      OptionArg(
        "moon-home",
        about="Moon home directory containing credentials.json.",
        env="MOON_HOME",
        global=true,
      ),
    ],
    subcommands=[
      Command(
        "publish",
        about="Publish a complete skill directory as an immutable version.",
        positionals=[
          PositionArg(
            "directory",
            about="Skill directory with SKILL.md (name and description required).",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        options=[
          OptionArg("version", about="Release version (SemVer).", required=true),
        ],
      ),
      Command("list", about="List all published skills.", flags=[
        FlagArg("json", about="Print the JSON response."),
      ]),
      Command(
        "download",
        about="Download a skill and verify its SHA-256 checksum.",
        positionals=[
          PositionArg(
            "reference",
            about="OWNER/NAME[@VERSION]; defaults to the highest stable SemVer.",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        options=[
          OptionArg(
            "output",
            about="Save the ZIP to a new file (default: NAME-VERSION.zip).",
            conflicts_with=["extract"],
          ),
          OptionArg("extract", about="Extract into this new directory."),
        ],
      ),
    ],
  )
}
