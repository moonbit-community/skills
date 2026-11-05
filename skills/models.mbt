///|
pub struct Credentials {
  token : String
  username : String?
}

///|
#derive(FromJson(fields(archive_sha256(rename="archive_digest"))))
pub struct Publication {
  owner : String
  name : String
  version : String
  detail_url : String
  archive_url : String
  archive_sha256 : String
}

///|
#derive(FromJson(fields(archive_sha256(rename="archive_digest"))), ToJson(fields(archive_sha256(rename="archive_digest"))))
pub struct Skill {
  owner : String
  name : String
  version : String
  author_avatar : String
  description : String
  detail_url : String
  archive_url : String
  archive_sha256 : String
  created_at : String
}

///|
pub struct SkillDetail {
  skill : Skill
  readme : String
  versions : Array[String]
}

///|
pub struct Download {
  skill : Skill
  path : String
}

///|
pub extend Publication with FromJson::{from_json}

///|
pub extend Skill with FromJson::{from_json}

///|
pub extend Skill with ToJson::{to_json}
