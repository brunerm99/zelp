#!/bin/env nu
# zelp.nu
# Zellij hELPer - the successor to gelp

const IGNORE_DIRS = [".cache", ".cargo", ".local"]
const DATA_DIR = ([$nu.home-path, ".local", "share", "zelp"] | path join)
const PROJECT_LIST_CACHE_FNAME = "project_cache.nuon"
const LAYOUT_FILENAME = ".zlayout.kdl"

# Open project workspace from selection
export def main [
  --update (-u) # Update project list cache
  --remote (-r) # Open remote repo
] {
  init # Ensure everything is set up

  if $update { list-projects -u; return }
  let projects = (list-projects | 
    sort-by -rin last_used uses name | 
    upsert fmt { |row| $'($row.name)(if $row.uses > 0 { $" \((ansi green)uses: ($row.uses)(ansi reset))" })(if $row.last_used > (0 | into datetime) { $" \((ansi green)last used ($row.last_used | date humanize)(ansi reset))" })' }
  )
  let selection = ($projects | input list --fuzzy --display fmt)
  if ($selection | is-empty) { print "No choice... exiting"; return }

  if $remote { 
    xdg-open (parse-remote-url $selection.full_path)
    return
  }

  update-uses $projects $selection

  let session_name = ($selection.config | get -i name | default $selection.name)

  if (session-exists $session_name) {
    let restart_session_choice = (["no", "yes"] | input list "Session exists, force restart?")
    if ($restart_session_choice | is-empty) {
      print "No choice... exiting"
      return
    } else if $restart_session_choice == "yes" {
      zellij delete-session $session_name --force
    } else {
      zellij attach $session_name
      return
    }
  }

  if ($selection.config | get -i auth-needed | default false | into bool) and not (authenticate-keyring -v) {
    print "Failed to authenticate keyring..."
    return
  }

  let temp_layout_path = (create-temp-project-layout $selection.config.layout_path $selection.full_path $session_name)
  zellij --session $session_name --layout $temp_layout_path
}

# export def open-last [] {
#   $projects | update uses { |row| if ($row.full_path == $selection.full_path) { $row.uses | 1 } else { $row.uses } } | update last_used { |row| if ($row.full_path == $selection.full_path) { date now } else { $row.last_used } } | reject full_path
# }

export def delete [
  --no-force (-n) # Don't force delete if in use
] {
  let sessions_to_delete = (list-sessions | input list -m)
  if ($sessions_to_delete | is-empty) { return }
  if $no_force {
    $sessions_to_delete | each { |session| zellij delete-session $session | complete } 
  } else {
    $sessions_to_delete | each { |session| zellij delete-session $session --force | complete }
  }
  let num_deleted = ($sessions_to_delete | length)
  print $"($num_deleted) sessions deleted"
}

# List git projects or directories with zlayout.kdl file
export def list-projects [
  --update (-u) # Update project list cache
] {
  let default_layout_path = ([$env.XDG_CONFIG_HOME, "zellij", "layouts", "default_layout.kdl"] | path join)
  let project_list_cache = ([$DATA_DIR, $PROJECT_LIST_CACHE_FNAME] | path join)
  if ($project_list_cache | path exists) {  }
  if ($update) or not ($project_list_cache | path exists) {
    let ignore_dirs_arg = $"-E '{($IGNORE_DIRS | str join ',')}'" | str expand | str join ' '
    let fd_args = $'-Hau "^.git$|($LAYOUT_FILENAME)$" $"($env.HOME)" ($ignore_dirs_arg) --prune'
    let projects = (
      nu -c $"fd ($fd_args)" | 
        lines | 
        path dirname | 
        uniq | 
        wrap full_path | 
        insert config { |row| 
          let layout_path = ([$row.full_path, $LAYOUT_FILENAME] | path join) 
          if ($layout_path | path exists) { 
            parse-layout-config $layout_path | merge { layout_path: $layout_path } 
          } else { 
            parse-layout-config $default_layout_path | merge { layout_path: $default_layout_path } 
          } 
        } | 
        insert name { |row| ($row.config | get -i name | default ($row.full_path | path basename)) } |
        insert uses { 0 } |
        insert last_used { null }
    )
    let cached_projects = if ($project_list_cache | path exists) { open $project_list_cache } else { $projects }
    let projects = (join-project-lists $cached_projects $projects)
    $projects | to nuon | save -f $project_list_cache
    $projects
  } else {
    open $project_list_cache
  }
}

export def join-project-lists [
  cached # Cached projects
  new # New projects
] {
  $cached | 
    join --outer $new full_path | 
    update uses { |row| ([($row.uses | default 0), ($row.uses_ | default 0)] | math max) } |
    update last_used { |row| ([($row.last_used | default (0 | into datetime)), ($row.last_used_ | default (0 | into datetime))] | math max) } |
    update name { |row| $row.name_ } |
    update config { |row| $row.config_ } | 
    reject -i ...($in | columns | find --regex '^(?<name>\w+)_$') fmt
}

export def update-uses [
  projects # List of projects to update
  selected_project # Selected project record
] {
  $projects | 
    update last_used { |row| if $row.full_path == $selected_project.full_path { date now } else { $row.last_used } } | 
    update uses { |row| if $row.full_path == $selected_project.full_path { $row.uses + 1 } else { $row.uses } } |
    save -f ([$DATA_DIR, $PROJECT_LIST_CACHE_FNAME] | path join)
}

# List existing zellij sessions
def list-sessions [] {
  zellij ls --short | lines
}

# Check if session named <session_name> already exists
def session-exists [
  session_name: string
] -> bool {
  $session_name in (list-sessions)
}

# Requires 'dummy' entry in password store
# FIXME: This may not be the best way to authenticate the keyring... 
# but I couldn't find a better way
def authenticate-keyring [
  --verbose (-v)
] -> bool {
  if $verbose { print -n "Keyring authentication needed..." }
  if (pass show dummy | complete | get exit_code) == 0 {
    if $verbose { print "success" }
    true
  } else {
    if $verbose { print }
    false
  }
}

# Parse config in header of zellij layout
# Follows the format: "// key = value"
export def parse-layout-config [
  config_path: path
] {
  open $config_path --raw | 
    lines | 
    filter { str starts-with '//' } | 
    each { str replace '//' '' | str trim } | 
    parse '{key} = {value}' | 
    transpose --header-row | 
    into record
}

# Replace generic layout fields with project-specific data
def create-temp-project-layout [
  layout_path: path # Path to layout file
  project_dir: path # Project directory
  session_name: string # Session name
] -> path {
  let temp_layout_path = (["/tmp", $"($session_name)-zellij-session-layout.kdl"] | path join)
  open $layout_path --raw | 
    str replace --all '<project_dir>' $'"($project_dir)"' | 
    save -f $temp_layout_path
  $temp_layout_path
}

# Parse git remote url
export def parse-remote-url [
  project_dir: path # FS repo path
] {
  let git_remote = git -C $project_dir remote get-url origin
  try { $git_remote | url parse | url join } catch {
    let parsed_url = ($git_remote | parse '{version_control}@{host}:{username}/{repo}.git')
    if ($parsed_url | is-empty) {
      "https://github.com/brunerm99"
    } else {
      get 0 | 
      insert "scheme" "https" | 
      insert "path" $"($in.username)/($in.repo)" | 
      select host path scheme |
      url join
    }
  }
}

# Initialize
# RUN FROM THE CLONED REPO DIRECTORY
export def init [
  --force-link (-f) # Force re-linking of default config. Defaults to skipping if default config exists in XDG_CONFIG_HOME
] {
  if not ($DATA_DIR | path exists) { print $"Creating ($DATA_DIR)"; mkdir $DATA_DIR }

  let default_layout_fname = "default_layout.kdl" 
  let default_layout_source = ([$env.PWD, $default_layout_fname] | path join)
  let default_layout_target = ([$env.XDG_CONFIG_HOME, "zellij", "layouts"] | path join)
  if $force_link or not ($default_layout_target | path join $default_layout_fname | path exists) {
    if not ($default_layout_source | path exists) {
      print "Make sure you're running the init script from the cloned repo directory."
      print $"Didn't find default layout in PWD \(($default_layout_source)\)."
      return 
    }
    print $"Linking the default layout in ($default_layout_source) to ($default_layout_target)"
    ln -sf $default_layout_source $default_layout_target 
  } else {
    return
  }
}
