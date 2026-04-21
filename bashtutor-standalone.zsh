#!/usr/bin/env zsh
# BashTutor Standalone — local pattern library, no AI dependency
# qq <question>  |  bt <question>  |  bashme <question>
# qq level beginner|intermediate|expert

[[ -n "${BASHTUTOR_LOADED}" ]] && return 0
export BASHTUTOR_LOADED=1
export BASHTUTOR_VERSION="2.0.0"
export BASHTUTOR_BACKEND="standalone"

# ── dirs & config ─────────────────────────────────────────────────────────────
export BASHTUTOR_DIR="${HOME}/.bashtutor"
export BASHTUTOR_CONFIG="${BASHTUTOR_DIR}/config"
export BASHTUTOR_LEVEL="beginner"
export _BT_LAST_CMD=""

mkdir -p "$BASHTUTOR_DIR" 2>/dev/null
[[ -f "$BASHTUTOR_CONFIG" ]] && source "$BASHTUTOR_CONFIG" 2>/dev/null
[[ -z "$BASHTUTOR_LEVEL" ]] && BASHTUTOR_LEVEL="beginner"

# ── colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    _OR=$(printf '\033[38;5;214m')   # gold/bright orange
    _DG=$(printf '\033[38;5;34m')    # bright green
    _GH=$(printf '\033[38;5;245m')   # light grey (more visible)
    _CY=$(printf '\033[38;5;51m')    # bright cyan
    _RE=$(printf '\033[38;5;196m')   # bright red
    _B=$(printf '\033[1m')
    _R=$(printf '\033[0m')
else
    _OR="" _DG="" _GH="" _CY="" _RE="" _B="" _R=""
fi

_bt_note() { printf "${_CY}  %s${_R}\n" "$*"; }
_bt_err()  { printf "${_RE}  ✗ %s${_R}\n" "$*" >&2; }

# ── boot line ─────────────────────────────────────────────────────────────────
printf "${_OR}${_B}❯ BashTutor${_R} ${_DG}v%s [%s]${_R}  ${_CY}qq help${_R} to start\n" "$BASHTUTOR_VERSION" "$BASHTUTOR_LEVEL"

# ── fish-style predictive ghost text ─────────────────────────────────────────
typeset -g _BT_GHOST=""
typeset -gA _BT_SMART=(
    [g]="git status"
    [gi]="git status"
    [git]="git status"
    [git\ s]="git status"
    [git\ p]="git push"
    [git\ c]="git commit -m ''"
    [git\ l]="git log --oneline -10"
    [git\ d]="git diff"
    [git\ b]="git checkout -b "
    [ls]="ls -la"
    [l]="ls -la"
    [cd]="cd ~"
    [rm]="rm -f "
    [mk]="mkdir -p "
    [cp]="cp "
    [mv]="mv "
    [ca]="cat "
    [gr]="grep -r '' ."
    [fi]="find . -name ''"
    [cu]="curl -s "
    [ss]="ssh "
    [ta]="tar -czf "
    [zi]="zip -r "
    [na]="nano "
    [vi]="vim "
    [py]="python3 "
    [pi]="pip3 install "
    [np]="npm install"
    [br]="brew install "
    [do]="docker ps"
    [ps]="ps aux"
    [ki]="kill "
    [pk]="pkill -f "
    [to]="top"
    [df]="df -h"
    [du]="du -sh *"
    [wh]="which "
    [ex]="export "
    [so]="source ~/.zshrc"
    [hi]="history | tail -20"
    [cl]="clear"
    [wc]="wc -l "
    [di]="diff "
    [ch]="chmod +x "
    [su]="sudo "
    [ec]="echo "
    [qq]="qq "
    [ma]="make folder / make file / make script executable"
    [mo]="move file to folder"
    [re]="remove file / rename file"
    [se]="set environment variable"
    [de]="delete file / delete folder"
    [op]="open file in editor"
    [ru]="run script / run python file"
    [sh]="show files / show ports / show disk space"
    [st]="stop process / start service"
    [wa]="watch file changes"
)

function _bt_ghost_update() {
    local prefix="$BUFFER"
    _BT_GHOST=""
    [[ ${#prefix} -lt 2 ]] && { zle -R; return; }
    local match
    match=$(fc -lnr 1 2>/dev/null | grep -Fm1 "${prefix}" | sed 's/^[0-9 \t]*//')
    if [[ -n "$match" && "$match" != "$prefix" ]]; then
        _BT_GHOST="${match#$prefix}"
    elif [[ ${#prefix} -ge 1 && -n "${_BT_SMART[$prefix]}" ]]; then
        local smart="${_BT_SMART[$prefix]}"
        [[ "$smart" != "$prefix" ]] && _BT_GHOST="${smart#$prefix}"
    fi
    zle -R
}

function _bt_ghost_render() {
    region_highlight=()
    [[ -z "$_BT_GHOST" ]] && return
    local ghost_start=${#BUFFER}
    local ghost_end=$(( ghost_start + ${#_BT_GHOST} ))
    POSTDISPLAY="$_BT_GHOST"
    region_highlight+=("$ghost_start $ghost_end fg=240,bold")
}

function _bt_ghost_accept() {
    [[ -z "$_BT_GHOST" ]] && { zle forward-char; return; }
    BUFFER="${BUFFER}${_BT_GHOST}"
    CURSOR=${#BUFFER}
    POSTDISPLAY=""
    _BT_GHOST=""
    zle -R
}

zle -N _bt_ghost_update
zle -N _bt_ghost_render
zle -N _bt_ghost_accept

autoload -Uz add-zle-hook-widget 2>/dev/null
add-zle-hook-widget line-pre-redraw _bt_ghost_render
add-zle-hook-widget keymap-select _bt_ghost_update

bindkey '^[[C' _bt_ghost_accept   # right arrow accepts
bindkey '^I' _bt_ghost_accept     # Tab accepts

function _bt_self_insert_ghost() {
    zle .self-insert
    _bt_ghost_update
}
zle -N self-insert _bt_self_insert_ghost

function _bt_ghost_clear() {
    POSTDISPLAY=""
    _BT_GHOST=""
}
zle -N _bt_ghost_clear
add-zle-hook-widget line-finish _bt_ghost_clear

# ── destructive command warning ───────────────────────────────────────────────
function _bt_preexec() {
    POSTDISPLAY=""
    _BT_GHOST=""
    export _BT_LAST_CMD="$1"
    local cmd="$1"
    local cmd_n="${cmd## }"
    cmd_n="${cmd_n//  / }"
    case "$cmd_n" in
        rm\ -rf*|rm\ -fr*|rm\ -r*|dd\ if=*|mkfs*|shred\ *|chmod\ -R\ 777*|\
        git\ reset\ --hard*|git\ clean\ -f*|git\ push\ --force*|git\ push\ -f\ *|\
        history\ -c*)
            printf "${_RE} =o_o= ${_B}⚠  Destructive: %s${_R}\n  Continue? [y/N] " "$cmd"
            read -r _bt_ans
            [[ "$_bt_ans" != [yY] ]] && { BUFFER=""; zle redisplay 2>/dev/null; return 1; }
            ;;
    esac
    return 0
}

# ── pattern lookup ────────────────────────────────────────────────────────────
# Sets globals: _BT_CMD  _BT_NOTE_B  _BT_NOTE_I
function _bt_lookup() {
    local q="${1:l}"
    _BT_CMD="" _BT_NOTE_B="" _BT_NOTE_I=""

    case "$q" in
        *list*file*|*show*file*|*display*file*|*what*here*|*ls\ *)
            _BT_CMD="ls -la"
            _BT_NOTE_B="Lists every file here, including hidden ones (starting with .)"
            _BT_NOTE_I="# -l=details -a=hidden files" ;;
        *new*file*|*creat*file*|*make*file*|*touch\ *)
            _BT_CMD="touch filename.txt"
            _BT_NOTE_B="Creates an empty file (updates timestamp if it exists)"
            _BT_NOTE_I="# creates or refreshes timestamp" ;;
        *creat*folder*|*make*folder*|*creat*dir*|*make*dir*|*new*folder*|*mkdir\ *)
            _BT_CMD="mkdir -p folder/name"
            _BT_NOTE_B="Creates a folder — -p also creates any missing parent folders"
            _BT_NOTE_I="# -p = ok if parents don't exist" ;;
        *copy*file*|*duplicat*file*)
            _BT_CMD="cp source.txt dest.txt"
            _BT_NOTE_B="Copies a file — use cp -r to copy a whole folder"
            _BT_NOTE_I="# -r=recursive for folders" ;;
        *move*file*|*renam*file*)
            _BT_CMD="mv old.txt new.txt"
            _BT_NOTE_B="Moves or renames a file — same command for both"
            _BT_NOTE_I="# mv works for files and folders" ;;
        *delet*file*|*remov*file*)
            _BT_CMD="rm filename"
            _BT_NOTE_B="Deletes a file permanently — no Trash, no undo"
            _BT_NOTE_I="# permanent, no recycle bin" ;;
        *delet*folder*|*remov*folder*|*delet*dir*|*remov*dir*)
            _BT_CMD="rm -rf foldername"
            _BT_NOTE_B="Deletes a folder and everything inside — no undo!"
            _BT_NOTE_I="# -r=recursive -f=force — CAREFUL" ;;
        *where*am*i*|*current*dir*|*pwd*)
            _BT_CMD="pwd"
            _BT_NOTE_B="Prints your current location in the file system"
            _BT_NOTE_I="# print working directory" ;;
        *go*home*|*home*dir*)
            _BT_CMD="cd ~"
            _BT_NOTE_B="Takes you to your home folder"
            _BT_NOTE_I="# ~ = your home directory" ;;
        *go*back*|*parent*folder*|*up*folder*|*cd*..*)
            _BT_CMD="cd .."
            _BT_NOTE_B="Goes up one folder level to the parent"
            _BT_NOTE_I="# .. = parent directory" ;;
        *go*folder*|*chang*dir*|*cd\ *)
            _BT_CMD="cd /path/to/folder"
            _BT_NOTE_B="Changes into a folder — use Tab to autocomplete paths"
            _BT_NOTE_I="# Tab autocompletes" ;;
        *view*file*|*show*file*|*display*file*|*read*file*|*print*file*|*show*content*|*cat\ *)
            _BT_CMD="cat file.txt"
            _BT_NOTE_B="Prints the whole file to the screen"
            _BT_NOTE_I="# dumps entire file to stdout" ;;
        *first*line*|*top*file*|*head\ *)
            _BT_CMD="head -20 file.txt"
            _BT_NOTE_B="Shows the first 20 lines of a file"
            _BT_NOTE_I="# -n sets number of lines" ;;
        *last*line*|*end*file*|*tail\ *)
            _BT_CMD="tail -20 file.txt"
            _BT_NOTE_B="Shows the last 20 lines of a file"
            _BT_NOTE_I="# -f=follow live updates" ;;
        *watch*log*|*follow*log*|*live*log*)
            _BT_CMD="tail -f logfile.log"
            _BT_NOTE_B="Watches a log file live — new lines appear as they're written"
            _BT_NOTE_I="# -f=follow, Ctrl+C to stop" ;;
        *edit*file*|*open*editor*|*view*editor*|*nano*)
            _BT_CMD="nano file.txt"
            _BT_NOTE_B="Opens a file in nano editor — Ctrl+O saves, Ctrl+X exits"
            _BT_NOTE_I="# ^O=save ^X=exit ^W=find" ;;
        *search*text*|*find*text*|*search*word*|*grep\ *)
            _BT_CMD="grep -r 'pattern' ."
            _BT_NOTE_B="Searches for text inside all files in this folder and subfolders"
            _BT_NOTE_I="# -r=recursive -i=case-insensitive -n=line numbers" ;;
        *search*case*insensit*|*grep*insensit*)
            _BT_CMD="grep -ri 'pattern' ."
            _BT_NOTE_B="Searches for text, ignoring upper/lower case"
            _BT_NOTE_I="# -i = ignore case" ;;
        *find*file*name*|*search*file*name*|*find\ *)
            _BT_CMD="find . -name '*.txt'"
            _BT_NOTE_B="Finds files by name — use * as a wildcard"
            _BT_NOTE_I="# -type f=files -type d=dirs -iname=case-insensitive" ;;
        *find*recent*modif*|*modif*today*|*new*files*)
            _BT_CMD="find . -mtime -1"
            _BT_NOTE_B="Finds files modified in the last 24 hours"
            _BT_NOTE_I="# -mtime -1=24h -mtime -7=week" ;;
        *find*large*|*find*big*|*find*size*)
            _BT_CMD="find . -size +100M"
            _BT_NOTE_B="Finds files larger than 100MB"
            _BT_NOTE_I="# +100M >100MB k=KB M=MB G=GB" ;;
        *replace*text*|*substitut*|*sed\ *)
            _BT_CMD="sed -i '' 's/old/new/g' file.txt"
            _BT_NOTE_B="Replaces every 'old' with 'new' in a file (macOS -i '')"
            _BT_NOTE_I="# g=all occurrences, remove '' on Linux" ;;
        *sort*|*order*line*)
            _BT_CMD="sort file.txt"
            _BT_NOTE_B="Sorts lines alphabetically — use -n for numeric, -r for reverse"
            _BT_NOTE_I="# -n=numeric -r=reverse -u=unique" ;;
        *unique*|*deduplic*|*remov*duplic*)
            _BT_CMD="sort file.txt | uniq"
            _BT_NOTE_B="Removes duplicate lines — must sort first so dupes are adjacent"
            _BT_NOTE_I="# uniq -c=count occurrences" ;;
        *disk*space*|*free*space*|*df\ *)
            _BT_CMD="df -h"
            _BT_NOTE_B="Shows how much disk space is free on each drive"
            _BT_NOTE_I="# -h=human readable GB/MB" ;;
        *folder*size*|*dir*size*|*du\ *)
            _BT_CMD="du -sh *"
            _BT_NOTE_B="Shows how much space each item in the current folder uses"
            _BT_NOTE_I="# -s=summary -h=human readable" ;;
        *biggest*|*largest*|*what*taking*space*)
            _BT_CMD="du -sh * | sort -rh | head -20"
            _BT_NOTE_B="Shows the 20 biggest items here, largest first"
            _BT_NOTE_I="# sort -rh = reverse human-sort" ;;
        *creat*archive*|*compress*folder*|*make*tar*)
            _BT_CMD="tar -czf archive.tar.gz folder/"
            _BT_NOTE_B="Compresses a folder into a .tar.gz archive"
            _BT_NOTE_I="# -c=create -z=gzip -f=filename" ;;
        *extract*archive*|*unpack*tar*|*uncompress*)
            _BT_CMD="tar -xzf archive.tar.gz"
            _BT_NOTE_B="Extracts a .tar.gz archive into the current folder"
            _BT_NOTE_I="# -x=extract -z=gzip -f=filename" ;;
        *zip*file*|*creat*zip*)
            _BT_CMD="zip -r archive.zip folder/"
            _BT_NOTE_B="Creates a .zip archive from a folder"
            _BT_NOTE_I="# -r=include subfolders" ;;
        *unzip*|*extract*zip*)
            _BT_CMD="unzip archive.zip"
            _BT_NOTE_B="Extracts a .zip archive here"
            _BT_NOTE_I="# -d folder/ to extract into a folder" ;;
        *permiss*|*chmod*|*who*can*)
            _BT_CMD="chmod 755 file"
            _BT_NOTE_B="Sets permissions: 7=owner all, 5=others read+run — think rwx"
            _BT_NOTE_I="# 4=read 2=write 1=exec; owner/group/others" ;;
        *make*executable*|*creat*executable*|*run*script*chmod*)
            _BT_CMD="chmod +x script.sh"
            _BT_NOTE_B="Makes a script executable so you can run it with ./script.sh"
            _BT_NOTE_I="# +x = add execute permission" ;;
        *change*owner*|*chown*)
            _BT_CMD="chown user:group file"
            _BT_NOTE_B="Changes who owns a file — you need sudo for others' files"
            _BT_NOTE_I="# -R=recursive for folders" ;;
        *see*permiss*|*check*permiss*)
            _BT_CMD="ls -la"
            _BT_NOTE_B="The left column shows permissions: rwxrwxrwx = owner/group/others"
            _BT_NOTE_I="# r=read w=write x=execute -=none" ;;
        *running*process*|*what*running*|*process*list*)
            _BT_CMD="ps aux"
            _BT_NOTE_B="Lists all running processes with CPU and memory usage"
            _BT_NOTE_I="# a=all u=user x=no-tty" ;;
        *kill*process*|*stop*process*)
            _BT_CMD="kill PID"
            _BT_NOTE_B="Stops a process by its ID — find the ID with: ps aux"
            _BT_NOTE_I="# kill -9 PID to force kill" ;;
        *kill*name*|*stop*app*|*pkill*)
            _BT_CMD="pkill -f appname"
            _BT_NOTE_B="Stops processes whose name matches — safer than kill PID"
            _BT_NOTE_I="# -f=match full command line" ;;
        *live*cpu*|*top*process*|*top\ *)
            _BT_CMD="top"
            _BT_NOTE_B="Live view of CPU and memory usage — q to quit"
            _BT_NOTE_I="# q=quit k=kill u=filter user" ;;
        *background*|*run*back*)
            _BT_CMD="command &"
            _BT_NOTE_B="Runs a command in the background so you can keep using the terminal"
            _BT_NOTE_I="# & = background; jobs to list; fg to bring back" ;;
        *port*listen*|*open*port*|*lsof*)
            _BT_CMD="lsof -i -P | grep LISTEN"
            _BT_NOTE_B="Shows which ports are open and which programs use them"
            _BT_NOTE_I="# -i=internet -P=port numbers" ;;
        *kill*port*|*free*port*|*stop*port*)
            _BT_CMD="lsof -ti:3000 | xargs kill -9"
            _BT_NOTE_B="Kills whatever process is using port 3000 (change the number)"
            _BT_NOTE_I="# -t=PIDs only, piped to xargs kill" ;;
        *test*connect*|*ping\ *|*reachable*)
            _BT_CMD="ping -c 4 google.com"
            _BT_NOTE_B="Tests if you can reach a server — sends 4 packets, shows speed"
            _BT_NOTE_I="# -c=count Ctrl+C to stop" ;;
        *download*file*|*curl*download*)
            _BT_CMD="curl -O https://example.com/file.zip"
            _BT_NOTE_B="Downloads a file from a URL, saving with its original filename"
            _BT_NOTE_I="# -o name=save as name -L=follow redirects" ;;
        *fetch*url*|*http*request*|*api*call*)
            _BT_CMD="curl -s https://api.example.com"
            _BT_NOTE_B="Fetches a URL and prints the response"
            _BT_NOTE_I="# -s=silent -I=headers only -X POST" ;;
        *ssh*connect*|*remote*server*|*ssh\ *)
            _BT_CMD="ssh user@hostname"
            _BT_NOTE_B="Opens a terminal on a remote server"
            _BT_NOTE_I="# -p=port -i=key file" ;;
        *sync*folder*|*rsync*|*backup*)
            _BT_CMD="rsync -avz source/ dest/"
            _BT_NOTE_B="Syncs folders — only copies what changed, much faster than cp"
            _BT_NOTE_I="# -a=archive -v=verbose -z=compress" ;;
        *set*var*|*env*var*|*export\ *)
            _BT_CMD="export VAR=value"
            _BT_NOTE_B="Sets an environment variable for this session and child processes"
            _BT_NOTE_I="# permanent: add to ~/.zshrc" ;;
        *list*env*|*see*env*|*env\ *|*printenv*)
            _BT_CMD="env"
            _BT_NOTE_B="Lists all environment variables currently set"
            _BT_NOTE_I="# printenv VAR to see just one" ;;
        *reload*config*|*source*zshrc*|*reload*shell*)
            _BT_CMD="source ~/.zshrc"
            _BT_NOTE_B="Reloads your zsh config without restarting the terminal"
            _BT_NOTE_I="# . ~/.zshrc also works" ;;
        *edit*zshrc*|*open*zshrc*|*edit*config*)
            _BT_CMD="nano ~/.zshrc"
            _BT_NOTE_B="Opens your shell config — add aliases and settings here"
            _BT_NOTE_I="# then: source ~/.zshrc to reload" ;;
        *where*command*|*which\ *)
            _BT_CMD="which command"
            _BT_NOTE_B="Shows where a command is installed on your system"
            _BT_NOTE_I="# command -v is the POSIX alternative" ;;
        *alias*|*shortcut*|*creat*shortcut*)
            _BT_CMD="alias ll='ls -la'"
            _BT_NOTE_B="Creates a shortcut — add to ~/.zshrc to keep it after restart"
            _BT_NOTE_I="# alias name='command'" ;;
        *command*histor*|*previous*command*|*histor\ *)
            _BT_CMD="history | tail -20"
            _BT_NOTE_B="Shows your 20 most recent commands"
            _BT_NOTE_I="# !! repeats last, !$ gets last arg" ;;
        *clear*screen*|*cls*)
            _BT_CMD="clear"
            _BT_NOTE_B="Clears the terminal screen (scroll up to see old output)"
            _BT_NOTE_I="# Ctrl+L also clears the screen" ;;
        *git*status*|*what*changed*git*)
            _BT_CMD="git status"
            _BT_NOTE_B="Shows which files have been changed, added, or deleted"
            _BT_NOTE_I="# -s = short summary" ;;
        *git*init*|*new*repo*|*start*repo*)
            _BT_CMD="git init"
            _BT_NOTE_B="Creates a new git repository in the current folder"
            _BT_NOTE_I="# creates the .git folder" ;;
        *git*add*|*stage*change*)
            _BT_CMD="git add ."
            _BT_NOTE_B="Stages all changed files ready to be committed"
            _BT_NOTE_I="# git add file.txt for one file" ;;
        *git*commit*|*save*git*)
            _BT_CMD="git commit -m 'message'"
            _BT_NOTE_B="Saves your staged changes with a description"
            _BT_NOTE_I="# -am to stage+commit all tracked files" ;;
        *git*push*|*upload*git*)
            _BT_CMD="git push"
            _BT_NOTE_B="Uploads your commits to the remote repository"
            _BT_NOTE_I="# -u origin main to set upstream" ;;
        *git*pull*|*download*latest*|*get*latest*)
            _BT_CMD="git pull"
            _BT_NOTE_B="Downloads and merges the latest changes from the remote"
            _BT_NOTE_I="# git fetch then merge" ;;
        *git*clone*|*download*repo*)
            _BT_CMD="git clone https://github.com/user/repo"
            _BT_NOTE_B="Downloads a full copy of a repository to your machine"
            _BT_NOTE_I="# --depth=1 for shallow (faster) clone" ;;
        *git*branch*|*new*branch*)
            _BT_CMD="git checkout -b branch-name"
            _BT_NOTE_B="Creates and switches to a new branch"
            _BT_NOTE_I="# git branch to list, -d to delete" ;;
        *git*log*|*commit*histor*)
            _BT_CMD="git log --oneline -20"
            _BT_NOTE_B="Shows the last 20 commits in a compact format"
            _BT_NOTE_I="# --graph for visual branch view" ;;
        *git*diff*|*what*diff*|*see*change*)
            _BT_CMD="git diff"
            _BT_NOTE_B="Shows what you've changed but not yet staged"
            _BT_NOTE_I="# --staged for staged changes" ;;
        *git*stash*|*save*work*later*)
            _BT_CMD="git stash"
            _BT_NOTE_B="Saves uncommitted work temporarily so you can switch branches"
            _BT_NOTE_I="# git stash pop to restore" ;;
        *git*undo*|*undo*commit*)
            _BT_CMD="git reset --soft HEAD~1"
            _BT_NOTE_B="Undoes the last commit but keeps your changes intact"
            _BT_NOTE_I="# --hard to discard changes too" ;;
        *git*merge*|*merge*branch*)
            _BT_CMD="git merge branch-name"
            _BT_NOTE_B="Merges another branch's changes into your current branch"
            _BT_NOTE_I="# --no-ff to always create a merge commit" ;;
        *brew*install*|*install*homebrew*)
            _BT_CMD="brew install packagename"
            _BT_NOTE_B="Installs a package via Homebrew — the macOS package manager"
            _BT_NOTE_I="# brew search name to find packages" ;;
        *brew*update*|*update*packages*)
            _BT_CMD="brew update && brew upgrade"
            _BT_NOTE_B="Updates Homebrew itself and upgrades all installed packages"
            _BT_NOTE_I="# update=Homebrew upgrade=packages" ;;
        *npm*install*|*node*module*|*package.json*)
            _BT_CMD="npm install"
            _BT_NOTE_B="Installs all packages listed in package.json"
            _BT_NOTE_I="# npm i --save-dev for dev deps" ;;
        *npm*run*|*run*script*npm*)
            _BT_CMD="npm run scriptname"
            _BT_NOTE_B="Runs a script defined in the scripts section of package.json"
            _BT_NOTE_I="# npm run with no args lists scripts" ;;
        *pip*install*|*python*package*)
            _BT_CMD="pip3 install packagename"
            _BT_NOTE_B="Installs a Python package"
            _BT_NOTE_I="# pip3 install -r requirements.txt for all" ;;
        *python*virtual*|*venv*|*virtualenv*)
            _BT_CMD="python3 -m venv venv && source venv/bin/activate"
            _BT_NOTE_B="Creates and activates a Python virtual environment"
            _BT_NOTE_I="# deactivate to exit it" ;;
        *docker*run*|*start*container*)
            _BT_CMD="docker run -it imagename"
            _BT_NOTE_B="Starts a Docker container interactively"
            _BT_NOTE_I="# -d=detached -p=port -v=volume" ;;
        *docker*list*|*running*container*|*docker*ps*)
            _BT_CMD="docker ps"
            _BT_NOTE_B="Lists all running Docker containers"
            _BT_NOTE_I="# -a = include stopped containers" ;;
        *system*info*|*os*version*|*uname*)
            _BT_CMD="uname -a"
            _BT_NOTE_B="Shows your OS, kernel version, and architecture"
            _BT_NOTE_I="# -r=kernel only -m=architecture" ;;
        *memory*|*ram*usage*)
            _BT_CMD="vm_stat | head -10"
            _BT_NOTE_B="Shows memory usage stats — look for 'Pages free' (macOS)"
            _BT_NOTE_I="# or: top -l 1 | grep PhysMem" ;;
        *uptime*|*how*long*running*)
            _BT_CMD="uptime"
            _BT_NOTE_B="Shows how long the system has been running and load averages"
            _BT_NOTE_I="# load avg: 1min 5min 15min" ;;
        *date*time*|*current*time*|*today*)
            _BT_CMD="date"
            _BT_NOTE_B="Shows the current date and time"
            _BT_NOTE_I="# date '+%Y-%m-%d' for custom format" ;;
        *who*am*i*|*username*|*whoami*)
            _BT_CMD="whoami"
            _BT_NOTE_B="Prints your current username"
            _BT_NOTE_I="# id for full user info" ;;
        *if*statement*|*condition*check*)
            _BT_CMD="if [[ condition ]]; then echo yes; fi"
            _BT_NOTE_B="Basic if/then — use [[ ]] for conditions in zsh/bash"
            _BT_NOTE_I="# [[ ]] preferred over [ ] in zsh" ;;
        *for*loop*|*loop*file*|*loop*list*)
            _BT_CMD='for f in *.txt; do echo "$f"; done'
            _BT_NOTE_B="Loops over all .txt files — \$f holds each filename"
            _BT_NOTE_I="# for item in list; do ...; done" ;;
        *while*loop*|*repeat*until*)
            _BT_CMD="while true; do echo running; sleep 1; done"
            _BT_NOTE_B="Runs forever until you press Ctrl+C"
            _BT_NOTE_I="# while condition; do ...; done" ;;
        *read*input*|*user*input*)
            _BT_CMD="read -r answer"
            _BT_NOTE_B="Waits for user to type something and stores it in \$answer"
            _BT_NOTE_I="# -p 'prompt: ' to show a prompt" ;;
        *function*|*creat*function*)
            _BT_CMD="function hello() { echo 'Hello!'; }"
            _BT_NOTE_B="Defines a reusable function — call it just by typing its name"
            _BT_NOTE_I="# or: hello() { ... }" ;;
        *pipe*|*chain*command*)
            _BT_CMD="command1 | command2"
            _BT_NOTE_B="Sends the output of command1 as input to command2"
            _BT_NOTE_I="# stdout of left becomes stdin of right" ;;
        *save*output*|*redirect*output*)
            _BT_CMD="command > output.txt"
            _BT_NOTE_B="Saves a command's output to a file (overwrites if it exists)"
            _BT_NOTE_I="# >> to append, 2>&1 to include errors" ;;
        *append*output*)
            _BT_CMD="command >> output.txt"
            _BT_NOTE_B="Adds output to the end of a file without overwriting it"
            _BT_NOTE_I="# > overwrites >> appends" ;;
        *discard*output*|*silent*|*dev*null*)
            _BT_CMD="command > /dev/null 2>&1"
            _BT_NOTE_B="Runs a command silently — discards all output"
            _BT_NOTE_I="# /dev/null = black hole for output" ;;
        *store*output*|*command*result*|*subshell*)
            _BT_CMD='result=$(command)'
            _BT_NOTE_B="Runs a command and stores its output in a variable"
            _BT_NOTE_I='# result=$(date) stores todays date' ;;
        *check*syntax*|*test*script*)
            _BT_CMD="zsh -n script.zsh"
            _BT_NOTE_B="Checks a script for syntax errors without running it"
            _BT_NOTE_I="# -n = no-exec, syntax check only" ;;
        *run*script*|*execute*script*)
            _BT_CMD="./script.sh"
            _BT_NOTE_B="Runs a script in the current folder (must be executable first)"
            _BT_NOTE_I="# chmod +x script.sh to make it executable" ;;
        *count*line*|*how*many*line*|*wc\ *|*word*count*|*line*count*)
            _BT_CMD="wc -l file.txt"
            _BT_NOTE_B="Counts lines in a file — -w counts words, -c counts characters"
            _BT_NOTE_I="# -l=lines -w=words -c=chars" ;;
        *compar*file*|*diff*file*|*differ*file*)
            _BT_CMD="diff file1.txt file2.txt"
            _BT_NOTE_B="Shows the differences between two files line by line"
            _BT_NOTE_I="# < =file1 only > =file2 only" ;;
        *file*exist*|*check*exist*|*does*file*exist*)
            _BT_CMD="[[ -f file.txt ]] && echo exists || echo missing"
            _BT_NOTE_B="Checks if a file exists — use -d for directories"
            _BT_NOTE_I="# -f=file -d=dir -e=either" ;;
        *symlink*|*symbolic*link*|*soft*link*|*ln\ *)
            _BT_CMD="ln -s /path/to/original /path/to/link"
            _BT_NOTE_B="Creates a shortcut (symlink) that points to another file or folder"
            _BT_NOTE_I="# -s=symbolic readlink -f shows real path" ;;
        *newest*file*|*latest*file*|*most*recent*file*|*last*modif*)
            _BT_CMD="ls -lt | head -5"
            _BT_NOTE_B="Lists the 5 most recently modified files, newest first"
            _BT_NOTE_I="# -t=sort by time -r=reverse (oldest first)" ;;
        *oldest*file*)
            _BT_CMD="ls -ltr | head -5"
            _BT_NOTE_B="Lists the 5 oldest files, oldest first"
            _BT_NOTE_I="# -r=reverse of -t (time sort)" ;;
        *hidden*file*|*show*dot*file*|*list*hidden*)
            _BT_CMD="ls -la | grep '^\\.'"
            _BT_NOTE_B="Lists only hidden files (those starting with a dot)"
            _BT_NOTE_I="# ls -la shows all, dotfiles start with ." ;;
        *watch*file*change*|*monitor*file*)
            _BT_CMD="fswatch -o file.txt | xargs -n1 -I{} echo 'changed'"
            _BT_NOTE_B="Watches a file and runs a command when it changes (macOS)"
            _BT_NOTE_I="# brew install fswatch first" ;;
        *open*finder*|*open*folder*finder*|*reveal*finder*)
            _BT_CMD="open ."
            _BT_NOTE_B="Opens the current folder in Finder"
            _BT_NOTE_I="# open /path/to/folder for any folder" ;;
        *open*url*|*open*browser*|*launch*url*)
            _BT_CMD="open https://example.com"
            _BT_NOTE_B="Opens a URL in your default browser"
            _BT_NOTE_I="# open also works on files and apps" ;;
        *ip*address*|*my*ip*|*what*ip*|*ifconfig*|*network*interface*)
            _BT_CMD="ipconfig getifaddr en0"
            _BT_NOTE_B="Shows your local IP address (en0=WiFi, en1=Ethernet on Mac)"
            _BT_NOTE_I="# ifconfig for all interfaces" ;;
        *public*ip*|*external*ip*)
            _BT_CMD="curl -s ifconfig.me"
            _BT_NOTE_B="Shows your public IP address as seen from the internet"
            _BT_NOTE_I="# requires internet connection" ;;
        *port*open*|*what*port*|*port*listen*)
            _BT_CMD="lsof -i -P | grep LISTEN"
            _BT_NOTE_B="Shows which ports are open and which programs are using them"
            _BT_NOTE_I="# -i=network -P=port numbers not names" ;;
        *flush*dns*|*clear*dns*|*dns*cache*)
            _BT_CMD="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
            _BT_NOTE_B="Clears the DNS cache on macOS — fixes 'site not found' errors"
            _BT_NOTE_I="# needs sudo (admin password)" ;;
        *wifi*network*|*current*wifi*|*connected*wifi*)
            _BT_CMD="networksetup -getairportnetwork en0"
            _BT_NOTE_B="Shows which WiFi network you're connected to"
            _BT_NOTE_I="# en0 is usually the WiFi interface on Mac" ;;
        *ssh*tunnel*|*forward*port*|*tunnel*)
            _BT_CMD="ssh -L 8080:localhost:80 user@remote"
            _BT_NOTE_B="Forwards remote port 80 to your local port 8080 via SSH"
            _BT_NOTE_I="# -L local:remote -R reverse tunnel" ;;
        *copy*remote*|*scp*|*send*file*server*)
            _BT_CMD="scp file.txt user@host:/path/"
            _BT_NOTE_B="Copies a file to a remote server over SSH"
            _BT_NOTE_I="# -r for folders scp user@host:file . to download" ;;
        *local*server*|*http*server*|*web*server*)
            _BT_CMD="python3 -m http.server 8000"
            _BT_NOTE_B="Starts a simple web server in the current folder on port 8000"
            _BT_NOTE_I="# visit http://localhost:8000 in browser" ;;
        *copy*clipboard*|*pbcopy*|*clipboard*)
            _BT_CMD="echo 'text' | pbcopy"
            _BT_NOTE_B="Copies text to the clipboard — paste anywhere with Cmd+V"
            _BT_NOTE_I="# cat file.txt | pbcopy to copy a file" ;;
        *paste*clipboard*|*pbpaste*|*from*clipboard*)
            _BT_CMD="pbpaste"
            _BT_NOTE_B="Prints what's currently in your clipboard"
            _BT_NOTE_I="# pbpaste > file.txt to save to file" ;;
        *lowercase*|*upper*lower*|*convert*case*)
            _BT_CMD="echo 'TEXT' | tr '[:upper:]' '[:lower:]'"
            _BT_NOTE_B="Converts text to lowercase using tr"
            _BT_NOTE_I="# swap args for uppercase" ;;
        *trim*whitespace*|*remove*space*|*strip*space*)
            _BT_CMD="echo '  text  ' | xargs"
            _BT_NOTE_B="Removes leading and trailing whitespace from text"
            _BT_NOTE_I="# xargs trims whitespace as a side effect" ;;
        *string*length*|*length*of*string*)
            _BT_CMD='str="hello"; echo ${#str}'
            _BT_NOTE_B="Gets the length of a string using \${#variable}"
            _BT_NOTE_I="# \${#var} = character count" ;;
        *base64*encode*|*encode*base64*)
            _BT_CMD="echo 'text' | base64"
            _BT_NOTE_B="Encodes text as base64 — used for tokens and file transfers"
            _BT_NOTE_I="# base64 -d to decode" ;;
        *random*password*|*generate*password*|*random*string*)
            _BT_CMD="openssl rand -base64 16"
            _BT_NOTE_B="Generates a random 16-character password"
            _BT_NOTE_I="# change 16 for longer/shorter" ;;
        *math*|*calculat*|*arithmetic*)
            _BT_CMD="echo $((2 + 2))"
            _BT_NOTE_B="Does arithmetic in the shell — supports + - * / and %"
            _BT_NOTE_I="# \$(( expr )) for any math" ;;
        *sudo*|*admin*|*run*admin*|*run*root*)
            _BT_CMD="sudo command"
            _BT_NOTE_B="Runs a command as admin — it will ask for your password"
            _BT_NOTE_I="# sudo -i for a full root shell" ;;
        *shutdown*|*turn*off*|*power*off*)
            _BT_CMD="sudo shutdown -h now"
            _BT_NOTE_B="Shuts down the Mac immediately"
            _BT_NOTE_I="# -h=halt -r=restart +5 in 5 min" ;;
        *restart*|*reboot*)
            _BT_CMD="sudo shutdown -r now"
            _BT_NOTE_B="Restarts the Mac immediately"
            _BT_NOTE_I="# or: sudo reboot" ;;
        *sleep*mac*|*sleep*computer*|*put*sleep*)
            _BT_CMD="pmset sleepnow"
            _BT_NOTE_B="Puts the Mac to sleep immediately"
            _BT_NOTE_I="# sudo pmset for system-wide settings" ;;
        *lock*screen*|*lock*mac*)
            _BT_CMD="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
            _BT_NOTE_B="Locks the screen — same as Ctrl+Cmd+Q"
            _BT_NOTE_I="# or press Ctrl+Cmd+Q" ;;
        *screenshot*|*screen*capture*|*screen*shot*)
            _BT_CMD="screencapture ~/Desktop/screenshot.png"
            _BT_NOTE_B="Takes a screenshot and saves it to your Desktop"
            _BT_NOTE_I="# -i=interactive -c=clipboard" ;;
        *empty*trash*|*clear*trash*)
            _BT_CMD="rm -rf ~/.Trash/*"
            _BT_NOTE_B="Empties the Trash — WARNING: permanent, no undo"
            _BT_NOTE_I="# same as Finder empty trash" ;;
        *force*quit*|*app*not*respond*|*kill*app*)
            _BT_CMD="pkill -f AppName"
            _BT_NOTE_B="Force quits an app by name — same as Cmd+Option+Esc"
            _BT_NOTE_I="# pkill -9 -f AppName for stubborn apps" ;;
        *mount*drive*|*mount*disk*|*list*mount*|*mounted*drive*)
            _BT_CMD="diskutil list"
            _BT_NOTE_B="Lists all mounted drives and partitions on macOS"
            _BT_NOTE_I="# diskutil info /dev/disk0 for details" ;;
        *monitor*process*|*watch*process*|*cpu*usage*)
            _BT_CMD="top -o cpu"
            _BT_NOTE_B="Shows live CPU usage, sorted by most CPU first"
            _BT_NOTE_I="# q=quit k=kill process" ;;
        *check*command*|*command*exist*|*installed*)
            _BT_CMD="command -v node"
            _BT_NOTE_B="Checks if a command is installed — shows its path if found"
            _BT_NOTE_I="# returns nothing if not found" ;;
        *node*version*|*check*node*)
            _BT_CMD="node --version"
            _BT_NOTE_B="Shows which version of Node.js is installed"
            _BT_NOTE_I="# nvm list to see installed versions" ;;
        *python*version*|*check*python*)
            _BT_CMD="python3 --version"
            _BT_NOTE_B="Shows which version of Python 3 is installed"
            _BT_NOTE_I="# python3 on macOS, python on Linux" ;;
        *run*python*|*python*file*|*python*script*)
            _BT_CMD="python3 script.py"
            _BT_NOTE_B="Runs a Python script"
            _BT_NOTE_I="# -m module to run a module" ;;
        *list*brew*|*installed*package*|*brew*list*)
            _BT_CMD="brew list"
            _BT_NOTE_B="Lists all packages installed via Homebrew"
            _BT_NOTE_I="# brew list --versions to see versions" ;;
        *install*homebrew*|*get*homebrew*)
            _BT_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            _BT_NOTE_B="Installs Homebrew — the macOS package manager"
            _BT_NOTE_I="# one-line installer from homebrew.sh" ;;
        *what*shell*|*current*shell*|*which*shell*)
            _BT_CMD="echo $SHELL"
            _BT_NOTE_B="Shows your current default shell (e.g. /bin/zsh)"
            _BT_NOTE_I="# echo \$0 shows the running shell" ;;
        *change*shell*|*default*shell*|*set*shell*)
            _BT_CMD="chsh -s $(which zsh)"
            _BT_NOTE_B="Changes your default shell to zsh"
            _BT_NOTE_I="# log out and back in for it to take effect" ;;
        *set*variable*|*print*variable*|*echo*variable*)
            _BT_CMD='VAR="hello"; echo "$VAR"'
            _BT_NOTE_B="Sets a variable and prints it — use \$ to read a variable"
            _BT_NOTE_I="# export VAR to share with child processes" ;;
        *cron*job*|*schedule*task*|*crontab*)
            _BT_CMD="crontab -e"
            _BT_NOTE_B="Opens your cron schedule for editing — runs tasks automatically"
            _BT_NOTE_I="# format: min hour day month weekday command" ;;
        *list*cron*|*see*cron*|*cron*schedule*)
            _BT_CMD="crontab -l"
            _BT_NOTE_B="Lists your current scheduled cron jobs"
            _BT_NOTE_I="# crontab -r to remove all" ;;
        *save*work*|*save*changes*|*commit*work*)
            _BT_CMD="git add . && git commit -m 'WIP'"
            _BT_NOTE_B="Saves all your current changes to git with a 'WIP' message"
            _BT_NOTE_I="# stage all + commit" ;;
        *test*internet*|*test*connection*|*am*i*online*)
            _BT_CMD="ping -c 3 8.8.8.8"
            _BT_NOTE_B="Tests your internet connection by pinging Google's DNS server"
            _BT_NOTE_I="# -c 3 = send 3 packets" ;;
        *how*much*space*|*storage*space*|*check*space*)
            _BT_CMD="df -h /"
            _BT_NOTE_B="Shows how much disk space is free on your main drive"
            _BT_NOTE_I="# / = root drive -h = human readable" ;;
        *what*using*cpu*|*cpu*usage*|*high*cpu*)
            _BT_CMD="top -o cpu -l 1 | head -20"
            _BT_NOTE_B="Shows the top processes using the most CPU right now"
            _BT_NOTE_I="# -o cpu = sort by cpu -l 1 = one snapshot" ;;
        *copy*folder*|*duplicat*folder*)
            _BT_CMD="cp -r source/ dest/"
            _BT_NOTE_B="Copies an entire folder and everything inside it"
            _BT_NOTE_I="# -r = recursive (required for folders)" ;;
        *install*npm*|*npm*package*|*node*package*)
            _BT_CMD="npm install packagename"
            _BT_NOTE_B="Installs a Node.js package into your current project"
            _BT_NOTE_I="# -g to install globally" ;;
        *reload*terminal*|*reload*shell*|*restart*shell*)
            _BT_CMD="source ~/.zshrc"
            _BT_NOTE_B="Reloads your shell config without closing the terminal"
            _BT_NOTE_I="# same as opening a new terminal" ;;
        *what*did*i*change*|*what*changed*|*show*diff*)
            _BT_CMD="git diff"
            _BT_NOTE_B="Shows exactly what lines you have changed but not yet saved to git"
            _BT_NOTE_I="# --staged to see staged changes" ;;
        *stash*|*save*for*later*|*put*aside*)
            _BT_CMD="git stash"
            _BT_NOTE_B="Puts your current changes aside so you can work on something else"
            _BT_NOTE_I="# git stash pop to bring them back" ;;
        *clone*|*download*repo*|*get*repo*)
            _BT_CMD="git clone https://github.com/user/repo"
            _BT_NOTE_B="Downloads a full copy of a git repository to your machine"
            _BT_NOTE_I="# --depth 1 for faster shallow clone" ;;
        *push*github*|*upload*github*|*push*remote*)
            _BT_CMD="git push origin main"
            _BT_NOTE_B="Uploads your commits to GitHub on the main branch"
            _BT_NOTE_I="# -u origin main to set upstream first time" ;;
        *pull*latest*|*get*latest*|*update*repo*)
            _BT_CMD="git pull"
            _BT_NOTE_B="Downloads and merges the latest changes from the remote"
            _BT_NOTE_I="# git fetch if you just want to check" ;;
        *apt*get*|*apt\ install*|*dnf*|*yum*|*pacman*)
            _BT_CMD="brew install packagename"
            _BT_NOTE_B="That command is Linux-only. On macOS use Homebrew instead"
            _BT_NOTE_I="# brew install replaces apt-get on macOS" ;;
        *help*|*what*can*|*example*)
            _BT_CMD=""
            _bt_help
            return 1 ;;
        *)
            return 1 ;;
    esac
    return 0
}

# ── display result ────────────────────────────────────────────────────────────
function _bt_display() {
    local level="${BASHTUTOR_LEVEL:-beginner}"
    printf "${_OR} =^.^= ${_B}%s${_R}\n" "$_BT_CMD"
    case "$level" in
        beginner)
            [[ -n "$_BT_NOTE_B" ]] && _bt_note "$_BT_NOTE_B"
            ;;
        intermediate)
            [[ -n "$_BT_NOTE_I" ]] && _bt_note "$_BT_NOTE_I"
            ;;
        expert) ;;
    esac
    echo ""
    printf "  Run it? [Y/n] "
    read -r _bt_run_ans
    [[ "$_bt_run_ans" != [nN] ]] && eval "$_BT_CMD"
}

# ── qq ────────────────────────────────────────────────────────────────────────
function qq() {
    local query="$*"
    # Warn if query contains shell syntax
    if [[ "$query" =~ '[|><&;]' ]]; then
        printf "${_CY} =-.^= Don't include shell syntax (| > & ;) in qq — just describe what you want${_R}\n"
        printf "${_CY}  e.g. 'qq show files sorted by size' not 'qq ls | sort'${_R}\n"
        return 1
    fi
    # Strip punctuation
    query="${query//[?!.,\'\"]/}"

    if [[ "$1" == "level" && -n "$2" ]]; then
        case "$2" in
            beginner|intermediate|expert)
                BASHTUTOR_LEVEL="$2"
                echo "BASHTUTOR_LEVEL=$2" > "$BASHTUTOR_CONFIG"
                printf "${_DG}  Level: %s${_R}\n" "$2"
                return 0 ;;
            *)
                _bt_err "Level must be: beginner, intermediate, or expert"
                return 1 ;;
        esac
    fi

    # No args: show single-line hint instead of full help
    if [[ -z "$query" ]]; then
        printf "${_OR} =-.^= ${_R}Type ${_OR}qq <question>${_R} or ${_OR}qq help${_R} for examples\n"
        return 0
    fi

    [[ "$query" == "help" || "$query" == "--help" ]] && { _bt_help; return 0; }

    # Single common-word handler — suggest more context
    case "$query" in
        show)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq show files${_R} / ${_OR}qq show ports${_R} / ${_OR}qq show disk space${_R}\n"; return 0 ;;
        make)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq make folder${_R} / ${_OR}qq make file${_R} / ${_OR}qq make script executable${_R}\n"; return 0 ;;
        get)    printf "${_OR} =-.^= ${_R}Try: ${_OR}qq get ip address${_R} / ${_OR}qq get disk space${_R} / ${_OR}qq get file from url${_R}\n"; return 0 ;;
        find)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq find files${_R} / ${_OR}qq find text${_R} / ${_OR}qq find large files${_R}\n"; return 0 ;;
        open)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq open finder${_R} / ${_OR}qq open file in editor${_R} / ${_OR}qq open url${_R}\n"; return 0 ;;
        run)    printf "${_OR} =-.^= ${_R}Try: ${_OR}qq run script${_R} / ${_OR}qq run python file${_R} / ${_OR}qq run as admin${_R}\n"; return 0 ;;
        check)  printf "${_OR} =-.^= ${_R}Try: ${_OR}qq check disk space${_R} / ${_OR}qq check ports${_R} / ${_OR}qq check node version${_R}\n"; return 0 ;;
        list)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq list files${_R} / ${_OR}qq list processes${_R} / ${_OR}qq list installed packages${_R}\n"; return 0 ;;
        delete) printf "${_OR} =-.^= ${_R}Try: ${_OR}qq delete file${_R} / ${_OR}qq delete folder${_R} / ${_OR}qq delete git branch${_R}\n"; return 0 ;;
        copy)   printf "${_OR} =-.^= ${_R}Try: ${_OR}qq copy file${_R} / ${_OR}qq copy to clipboard${_R} / ${_OR}qq copy file to remote${_R}\n"; return 0 ;;
    esac

    # Short query handler (1-2 words, no verb matched above)
    local word_count
    word_count=$(echo "$query" | wc -w | tr -d ' ')
    if [[ "$word_count" -le 2 ]]; then
        printf "${_OR} =-.^= ${_R}Try adding more context: e.g. '${_OR}qq [action] [thing]${_R}' — or try ${_OR}qq help${_R} for examples\n"
        return 0
    fi

    _bt_lookup "$query" || {
        printf "${_OR} =-.^= ${_CY} not sure about '%s'${_R}\n" "$query"
        printf "${_CY}  Try rephrasing — for example:${_R}\n"
        printf "${_GH}    • use a verb + object  (e.g. 'compress folder', 'delete file')${_R}\n"
        printf "${_GH}    • name the tool        (e.g. 'git undo last commit')${_R}\n"
        printf "${_GH}    • describe the goal    (e.g. 'show open ports', 'find large files')${_R}\n"
        printf "${_CY}  Or run: ${_OR}man <command>${_CY} for manual pages.${_R}\n\n"
        return 1
    }
    _bt_display
}

# ── explain last command (Ctrl+B) ─────────────────────────────────────────────
typeset -gA BASHTUTOR_EXPLANATIONS
BASHTUTOR_EXPLANATIONS=(
    ls "Listed files and directories" ll "Listed files with details"
    la "Listed all files including hidden" cd "Changed directory"
    pwd "Showed current directory" mkdir "Created a directory"
    rm "Deleted files or directories" cp "Copied files"
    mv "Moved or renamed files" touch "Created or updated a file"
    cat "Printed file contents" less "Opened file for scrolling"
    head "Showed start of file" tail "Showed end of file"
    grep "Searched for text patterns" find "Found files by criteria"
    chmod "Changed file permissions" chown "Changed file ownership"
    sudo "Ran with admin privileges" ssh "Connected to remote server"
    curl "Fetched URL data" wget "Downloaded a file"
    tar "Archived or extracted files" zip "Created zip archive"
    unzip "Extracted zip archive" git "Ran git command"
    npm "Ran npm command" pip3 "Installed Python package"
    docker "Ran Docker command" brew "Ran Homebrew"
    ps "Listed running processes" kill "Stopped a process"
    top "Viewed live system stats" df "Showed disk space"
    du "Showed directory sizes" ping "Tested network connectivity"
    echo "Printed text to screen" export "Set environment variable"
    source "Reloaded shell config" man "Opened manual page"
    history "Showed command history" clear "Cleared screen"
    which "Found command location" date "Showed date and time"
    whoami "Showed username" uname "Showed system info"
    nano "Opened file in editor" vi "Opened file in vi editor"
    sed "Edited text with patterns" awk "Processed text fields"
    sort "Sorted lines" uniq "Removed duplicate lines"
    wc "Counted lines/words/chars" diff "Compared two files"
    rsync "Synced files between locations" scp "Copied files to/from remote"
)

function _bt_explain_last() {
    local cmd="${_BT_LAST_CMD:-$(fc -ln -1 2>/dev/null | sed 's/^ *//')}"
    if [[ -z "$cmd" ]]; then
        printf "\n${_RE}  No previous command${_R}\n"
        zle redisplay 2>/dev/null
        return
    fi
    local base="${cmd%% *}"
    local expl="${BASHTUTOR_EXPLANATIONS[$base]:-Ran: $base}"
    printf "\n${_CY}  ❯ %s${_R}\n${_OR}  %s${_R}\n\n" "$cmd" "$expl"
    zle redisplay 2>/dev/null
}
zle -N _bt_explain_last
bindkey '^B' _bt_explain_last

# ── help screen ───────────────────────────────────────────────────────────────
function _bt_help() {
    printf "\n${_OR}${_B}❯ BashTutor${_R}  Level: ${_DG}%s${_R}\n\n" "$BASHTUTOR_LEVEL"
    printf "${_B}Usage:${_R}\n"
    printf "  qq <question>           ask in plain English\n"
    printf "  bt <question>           same, shorter alias\n"
    printf "  bashme <question>       same\n"
    printf "  qq level beginner       set response level\n"
    printf "  qq level intermediate\n"
    printf "  qq level expert\n"
    printf "\n${_B}Keybindings:${_R}\n"
    printf "  Ctrl+B                  explain last command\n"
    printf "  Right arrow / Tab       accept ghost suggestion\n"
    printf "\n${_B}Examples:${_R}\n"
    printf "  qq list all files\n"
    printf "  qq find files modified today\n"
    printf "  qq compress a folder\n"
    printf "  qq git save changes\n"
    printf "  qq how do I redirect output\n"
    printf "  qq show open ports\n"
    printf "  qq docker list running containers\n"
    printf "  qq kill process on port 3000\n"
    printf "  qq download a file from url\n"
    printf "  qq create a python virtual environment\n"
    printf "  qq git undo last commit\n"
    printf "  qq search text in all files recursively\n"
    printf "  qq ssh tunnel to remote server\n"
    printf "\n${_B}Levels:${_R}\n"
    printf "  ${_DG}beginner${_R}      plain English + command\n"
    printf "  ${_DG}intermediate${_R}  command + brief note\n"
    printf "  ${_DG}expert${_R}        command only\n\n"
}

# ── hooks & aliases ───────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook preexec _bt_preexec

alias bt='qq'
alias bashme='qq'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ll='ls -la'
alias la='ls -la'
alias lt='ls -lt'
alias lth='ls -lt | head -20'
alias ports='lsof -i -P | grep LISTEN'
alias myip='ipconfig getifaddr en0'
alias pubip='curl -s ifconfig.me'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias hosts='sudo nano /etc/hosts'
alias zshrc='nano ~/.zshrc'
alias reload='source ~/.zshrc'
alias hist='history | tail -30'
alias path='echo $PATH | tr ":" "\n"'
alias week='date +%V'
alias now='date +"%T"'
alias today='date +"%Y-%m-%d"'
