#!/bin/env nu
# zelp.nu
# Zellij git hELPer - the successor to gelp

const IGNORE_DIRS = [".cache", ".cargo", ".local"]
const DATA_DIR = ([$nu.home-path, ".local", "share", "zelp"] | path join)

# Open project workspace from selection
export def main [
  --update (-u) # Update project list cache
] {
  init # Ensure everything is set up

  let projects = if $update { (list-projects -u) } else { (list-projects) }
  let selection = ($projects | input list --fuzzy --display name)
  if ($selection | is-empty) { print "No choice... exiting"; return }

  let layout_dir = [$env.XDG_CONFIG_HOME, "zellij", "layouts"] | path join
  let possible_custom_layout_path = ([$selection.full_path, "zlayout.kdl"] | path join)
  let layout_path = if ($possible_custom_layout_path | path exists) { 
    $possible_custom_layout_path 
  } else {
    [$layout_dir, "default_layout.kdl"] | path join
  }

  let layout_config = (parse-layout-config $layout_path)
  let session_name = ($layout_config | get -i name | default $selection.name)

  if (session-exists $session_name) {
    let restart_session_choice = (["no", "yes"] | input list "Session exists, force restart?")
    if ($restart_session_choice | is-empty) {
      print "No choice... exiting"
      return
    } else if $restart_session_choice == 'yes' {
      zellij delete-session $session_name --force
    } else {
      zellij attach $session_name
      return
    }
  }

  if ($layout_config | get -i auth-needed | default false | into bool) and not (authenticate-keyring -v) {
    print "Failed to authenticate keyring..."
    return
  }

  let temp_layout_path = (create-temp-project-layout $layout_path $selection.full_path $session_name)

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

# List git projects
export def list-projects [
  --update (-u) # Update project list cache
] {
  let project_list_cache = ([$DATA_DIR, "project_cache.nuon"] | path join)
  if ($update) or not ($project_list_cache | path exists) {
    let ignore_dirs_arg = $"-E '{($IGNORE_DIRS | str join ',')}'" | str expand | str join ' '
    let fd_args = $'-Hau "^.git$" $"($env.HOME)" ($ignore_dirs_arg) --prune'
    let projects = (
      nu -c $"fd ($fd_args)" | 
        lines | 
        path dirname | 
        wrap full_path | 
        insert name { |row| $row.full_path | path basename }
    )
    $projects | to nuon | save -f $project_list_cache
    $projects
  } else {
    open $project_list_cache
  }
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
