# Separate parsing, url resolution from ExternalProcesser

def parse_externals(input, repo)
  externals = []
  # externals should contain an array of 
  # hashes with local_dir, url and rev elements
  input.each { |l|
    # TODO: get rid of empty lines, comments and '# /'

    rev = nil
    # strip the dash rev
    if ! l.grep(/-r\s*(\d+)\b/i).empty? then
      rev = $~[1] 
      l.sub!($~[0], '')
    end
    # strip the peg revision
    if ! l.grep(/@(\d+)\b/i).empty? then
      rev = $~[1]
      l.sub!($~[0], '')
    end

    if m = %r|^/\s*(\S+)\s+(\S+)| then
      url = resolve_url(m[1], "DUMMY", repo)
      externals += [ { :dir=> $~[2], :url=> url, :rev=> rev } ]
    end
  }

  return externals
end

def resolve_url(partial_url, parent_url, repo)
  # certain special characters in the externals url need to be expanded
  # replace ^ with repository url
  url = partial_url.sub(/^\^/, repo)
  # TODO: replace .. with parent dir
  # TODO: replace // with repo scheme://
  # parsed_url = URI.parse(repo)
  # sch = parsed_url.scheme
  # TODO: replace / with repo server
  return url
end
