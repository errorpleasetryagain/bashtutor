# 🎓 BashTutor

A macOS zsh plugin that teaches bash through doing — designed for dyslexic learning patterns. Type plain English, get bash commands. Run them, get plain English explanations.

Three editions:
- **OpenClaw** — uses your local OpenClaw AI (default, no API key needed)
- **Claude** — uses the Anthropic Claude API
- **Standalone** — no AI at all, works entirely offline with a built-in pattern library

---

## ⚡ One-line Install

Paste this into any terminal — it handles everything:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)"
```

The installer will:
- Check you have macOS and zsh (with platform-specific install instructions if not)
- Download BashTutor and install the plugin to `~/.bashtutor/`
- Wire it into your shell so it loads every time a terminal opens
- Run a syntax check and report pass/fail

Then **open a new terminal** (or run `source ~/.zshrc`).

---

### Claude API edition

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)" -- --claude
```

You'll also need an API key — get one free at [console.anthropic.com](https://console.anthropic.com), then add it:

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc && source ~/.zshrc
```

### Standalone edition (no AI, fully offline)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)" -- --standalone
```

### Other install flags

```bash
bash install.sh --uninstall   # remove everything cleanly
```

---

## 🍺 Install via Homebrew

```bash
brew tap errorpleasetryagain/bashtutor
brew install bashtutor
```

---

## 🚀 What It Does

### Plain English → bash command

```bash
qq show files modified today
qq find all pdfs in downloads
qq kill whatever is using port 3000
qq create a python virtual environment
```

`qq` is the main shortcut. `bt` and `bashme` also work. After a result appears, BashTutor asks `Run it? [y/N]` — press `y` to run the command directly.

### Three response levels

```bash
qq level beginner       # plain English explanation + command (default)
qq level intermediate   # command + short technical note
qq level expert         # command only
```

Level is saved between sessions.

### Ghost autocomplete while you type

As you type, grey suggestion text appears based on your command history. Press `→` or `Tab` to accept it. Works like Fish shell — no configuration needed. Ghost text activates after just one character.

### Explain any command

```bash
Ctrl+B    # explain the last command you ran
```

### Destructive command safety net

```bash
rm -rf somefolder    # BashTutor warns before this runs, asks for confirmation
```

Catches: `rm -rf`, `dd if=`, `mkfs`, `shred`, `chmod -R 777` — even if typed with leading spaces.

---

## 💡 Commands

| Command | What it does |
|---------|-------------|
| `qq <english>` | Translate plain English to bash |
| `bt <english>` | Same as `qq` |
| `bashme <english>` | Same as `qq` |
| `qq level beginner\|intermediate\|expert` | Change response detail level |
| `qq help` | Show usage and examples |
| `Ctrl+B` | Explain the last command you ran |
| `→` or `Tab` | Accept ghost text suggestion |

---

## ⚙️ Configuration

Edit `~/.bashtutor/config`:

```bash
# Auto-explain commands? (0 = off, 1 = on)
BASHTUTOR_AUTO_EXPLAIN=0

# Remember AI answers for how long? (hours)
BASHTUTOR_CACHE_TTL=24

# How many commands to keep in history
BASHTUTOR_MAX_HISTORY=1000

# Suggest next commands based on your habits? (0 = off, 1 = on)
BASHTUTOR_SMART_SUGGEST=0

# Show debug info? (0 = off, 1 = on)
BASHTUTOR_VERBOSE=0
```

---

## 🛠️ Troubleshooting

**`command not found: qq`**  
Run `source ~/.zshrc` or open a new terminal window.

**Claude edition: explanations are slow or not working**  
Check your API key is set: `echo $ANTHROPIC_API_KEY`  
BashTutor falls back to local patterns automatically if the API is unavailable.

**OpenClaw edition: "openclaw not found"**  
BashTutor uses its built-in local pattern library until you install OpenClaw. All core commands still work.

**Ghost text not appearing**  
Ghost text learns from your shell history. The more you use the terminal, the more suggestions appear. It activates after typing just one character.

---

## 📋 Requirements

- macOS (Intel or Apple Silicon)
- zsh 5.0+
- OpenClaw CLI (OpenClaw edition), Anthropic API key (Claude edition), or nothing (Standalone edition)

---

## 📁 Files installed

```
~/.bashtutor/
├── bashtutor.zsh    # active plugin (whichever edition you chose)
├── config           # your settings
└── cache/           # AI response cache
```

---

## 🔗 Links

- GitHub: [github.com/errorpleasetryagain/bashtutor](https://github.com/errorpleasetryagain/bashtutor)
- Homebrew tap: [github.com/errorpleasetryagain/homebrew-bashtutor](https://github.com/errorpleasetryagain/homebrew-bashtutor)
