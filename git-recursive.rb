#!/usr/bin/ruby -w

require 'fileutils'
require 'open3'

class Processor

  def initialize(options = {})
    @all, @other = options.values_at(:all, :other)
    @warnings = []

    if @other.length < 1
      usage
    else
      @command = @other.delete_at(0)
    end
    
  end

  def usage
    # TODO:
    puts "Usage: COMMAND\nCOMMAND is one of st, exec, gengitosisconf, genclonescript"
    exit 1
  end

  def run    
    # t1 = Time.now

    case @command
      when "list" then list
      when "st" then status
      when "sts" then @other += ['-s'] ; status
      when "exec" then exec
      when "gengitosisconf" then gengitosisconf
      when "genclonescript" then genclonescript
      when "addgitosisremotes" then addgitosisremotes
      else puts "Command unknown."
    end

    # dump_warnings
    # dt = Time.now - t1
    # display_time = dt < 60 ? "%ds" % dt : "%d:%02d" % [dt / 60, dt % 60]
    # puts "Total time: #{display_time}"

    0
  end

  def find_git_sandboxes_in_current_dir(include_current = true)
    repos = %x(find . -type d -name .git).split("\n").grep(%r%^./(.+)/.git$%) {$~[1]}.sort
    if include_current
      ["."] + repos
    else
      repos
    end
  end

  def path_to_name(path, prefix, sep = "-")
    prefix + sep + path.gsub("/",sep)
  end

  def list

    if @other.length != 0
      usage
    end

    repos = find_git_sandboxes_in_current_dir
    puts repos
  end

  def status

    do_all = @other.delete("-a")
    do_branch = @other.delete("-b")
    do_svn = @other.delete("-s")
    if @other.length != 0
      usage
    end

    repos = find_git_sandboxes_in_current_dir
    repos.each do |r|
      puts "   CHECKING %s" % r
      if do_svn
        Dir.chdir(r) do
          system "git log git-svn..master --oneline"
        end
      end
      if !clean_repo?(r) || do_all
        Dir.chdir(r) do
          if do_branch
            system "git status -sb"
          else
            system "git status -s"
          end
        end
      end
    end

  end

  def exec

    repos = find_git_sandboxes_in_current_dir

    repos.each do |r|
      puts "   PROCESSING " + r
      Dir.chdir(r) do
        system @other.join(" ")
      end
    end
  end

  def gengitosisconf

    usage unless  @other.length >= 1

    prefix = @other.delete_at(0)
    
    args = Hash[*@other]
    owner = args['--owner']
    gitweb = args['--gitweb']
    daemon = args['--daemon']
    write = args['--write']
    readonly = args['--readonly']

    usage unless write

    repos = find_git_sandboxes_in_current_dir(false)

    reponames = [prefix] + repos.map { |r| path_to_name(r, prefix) }

    res = gitosisgroup(prefix, reponames, write, readonly)
    res += "\n"

    res += gitosisrepo(prefix, nil, owner, gitweb, daemon, "Root repository %s" % prefix)
    res += "\n"

    repos.each do |r|
      res += gitosisrepo(r, prefix, owner, gitweb, daemon, "Subrepository of %s with path %s" % [prefix, r] )
      res += "\n"
    end

    puts res
  end

  def gitosisgroup(name, repos, writable, readonly = nil)
    res = "[group %s]\n" % name
    res += "members = %s\n" % writable
    res += "writable = %s\n" % repos.join(" ") 
    if readonly
      res += "\n[group %s_readonly]\n" % name
      res += "members = %s\n" % readonly
      res += "readonly = %s\n" % repos.join(" ") 
    end

    res
  end

  def gitosisrepo(repo, prefix, owner = nil, gitweb = nil, daemon = nil, dscr = nil)
    repo = path_to_name(repo, prefix) if prefix
    res = "[repo %s]\n" % repo
    res += "owner = %s\n" % owner if owner
    res += "gitweb = %s\n" % gitweb if gitweb
    res += "daemon = %s\n" % daemon if daemon
    res += "description = %s\n" % dscr if dscr
    
    res
  end

  def genclonescript
    usage unless @other.length >= 1

    prefix = @other.delete_at(0)
    
    args = Hash[*@other]
    server = args['--server']

    usage unless server

    repos = find_git_sandboxes_in_current_dir(false)
    reponames = [[".", prefix]] + repos.map { |r| [r,path_to_name(r, prefix)] }

    res = <<EOS
#!/bin/bash
# Generated by git-recursive.rb

ROOTDIR=$1

if [ -z $ROOTDIR ] ; then
  ROOTDIR="."
fi

EOS
    
    reponames.each do |path, name|
      res += "mkdir -p $ROOTDIR/%s\n" % path
      res += "git clone %s:%s.git $ROOTDIR/%s\n" % [server, name, path]
    end
    
    puts res
  end

  def addgitosisremotes
    usage unless @other.length >= 1

    prefix = @other.delete_at(0)
    dry = @other.delete('--dry')
    
    args = Hash[*@other]
    server = args['--server']
    remotename = args['--remotename']

    usage unless server
    remotename = remotename || "origin"

    repos = find_git_sandboxes_in_current_dir(false)
    reponames = [[".", prefix]] + repos.map { |r| [r,path_to_name(r, prefix)] }

    reponames.each do |path,name|
      puts "   PROCESSING " + path
      Dir.chdir(path) do 
        command = "git remote add %s %s:%s.git" % [remotename, server, name]
        if dry
          puts command
        else
          system command
        end
      end
    end
    
  end

  def clean_repo?(repo)
    Dir.chdir(repo) do 
      %x%git status% =~ %r%working directory clean%
    end
  end










  def preflight_externals(externals)
  	externals = externals.select { |dir, url| File.exists?(dir) }
    have_dirty_files = false
    externals.each do |dir, url|
      Dir.chdir(dir) do
      	have_dirty_files = check_working_copy_dirty || have_dirty_files
      end
    end
    if have_dirty_files
	  exit 1
    end
  end


  def process_externals(externals)
    externals.each do |dir, url|
#      puts "Processing external #{dir} with url #{url}"
      raise "Error: svn:externals cycle detected: '#{url}'" if known_url?(url)
      raise "Error: Unable to find or mkdir '#{dir}'" unless File.exist?(dir) || FileUtils.mkpath(dir)
      raise "Error: Expected '#{dir}' to be a directory" unless File.directory?(dir)

      Dir.chdir(dir) { self.class.new(:parent => self, :externals_url => url).run }
      # remove the prepending '.' from dir for the ingore file
      update_exclude_file_with_paths([dir[1..-1]]) unless quick? 
    end
  end

  
  def dump_warnings
    @warnings.each do |key, data|
      puts "Warning: #{data[:message]}:"
      data[:items].each { |x| puts "#{x}\n" }
    end
  end


  def find_non_externals_sandboxes(externals)
    externals_dirs = externals.map { |x| File.expand_path(x[0]) }
    sandboxes = find_git_svn_sandboxes_in_current_dir.map { |x| File.expand_path(x) } 
#    print externals_dirs.join("\n")
#    print sandboxes.join("\n")
    non_externals_sandboxes = sandboxes.select { |sandbox| externals_dirs.select { |external| sandbox.index(external) == 0}.empty? }
    return if non_externals_sandboxes.empty?
    collect_warning('unknown_sandbox', 'Found git-svn sandboxes that do not correspond to SVN externals', non_externals_sandboxes.map {|x| "#{Dir.getwd}/#{x}"})
  end


  def collect_warning(category, message, items)
    if @parent
      @parent.collect_warning(category, message, items)
      return
    end
    @warnings[category] ||= {:message => message, :items => []}
    @warnings[category][:items].concat(items)
  end


  def topdir_relative_path(path)
    relative_dir = path.sub(self.topdir, '').sub(/^\//, '')
    relative_dir = '.' if relative_dir.empty?
    return relative_dir
  end


  def update_current_dir
    contents = Dir.entries('.').reject { |x| x =~ /^(?:\.+|\.DS_Store)$/ }
    relative_dir = topdir_relative_path(Dir.getwd)
    puts "updating #{relative_dir}"

    if contents.empty?
      # first-time clone
      raise "Error: Missing externals URL for '#{Dir.getwd}'" unless @externals_url
      no_history_option = no_history? ? '-r HEAD' : ''
      shell("git svn clone #{no_history_option} #@externals_url .")
    elsif contents == ['.git']
      # interrupted clone, restart with fetch
      shell('git svn fetch')
    else
      # regular update, rebase to SVN head
      check_working_copy_git
      check_working_copy_url
      check_working_copy_dirty # do a second check for dirty directories
      check_working_copy_branch

      # All sanity checks OK, perform the update
      output = shell('git svn rebase', true, [/is up to date/, /First, rewinding/, /Fast-forwarded master/, /W: -empty_dir:/])
      if output.include?('Current branch master is up to date.')
        restore_working_copy_branch
      end
    end
  end


  def check_working_copy_git
    raise "Error: Expected '#{Dir.getwd}' to be a Git working copy, but it isn't. Maybe a directory was replaced with an SVN externals definition. Please remove this directory and run this script again." unless File.exist?('.git')
  end


  def check_working_copy_branch
    shell('git status')[0] =~ /On branch (\S+)/
    raise "Error: Unable to determine Git branch in '#{Dir.getwd}' using 'git status'" unless $~
    branch = $~[1]
    return if branch == 'master'
    @previous_branch = branch
    puts "Switching from branch '#{@previous_branch}' to 'master'"
    shell("git checkout master")
#    raise "Error: Git branch is '#{branch}', should be 'master' in '#{Dir.getwd}'\n" unless branch == 'master'
  end
  

  def restore_working_copy_branch
    return if @previous_branch == nil
    puts "Switching back to branch '#{@previous_branch}'"
    shell("git checkout #{@previous_branch}")
  end


  def check_working_copy_dirty
      # Check that there are no uncommitted changes in the working copy that would trip up git's svn rebase
      dirty = ''      
      if git_version >= 1.7
        dirty = shell('git status --porcelain').reject { |x| x =~ /^\?\?/ }
      else
        dirty = shell('git status').map { |x| x =~ /modified:\s*(.+)/; $~ ? $~[1] : nil }.compact
      end

      if dirty.empty?
	    return false
      end

      puts "Error: Can't run svn rebase with dirty files in '#{Dir.getwd}':\n#{dirty.map {|x| x + "\n"}}"

      true
  end


  def git_version
    %x%git --version% =~ /git version (\d+\.\d+)/;
    return $~[1].to_f
  end


  def check_working_copy_url()
    return if quick?
    url = svn_url_for_current_dir
    if @externals_url && @externals_url.sub(/\/*$/, '') != url.sub(/\/*$/, '')
      raise "Error: The svn:externals URL for '#{Dir.getwd}' is defined as\n\n  #@externals_url\n\nbut the existing Git working copy in that directory is configured as\n\n  #{url}\n\nThe externals definition might have changed since the working copy was created. Remove the '#{Dir.getwd}' directory and re-run this script to check out a new version from the new URL.\n"
    end
  end
  
  
  def read_externals
    return read_externals_quick if quick?
    externals = shell('git svn show-externals').reject { |x| x =~ %r%^$% } # remove
    # empty lines remove commented lines (fix flaky show-externals output of
    # externals that are commented in svn:
    externals = externals.reject { |x| x =~ %r%(^\S*\s*#)|(^#)% } 
    # lines starting with / and not having any whitespaces are probably just
    # flaky outputs of show-externals where there was an actual empty line in
    # the svn:externals definition somewhere (which seems to be an svn-bug?)
    externals = externals.reject { |x| x =~ %r%^/\S*$% } 
    versioned_externals = externals.grep(/-r\d+\b/i)
    unless versioned_externals.empty?
      raise "Error: Found external(s) pegged to fixed revision: '#{versioned_externals.join ', '}' in '#{Dir.getwd}', don't know how to handle this."
    end
    peg_revision_externals = externals.grep(/@/)
    unless peg_revision_externals.empty?
      raise "Error: Found external(s) that seem to have a peg revision: '#{peg_revision_externals.join ', '}' in '#{Dir.getwd}', don't know how to handle this."
    end
    non_root_relative_externals = externals.reject { |x| x =~ /.*\^.*/ }
    unless non_root_relative_externals.empty?
      raise "Error: Found external(s) that don't use the root relative syntax (^): '#{non_root_relative_externals.join ', '}' in '#{Dir.getwd}'. Not yet implemented."
    end
    externals = externals.grep(%r%^(\S+)\s+(\S+)$%) { $~[1,2] }

    # process externals: replaceing "^" by the repository root, adding the
    # prefix to the local path, and changing the order of url and local dir
    processed_externals = []
    root = svn_repository_root_for_current_dir
    externals.each do |url, dir|
      /^(.*)\^(.*)$/ =~ url
      dir = "." + $1 + dir  # prefix starts with a '/', thus add a . to make the path relative
      url = root + $2
      processed_externals << [dir, url]
    end
    processed_externals
  end


  # In quick mode, fake it by using "find"
  def read_externals_quick
    find_git_svn_sandboxes_in_current_dir.map {|x| [x, nil]}
  end



  

  def process_svn_ignore_for_current_dir
    svn_ignored = shell('git svn show-ignore').reject { |x| x =~ %r%^\s*/?\s*#% }.grep(%r%^(/\S+)%) { $~[1] }
    update_exclude_file_with_paths(svn_ignored) unless svn_ignored.empty?
  end


  def update_exclude_file_with_paths(excluded_paths)
    excludefile_path = '.git/info/exclude'
    exclude_lines = []
    File.open(excludefile_path) { |file| exclude_lines = file.readlines.map { |x| x.chomp } } if File.exist?(excludefile_path)
    
    new_exclude_lines = []
    excluded_paths.each do |path|
      new_exclude_lines.push(path) unless (exclude_lines | new_exclude_lines).include?(path)
    end

    return if new_exclude_lines.empty?

    relative_path = topdir_relative_path("#{Dir.getwd}/#{excludefile_path}")
    puts "Updating Git exclude list '#{relative_path}' with new item(s): #{new_exclude_lines.join(" ")}\n"
    File.open(excludefile_path, 'w') { |file| file << (exclude_lines + new_exclude_lines).map { |x| x + "\n" } }
  end


  def svn_info_for_current_dir
    svn_info = {}
    shell('git svn info').map { |x| x.split(': ') }.each { |k, v| svn_info[k] = v }
    svn_info
  end


  def svn_url_for_current_dir
    url = svn_info_for_current_dir['URL']
    raise "Unable to determine SVN URL for '#{Dir.getwd}'" unless url
    url
  end


  def svn_repository_root_for_current_dir
    root = svn_info_for_current_dir['Repository Root']
    raise "Unable to determine SVN Repository Root for '#{Dir.getwd}'" unless root
    root
  end


  def known_url?(url)
    return false if quick?
    url == svn_url_for_current_dir || (@parent && @parent.known_url?(url))
  end
  
  
  def quick?
    return (@parent && @parent.quick?) || @quick
  end


  def verbose?
    return (@parent && @parent.verbose?) || @verbose
  end


  def no_history?
    return (@parent && @parent.no_history?) || @no_history
  end


  def topdir
    return (@parent && @parent.topdir) || @topdir
  end


  # this should really be using $? to check the exit status,
  # but it seems that's not available when using open3()
  def shell(cmd, echo_stdout = false, echo_filter = [])
    t1 = Time.now

    output = []
    done = false
    while !done do
      done = true
      Open3.popen3(cmd) do |stdin, stdout, stderr|
        stdin.close

        loop do
          ready = select([stdout, stderr])
          readable = ready[0]
          if stdout.eof?
            error = stderr.readlines
            if error.join('') =~ /SSL negotiation failed/
              done = false
              puts "shell command #{cmd} failed, retrying..."
              if cmd =~ /git svn clone/
                cmd_new = 'git svn fetch'
                puts "replacing shell command with '#{cmd_new}'"
                cmd = cmd_new
              end
            end
            break
          end
          readable.each do |io|
            data = io.gets
            next unless data
            if io == stderr
              print data if (verbose? || !echo_filter.find { |x| data =~ x })
            else
              print data if (verbose? || (echo_stdout && ! echo_filter.find { |x| data =~ x }))
              output << data
            end
          end
        end
      end
    end


    output.each { |x| x.chomp! }

    dt = (Time.now - t1).to_f
    puts "[shell %.2fs %s] %s" % [dt, Dir.getwd, cmd] if verbose?

    output
  end

end

# ----------------------

#exit Processor.new( :all => ARGV.delete('-a'), :other => ARGV).run
exit Processor.new(:other => ARGV).run
