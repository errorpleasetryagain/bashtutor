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
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null 2>&1; then
    _R=$(tput sgr0); _B=$(tput bold)
    _CY=$(tput setaf 6); _GR=$(tput setaf 2); _YE=$(tput setaf 3)
    _MG=$(tput setaf 5); _RE=$(tput setaf 1); _BL=$(tput setaf 4)
else
    _R="" _B="" _CY="" _GR="" _YE="" _MG="" _RE="" _BL=""
fi

_bt_cmd()  { printf "${_BL}${_B}  %s${_R}\n" "$*"; }
_bt_note() { printf "${_CY}  %s${_R}\n" "$*"; }
_bt_warn() { printf "${_YE}  ⚠  %s${_R}\n" "$*"; }
_bt_err()  { printf "${_RE}  ✗ %s${_R}\n" "$*" >&2; }

# ── boot line ─────────────────────────────────────────────────────────────────
printf "${_CY}${_B}❯ BashTutor${_R} ${_YE}[%s]${_R}  type ${_BL}qq help${_R} to start\n" "$BASHTUTOR_LEVEL"

# ── ghost complete from history (Ctrl+F) ──────────────────────────────────────
function _bt_history_complete() {
    local prefix="$BUFFER"
    [[ -z "$prefix" ]] && return
    local match
    match=$(fc -lnr 1 2>/dev/null | grep -m1 "^${prefix}") || return
    [[ -z "$match" || "$match" == "$prefix" ]] && return
    BUFFER="$match"
    CURSOR=${#BUFFER}
    zle redisplay
}
zle -N _bt_history_complete
bindkey '^F' _bt_history_complete

# ── destructive command warning ───────────────────────────────────────────────
function _bt_preexec() {
    export _BT_LAST_CMD="$1"
    local cmd="$1"
    case "$cmd" in
        rm\ -rf*|rm\ -fr*|dd\ if=*|mkfs*|shred\ *|chmod\ -R\ 777*)
            printf "${_RE}${_B}  ⚠  Destructive: %s${_R}\n  Continue? [y/N] " "$cmd"
            read -r _bt_ans
            [[ "$_bt_ans" != [yY] ]] && return 1
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
# FILES & DIRECTORIES
        *list*file*|*show*file*|*what*here*|*ls\ *)
            _BT_CMD="ls -la"
            _BT_NOTE_B="Lists every file here, including hidden ones (starting with .)"
            _BT_NOTE_I="# -l=details -a=hidden files" ;;
        *new*file*|*creat*file*|*touch\ *)
            _BT_CMD="touch filename.txt"
            _BT_NOTE_B="Creates an empty file (updates timestamp if it exists)"
            _BT_NOTE_I="# creates or refreshes timestamp" ;;
        *creat*folder*|*creat*dir*|*new*folder*|*mkdir\ *)
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
# TEXT VIEWING
        *view*file*|*read*file*|*print*file*|*show*content*|*cat\ *)
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
        *edit*file*|*open*editor*|*nano*)
            _BT_CMD="nano file.txt"
            _BT_NOTE_B="Opens a file in nano editor — Ctrl+O saves, Ctrl+X exits"
            _BT_NOTE_I="# ^O=save ^X=exit ^W=find" ;;
# SEARCH
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
# DISK & SPACE
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
# ARCHIVES
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
# PERMISSIONS
        *permiss*|*chmod*|*who*can*)
            _BT_CMD="chmod 755 file"
            _BT_NOTE_B="Sets permissions: 7=owner all, 5=others read+run — think rwx"
            _BT_NOTE_I="# 4=read 2=write 1=exec; owner/group/others" ;;
        *make*executable*|*run*script*chmod*)
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
# PROCESSES
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
# NETWORKING
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
# ENVIRONMENT & SHELL
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
# GIT
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
# BREW / NPM / PYTHON / DOCKER
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
# SYSTEM
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
# SCRIPTING
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
# FILES — ADVANCED
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
# NETWORKING
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
# CLIPBOARD & TEXT
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
# SYSTEM — macOS
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
# PROCESSES & MONITORING
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
# SHELL & ENVIRONMENT
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
# CRON
        *cron*job*|*schedule*task*|*crontab*)
            _BT_CMD="crontab -e"
            _BT_NOTE_B="Opens your cron schedule for editing — runs tasks automatically"
            _BT_NOTE_I="# format: min hour day month weekday command" ;;
        *list*cron*|*see*cron*|*cron*schedule*)
            _BT_CMD="crontab -l"
            _BT_NOTE_B="Lists your current scheduled cron jobs"
            _BT_NOTE_I="# crontab -r to remove all" ;;
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
    echo ""
    case "$level" in
        beginner)
            [[ -n "$_BT_NOTE_B" ]] && _bt_note "$_BT_NOTE_B"
            _bt_cmd "$_BT_CMD"
            ;;
        intermediate)
            _bt_cmd "$_BT_CMD"
            [[ -n "$_BT_NOTE_I" ]] && _bt_note "$_BT_NOTE_I"
            ;;
        expert)
            _bt_cmd "$_BT_CMD"
            ;;
    esac
    echo ""
    printf "  Run it? [y/N] "
    read -r _bt_run_ans
    [[ "$_bt_run_ans" == [yY] ]] && eval "$_BT_CMD"
}

# ── qq ────────────────────────────────────────────────────────────────────────
function qq() {
    local query="$*"

    if [[ "$1" == "level" && -n "$2" ]]; then
        case "$2" in
            beginner|intermediate|expert)
                BASHTUTOR_LEVEL="$2"
                echo "BASHTUTOR_LEVEL=$2" > "$BASHTUTOR_CONFIG"
                printf "${_GR}  Level: %s${_R}\n" "$2"
                return 0 ;;
            *)
                _bt_err "Level must be: beginner, intermediate, or expert"
                return 1 ;;
        esac
    fi

    [[ "$query" == "help" || -z "$query" ]] && { _bt_help; return 0; }

    _bt_lookup "$query" || {
        _bt_err "No pattern found for: $query"
        printf "${_CY}  Try rephrasing — or: man <command>${_R}\n"
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
        printf "\n${_YE}  No previous command${_R}\n"
        zle redisplay 2>/dev/null
        return
    fi
    local base="${cmd%% *}"
    local expl="${BASHTUTOR_EXPLANATIONS[$base]:-Ran: $base}"
    printf "\n${_CY}  ❯ %s${_R}\n${_BL}  %s${_R}\n\n" "$cmd" "$expl"
    zle redisplay 2>/dev/null
}
zle -N _bt_explain_last
bindkey '^B' _bt_explain_last

# ── help screen ───────────────────────────────────────────────────────────────
function _bt_help() {
    printf "\n${_CY}${_B}❯ BashTutor${_R}  Level: ${_YE}%s${_R}\n\n" "$BASHTUTOR_LEVEL"
    printf "${_B}Usage:${_R}\n"
    printf "  qq <question>           ask in plain English\n"
    printf "  bt <question>           same, shorter alias\n"
    printf "  bashme <question>       same\n"
    printf "  qq level beginner       set response level\n"
    printf "  qq level intermediate\n"
    printf "  qq level expert\n"
    printf "\n${_B}Keybindings:${_R}\n"
    printf "  Ctrl+B                  explain last command\n"
    printf "  Ctrl+F                  complete from history\n"
    printf "\n${_B}Examples:${_R}\n"
    printf "  qq list all files\n"
    printf "  qq find files modified today\n"
    printf "  qq compress a folder\n"
    printf "  qq git save changes\n"
    printf "  qq how do I redirect output\n"
    printf "\n${_B}Levels:${_R}\n"
    printf "  ${_YE}beginner${_R}      plain English + command\n"
    printf "  ${_YE}intermediate${_R}  command + brief note\n"
    printf "  ${_YE}expert${_R}        command only\n\n"
}

# ── hooks & aliases ───────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook preexec _bt_preexec

alias bt='qq'
alias bashme='qq'
