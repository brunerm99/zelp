# Zelp - Zellij git hELPer
> The successor to [gelp](https://github.com/brunerm99/small-scripts/blob/main/gelp.nu)

## What is it?
It's a simple alternative to [tmux-sessionizer](https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer) for [zellij](https://zellij.dev/) written purely in [nushell](https://www.nushell.sh/).
It has one basic feature and is not completely done.

## Setup
1. Clone repo
2. Run `zelp init` from the cloned repo directory
    - This is checked every time you run `zelp`, so it is not necessary if you run `zelp` from within the cloned repo directory initially
3. Make sure you have the 'dummy' entry in your [password store](https://www.passwordstore.org/) if you wish to use the authentication for `root` priviledged commands in your zellij panes

## TODO
- [ ] Does not work (as expected) if already in zellij instance. Need the '--background' flag PR to be merged or find a workaround.
- [ ] Add option for automatically activating venvs, if available. This is done manually in each custom layout file, currently.
- [ ] Add default layout copy command to easily copy a template into a new project
