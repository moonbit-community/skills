///|
pub suberror InvalidSkill {
  InvalidSkill(String)
}

///|
impl Show for InvalidSkill with fn output(self, logger) {
  let InvalidSkill(message) = self
  logger.write_string(message)
}

///|
pub const MaxArchiveSize : Int32 = 20 * 1024 * 1024

///|
pub const MaxExpandedSize : Int32 = 50 * 1024 * 1024

///|
pub struct Archive {
  name : String
  description : String
  contents : Array[(String, FixedArray[Byte])]
}

///|
pub fn valid_name(name : String) -> Bool {
  !name.is_empty() &&
  name.length() <= 64 &&
  !name.has_prefix("-") &&
  !name.has_suffix("-") &&
  !name.contains("--") &&
  name.iter().all(c => c is ('a'..<='z' | '0'..<='9' | '-'))
}

///|
pub fn parse_version(version : String) -> @semver.SemVer raise InvalidSkill {
  let parsed = @semver.parse(version) catch {
    _ => raise InvalidSkill("Version must be a complete SemVer, such as 1.0.0")
  }
  if parsed.to_string() != version {
    raise InvalidSkill("Version must use canonical SemVer syntax")
  }
  parsed
}

///|
pub fn validate_path(path : String) -> Unit raise InvalidSkill {
  if path.is_empty() ||
    path.length() > 1024 ||
    path.iter().any(c => c < ' ' || c == '\\' || c == ':' || c == '\u{7f}') {
    raise InvalidSkill("Invalid archive path: \{path}")
  }
  let parts = path.trim_end(chars="/").split("/")
  for part in parts {
    if part.is_empty() ||
      part == "." ||
      part == ".." ||
      part.has_suffix(".") ||
      part.has_suffix(" ") {
      raise InvalidSkill("Invalid archive path: \{path}")
    }
  }
}

///|
fn metadata(readme : String) -> Json raise InvalidSkill {
  let lines = readme.split("\n").collect()
  guard lines.length() >= 3 && lines[0].trim_end(chars="\r") == "---" else {
    raise InvalidSkill("SKILL.md must start with YAML frontmatter")
  }
  let yaml_lines : Array[String] = []
  let mut closed = false
  for line in lines[1:] {
    if line.trim_end(chars="\r") == "---" {
      closed = true
      break
    }
    yaml_lines.push(line.to_owned())
  }
  if !closed {
    raise InvalidSkill("SKILL.md frontmatter is missing its closing ---")
  }
  let documents = @yaml.Yaml::load_from_string(yaml_lines.join("\n")) catch {
    _ => raise InvalidSkill("Invalid YAML in SKILL.md")
  }
  guard documents is [Map(fields)] else {
    raise InvalidSkill("SKILL.md frontmatter must be a single YAML mapping")
  }
  guard fields.get("name") is Some(String(name)) && valid_name(name) else {
    raise InvalidSkill(
      "name must be 1–64 lowercase letters, digits or single hyphens, without leading or trailing hyphens",
    )
  }
  guard fields.get("description") is Some(String(description)) &&
    !description.trim().is_empty() &&
    description.iter().count() <= 1024 else {
    raise InvalidSkill(
      "description must be a non-empty string of at most 1024 characters",
    )
  }
  documents[0].to_json()
}

///|
// fzip validates ZIP structure and sizes. Inspect the Unix file type as well:
// published archives must not smuggle symlinks or device entries into unzip tools.
fn validate_entry_kinds(data : Bytes) -> Unit raise InvalidSkill {
  fn u16(offset : Int32) -> Int32 {
    data[offset].to_int() | (data[offset + 1].to_int() << 8)
  }
  fn u32(offset : Int32) -> UInt32 {
    data[offset].to_uint() |
    (data[offset + 1].to_uint() << 8) |
    (data[offset + 2].to_uint() << 16) |
    (data[offset + 3].to_uint() << 24)
  }
  let mut end = data.length() - 22
  while end >= 0 {
    if u32(end) == 0x06054b50U && end + 22 + u16(end + 20) == data.length() {
      break
    }
    end -= 1
  }
  if end < 0 {
    raise InvalidSkill("Invalid ZIP directory")
  }
  let count = u16(end + 10)
  let offset = u32(end + 16)
  if count == 65535 || offset > data.length().reinterpret_as_uint() {
    raise InvalidSkill("ZIP64 archives are not supported")
  }
  let mut pos = offset.reinterpret_as_int()
  for _ in 0..<count {
    if pos < 0 || pos > data.length() - 46 || u32(pos) != 0x02014b50U {
      raise InvalidSkill("Invalid ZIP directory entry")
    }
    let kind = (u32(pos + 38) >> 16) & 0xf000U
    if kind != 0U && kind != 0x8000U && kind != 0x4000U {
      raise InvalidSkill("Only regular files and directories may be published")
    }
    pos += 46 + u16(pos + 28) + u16(pos + 30) + u16(pos + 32)
  }
}

///|
pub fn validate(data : Bytes) -> Archive raise InvalidSkill {
  if data.length() > MaxArchiveSize {
    raise InvalidSkill("Archive exceeds 20 MiB")
  }
  let input = data.to_fixedarray()
  let entries = @fzip.unzip_list(input) catch {
    _ => raise InvalidSkill("Invalid ZIP archive")
  }
  if entries.length() > 2000 {
    raise InvalidSkill("Archive exceeds 2000 entries")
  }
  validate_entry_kinds(data)
  let seen : Map[String, Bool] = Map([])
  let mut total = 0
  for entry in entries {
    validate_path(entry.name)
    let key = entry.name.trim_end(chars="/").to_owned().to_lower()
    if seen.contains(key) {
      raise InvalidSkill("Duplicate archive path: \{entry.name}")
    }
    seen[key] = !entry.name.has_suffix("/")
    if entry.original_size < 0 || entry.original_size > MaxExpandedSize - total {
      raise InvalidSkill("Expanded archive exceeds 50 MiB")
    }
    total += entry.original_size
    if entry.name == "SKILL.md" && entry.original_size > 256 * 1024 {
      raise InvalidSkill("SKILL.md exceeds 256 KiB")
    }
  }
  for entry in entries {
    let parts = entry.name.trim_end(chars="/").split("/").collect()
    let mut parent = ""
    for index, part in parts {
      if index == parts.length() - 1 {
        break
      }
      parent = if parent.is_empty() {
        part.to_owned()
      } else {
        "\{parent}/\{part}"
      }
      if seen.get(parent.to_lower()) is Some(true) {
        raise InvalidSkill(
          "Archive path is both a file and a directory: \{parent}",
        )
      }
    }
  }
  let contents = @fzip.unzip_sync(input, opts={ verify_checksum: true, }) catch {
    _ => raise InvalidSkill("Invalid ZIP archive or checksum")
  }
  let mut readme : String? = None
  for (path, content) in contents {
    if path.has_suffix("/") {
      continue
    }
    if path == "SKILL.md" {
      readme = Some(
        @utf8.decode(Bytes::from_array(content)) catch {
          _ => raise InvalidSkill("SKILL.md must be valid UTF-8")
        },
      )
    }
  }
  guard readme is Some(readme) else {
    raise InvalidSkill("Archive must contain SKILL.md at its root")
  }
  let meta = metadata(readme)
  guard meta is { "name": String(name), "description": String(description), .. } else {
    raise InvalidSkill("Invalid skill metadata")
  }
  { name, description, contents, }
}
