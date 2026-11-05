///|
pub struct Credentials {
  token : String
  username : String?
}

///|
#derive(FromJson)
pub struct Publication {
  owner : String
  name : String
  version : String
  detail_url : String
  archive_url : String
  archive_digest : String
}

///|
#derive(FromJson, ToJson)
pub struct Skill {
  owner : String
  name : String
  version : String
  author_avatar : String
  description : String
  detail_url : String
  archive_url : String
  archive_digest : String
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
