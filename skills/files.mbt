///|
async fn pack_directory(directory : String) -> Bytes {
  if @fs.kind(directory, follow_symlink=false) != Directory {
    raise ClientError("Publish a regular directory, not a symbolic link")
  }
  let files : Array[(String, FixedArray[Byte])] = []
  let mut total = 0
  async fn visit(relative : String) -> Unit {
    let path = if relative.is_empty() {
      directory
    } else {
      "\{directory}/\{relative}"
    }
    for entry in @fs.readdir(path, include_hidden=true, sort=true) {
      if [".git", ".mooncakes", "_build"].contains(entry) {
        continue
      }
      let name = if relative.is_empty() {
        entry
      } else {
        "\{relative}/\{entry}"
      }
      validate_path(name)
      let source = "\{directory}/\{name}"
      if files.length() >= 2000 {
        raise ClientError("Skill exceeds 2000 entries")
      }
      match @fs.kind(source, follow_symlink=false) {
        Directory => {
          files.push(("\{name}/", []))
          visit(name)
        }
        Regular => {
          let size = @fs.file_size(source)
          if size > (MaxExpandedSize - total).to_int64() {
            raise ClientError("Skill exceeds 50 MiB")
          }
          let data = @fs.read_file(source).binary()
          total += data.length()
          if total > MaxExpandedSize {
            raise ClientError("Skill exceeds 50 MiB")
          }
          files.push((name, data.to_fixedarray()))
        }
        _ =>
          raise ClientError(
            "Only regular files and directories may be published: \{name}",
          )
      }
    }
  }
  visit("")
  Bytes::from_array(@fzip.zip_sync_checked(files))
}

///|
pub async fn Archive::extract(self : Archive, directory : String) -> Unit {
  // Reserve a fresh directory before writing; existing files, symlinks and
  // directories are never followed or overwritten.
  @fs.mkdir(directory, allow_exist=false)
  let mut complete = false
  defer (if !complete { @fs.rmdir(directory, recursive=true) })
  for (name, bytes) in self.contents {
    let destination = "\{directory}/\{name}"
    if name.has_suffix("/") {
      @fs.mkdir(destination, recursive=true, allow_exist=true)
    } else {
      if name.rev_split_once("/") is Some((parent, _)) {
        @fs.mkdir("\{directory}/\{parent}", recursive=true, allow_exist=true)
      }
      @fs.write_file(
        destination,
        Bytes::from_array(bytes),
        create_mode=CreateNew,
      )
    }
  }
  complete = true
}
