#!/usr/bin/env bash
# Fast file search — fd streams into fzf for instant fuzzy matching
# (scales to huge homes like GNOME's search). Runs in a floating terminal;
# the picked file opens in its default app. Hidden/dev/cache junk is skipped.
cd "$HOME" || exit 1

sel=$(fd --type f --follow \
        --exclude .git --exclude node_modules --exclude .cache \
        --exclude Android --exclude .cargo --exclude .rustup \
        --exclude .gradle --exclude flutter --exclude .pub-cache \
        --exclude .npm --exclude .m2 --exclude go --exclude build \
        . 2>/dev/null \
      | fzf --prompt "  " --height 100% --layout reverse --border rounded \
            --info inline --cycle \
            --preview 'file --brief {}' --preview-window down,1,border-top)

[ -z "$sel" ] && exit 0
setsid -f xdg-open "$HOME/$sel" >/dev/null 2>&1
