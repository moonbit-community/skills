///|
struct Client {
  origin : String
  moon_home : String?
}

///|
pub fn Client::Client(
  registry~ : String = "https://mooncakes.io",
  moon_home? : String,
) -> Client raise ClientError {
  let origin = registry.trim_end(chars="/").to_owned()
  if !origin.has_prefix("https://") &&
    !origin.has_prefix("http://127.0.0.1:") &&
    !origin.has_prefix("http://localhost:") &&
    origin != "http://mooncakes.test" {
    raise ClientError(
      "Use an HTTPS registry (HTTP is supported for local development)",
    )
  }
  { origin, moon_home, }
}

///|
pub suberror ClientError {
  ClientError(String)
}

///|
impl Show for ClientError with fn output(self, logger) {
  let ClientError(message) = self
  logger.write_string(message)
}

///|
fn encode(value : String) -> String {
  @percent.encode(
    value,
    escape_chars=@percent.controls + " !\"#$%&'()*+,:;<=>?@[\\]^`{|}/",
  )
}

///|
pub async fn Client::credentials(self : Client) -> Credentials? {
  let origin = self.origin
  guard self.moon_home is Some(moon_home) else { return None }
  let path = "\{moon_home}/credentials.json"
  if !@fs.exists(path) {
    return None
  }
  let contents = @fs.read_file(path).text()
  let credentials = @json.parse(contents) catch {
    _ => raise ClientError("Invalid credentials.json. Run moon login again.")
  }
  guard credentials is { "token": String(token), .. } else {
    raise ClientError(
      "credentials.json has no API token. Run moon login again.",
    )
  }
  match credentials {
    { "registry_api": String(registry), .. } =>
      if registry.trim_end(chars="/") != origin {
        raise ClientError(
          "Moon credentials belong to a different registry. Run moon login for \{origin}.",
        )
      }
    { "registry_api": Null, .. } => ()
    { "registry_api": _, .. } =>
      raise ClientError(
        "Invalid registry_api in credentials.json. Run moon login again.",
      )
    _ => ()
  }
  let token = token.trim().to_owned()
  if token.length() != 32 ||
    !token.iter().all(c => c is ('0'..<='9' | 'a'..<='f')) {
    raise ClientError(
      "Invalid publishing API token. Run moon login again. Login JWTs are not publishing tokens.",
    )
  }
  let username = if credentials is { "username": String(username), .. } {
    Some(username)
  } else {
    None
  }
  Some({ token, username, })
}

///|
fn require_success(
  response : @http.Response,
  body : Bytes,
) -> Unit raise ClientError {
  if response.code >= 200 && response.code < 300 {
    return
  }
  let detail = try @json.parse(@fzip.str_from_u8(body.to_fixedarray())) catch {
    _ => "Request failed"
  } noraise {
    { "detail": String(detail), .. } => detail
    _ => "Request failed"
  }
  raise ClientError("HTTP \{response.code}: \{detail}")
}

///|
async fn read_bounded(reader : &@io.Reader, limit : Int32) -> Bytes {
  let buffer = @buffer.Buffer()
  while reader.read_some(max_len=65536) is Some(chunk) {
    if chunk.length() > limit - buffer.length() {
      raise ClientError("Response exceeds size limit")
    }
    buffer.write_bytes(chunk)
  }
  buffer.to_bytes()
}

///|
async fn request_bytes(
  url : String,
  limit : Int32,
  method~ : @http.RequestMethod = Get,
  body~ : Bytes = b"",
  headers~ : @http.Headers = {},
) -> Bytes {
  let mut url = @url.Url::parse(url)
  let mut method = method
  let mut body = body
  for redirects in 0..<6 {
    if url.scheme != "https" && url.scheme != "http" {
      raise ClientError("Unsupported HTTP URL")
    }
    let client = @http.Client(url.origin())
    defer client.close()
    client.request(
      method,
      "\{url.pathname()}\{url.search()}",
      extra_headers=headers,
    )
    client.write(body)
    let response = client.end_request()
    if response.code is (301 | 302 | 303 | 307 | 308) {
      if redirects == 5 {
        raise ClientError("Too many HTTP redirects")
      }
      guard response.headers.get("Location") is Some(location) else {
        raise ClientError("Redirect has no Location")
      }
      let next = @url.Url::parse(location, base=url)
      if next.origin() != url.origin() {
        headers.remove("Authorization")
      }
      if response.code == 303 ||
        (response.code is (301 | 302) && method == Post) {
        method = Get
        body = b""
        headers.remove("Content-Type")
      }
      url = next
      continue
    }
    let body = read_bounded(client, limit)
    require_success(response, body)
    return body
  }
  raise ClientError("Too many HTTP redirects")
}

///|
pub async fn Client::publish(
  self : Client,
  directory : String,
  version : String,
) -> Publication {
  ignore(parse_version(version))
  guard self.credentials() is Some(credentials) else {
    raise ClientError(
      "Moon credentials are required to publish. Run moon login for \{self.origin} and provide the Moon home directory.",
    )
  }
  let token = credentials.token
  let data = pack_directory(directory)
  ignore(validate(data))
  let result = request_bytes(
    "\{self.origin}/api/v0/skills?version=\{encode(version)}",
    1024 * 1024,
    method=Post,
    body=data,
    headers={
      "Authorization": "Bearer \{token}",
      "Content-Type": "application/zip",
    },
  )
  let publication : Publication = @json.from_json(
    @json.parse(@fzip.str_from_u8(result.to_fixedarray())),
  )
  if publication.archive_sha256 !=
    @crypto.bytes_to_hex_string(@crypto.sha256(data)) {
    raise ClientError("Published archive checksum does not match the upload")
  }
  publication
}

///|
pub async fn Client::list(self : Client) -> Array[Skill] {
  let data = request_bytes("\{self.origin}/api/v0/skills", 2 * 1024 * 1024)
  @json.from_json(@json.parse(@fzip.str_from_u8(data.to_fixedarray())))
}

///|
pub async fn Client::get(self : Client, reference : String) -> SkillDetail {
  guard reference.split("/").collect() is [owner, name] &&
    !owner.is_empty() &&
    !name.is_empty() else {
    raise ClientError("Invalid skill reference; expected OWNER/NAME[@VERSION]")
  }
  let data = request_bytes(
    "\{self.origin}/api/v0/skills/\{encode(owner.to_owned())}/\{encode(name.to_owned())}",
    16 * 1024 * 1024,
  )
  let payload = @json.parse(@fzip.str_from_u8(data.to_fixedarray()))
  guard payload is { "readme": String(readme), "versions": versions, .. } else {
    raise ClientError("Invalid skill response")
  }
  {
    skill: @json.from_json(payload),
    readme,
    versions: @json.from_json(versions),
  }
}

///|
pub async fn Client::download(
  self : Client,
  reference : String,
  output? : String,
  extract? : String,
) -> Download {
  if output is Some(_) && extract is Some(_) {
    raise ClientError("Choose either an output ZIP or an extraction directory")
  }
  let skill = self.get(reference).skill
  let data = request_bytes(skill.archive_url, MaxArchiveSize)
  if @crypto.bytes_to_hex_string(@crypto.sha256(data)) != skill.archive_sha256 {
    raise ClientError("Archive SHA-256 mismatch; nothing was written")
  }
  let archive = validate(data)
  if archive.name != skill.name {
    raise ClientError("Archive name does not match its skill release record")
  }
  let path = if extract is Some(directory) {
    archive.extract(directory)
    directory
  } else {
    let output = output.unwrap_or("\{skill.name}-\{skill.version}.zip")
    @fs.write_file(output, data, create_mode=CreateNew)
    output
  }
  { skill, path, }
}
