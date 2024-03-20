#!/bin/env nu
# kif.nu - Kitty interface

use zelp.nu

const ALT = '\u1b'
const CLEAR_SCREEN = '\u0c'
const CLEAR_TERMINAL_INPUT = '\u15'
const MAX_KITTY_SESSIONS = 20
const SOCKET_DIR = "/tmp"
const SOCKET_FILE_BASE_NAME = "kitty-socket-"

# Detach from zellij session inside kitty instance  
export def detach-zellij [
  kitty_socket: path # Kitty remote control socket path
] { 
  kitten @ --to $"($kitty_socket)" send-text $'($ALT)sd' 
}

export def switch-session [] {
  if ("KITTY_LISTEN_ON" in ($env | columns)) { 
    detach-zellij $env.KITTY_LISTEN_ON
    kitten @ --to $"($env.KITTY_LISTEN_ON)" send-text $CLEAR_TERMINAL_INPUT 
  }
  kitten @ --to $"($env.KITTY_LISTEN_ON)" send-text 'zelp \r' 
  
}

# Create remote controllable session
export def create-session [] {
  let session_id = (next-session-id)
  let socket_file = ([$SOCKET_DIR, $"($SOCKET_FILE_BASE_NAME)($session_id)"] | path join)
  bash -c $"'kitty -o allow_remote_control=yes --listen-on unix:($socket_file)&'"

  wait-for-socket $socket_file
  set-env [[key, value]; [KITTY_SOCKET_FILE, $socket_file]] $socket_file
}
 
# Get ids of current active kitty sessions
export def current-active-ids [] {
  ls -s $SOCKET_DIR | get name | parse $'($SOCKET_FILE_BASE_NAME){id}' | update id {into int} | get id
}

# Get next available kitty session id
# FIXME: What if max?
export def next-session-id [] {
  (current-active-ids) | 
    append 1..$MAX_KITTY_SESSIONS | 
    uniq --count | 
    where count == 1 | 
    get value | 
    math min
}

# Block until kitty socket open
def wait-for-socket [
  socket_file: path
] {
  while (kitten @ --to $"unix:($socket_file)" ls | complete | get exit_code) != 0 {}
  sleep 0.1sec
}

# Set environment variables in session
export def set-env [
  envs: table
  socket_file: path
] {
  $envs | each { |row| kitten @ --to $"unix:($socket_file)" send-text $" $env.($row.key) = '($row.value)' \r" }
  kitten @ --to $"unix:($socket_file)" send-text '\r'
  kitten @ --to $"unix:($socket_file)" send-text $CLEAR_SCREEN
}

# Start pueue daemon
export def start-pueue [] -> bool {
  if (ps | where name == (which pueued | get path.0) | is-empty) { pueued -d }
}

# Interface with kitty terminals through a socket interface.
# Default behaviour opens a kitty terminal in remote control 
# mode with some environment variables.
export def main [] {
  create-session
}


