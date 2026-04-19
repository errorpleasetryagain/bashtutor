# BashTutor Production Build

## Source Files
- Main module: /Users/adam.turton/.openclaw/workspace/projects/bashtutor/src/bashtutor.zsh
- Installer: /Users/adam.turton/.openclaw/workspace/projects/bashtutor/install.sh

## Critical Issues from Debug
1. JSON Safety: Commands with quotes/newlines corrupt history.jsonl
2. Performance: explanations array rebuilt every call (~70 hash assignments)
3. install.sh: install_embedded() referenced before defined

## Production Requirements
1. Config file ~/.bashtutor/config (mode, timeout, history_enabled, keybind)
2. JSON escaping function (handle ", \\, newlines)
3. Key binding Ctrl+B for explain-last-command
4. Cache openclaw responses (24h TTL)
5. README.md with usage/troubleshooting
6. uninstall.sh for clean removal

## Test Commands
- echo "hello 'world'"
- echo "say \"hi\""  
- git commit -m "fix: handle \"quoted\" strings"

