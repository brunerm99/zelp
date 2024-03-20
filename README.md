# Zelp - Zellij git hELPer
> The successor to [gelp](https://github.com/brunerm99/small-scripts/blob/main/gelp.nu)

## What is it?
It's a simple alternative to [tmux-sessionizer](https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer) for [zellij](https://zellij.dev/) written purely in [nushell](https://www.nushell.sh/).
It has one basic feature and is not completely done.

## Setup
1. Clone repo
2. Run `use zelp.nu`
3. Run `zelp init` from the cloned repo directory
    - This is checked every time you run `zelp`, so it is not necessary if you run `zelp` from within the cloned repo directory initially
4. Make sure you have the 'dummy' entry in your [password store](https://www.passwordstore.org/) if you wish to use the authentication for `root` priviledged commands in your zellij panes

### Optional setup for use with [kitty](https://sw.kovidgoyal.net/kitty/)
Kitty allows remote control of terminal sessions which can be used to detach zellij, run commands, etc. making a more complete zellij sessionizer possible.
This is _extremely_ hacky, but it works for detaching from zellij and running `zelp`.

1. Run `use kif.nu`
2. Map a key in [kitty.conf](https://sw.kovidgoyal.net/kitty/conf/) to `kif switch-session`. This is a little weird since you need to run it with `nushell`. Example mapping:
```
map f3 launch --keep-focus --copy-env /bin/nu -c "use /path/to/zelp-clone/kif.nu; kif switch-session"
```
