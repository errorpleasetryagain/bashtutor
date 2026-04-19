# 🎓 BashTutor

A macOS zsh plugin that teaches bash through doing — designed for dyslexic learning patterns. Type plain English, get bash commands. Run them, get plain English explanations. It watches your habits and gets smarter over time.

Two editions:
- **OpenClaw** — uses your local OpenClaw AI (default, no API key needed)
- **Claude** — uses the Anthropic Claude API

---

## ⚡ One-line Install

Paste this into any terminal — it handles everything:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)"
```

This will:
- Check you have macOS and zsh (and tell you how to get them if not)
- Clone BashTutor to `~/.bashtutor/`
- Wire it into your shell so it loads every time a terminal opens
- Activate it immediately

Then restart your terminal or run:
```bash
source ~/.zshrc
```

**Claude API edition** (uses Anthropic AI instead of OpenClaw):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)" -- --claude
```

You'll also need an API key — get one free at [console.anthropic.com](https://console.anthropic.com), then add it:
```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.zshrc && source ~/.zshrc
```

**Don't have zsh?** Run this first:
```bash
brew install zsh && chsh -s $(which zsh)
```
Then open a new terminal and run the install command above.

**Don't have Homebrew?** Run this first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
```
`qq` is the main shortcut. `bt` and `bashme` also work.

### Ghost autocomplete while you type
As you type, grey suggestion text appears based on your history. Press `→` or `Tab` to accept it. Works like Fish shell — no configuration needed. Gets smarter the more you use it.

### Explain any command
```bash
Ctrl+B                              # explain the last command you ran
```

### "what?" mode — paste anything and ask
```bash
qq find . -name "*.log" -mtime +7 -delete what?
# → Plain English explanation of what that command does
```

### Smart explanations
BashTutor watches what you run. It only explains commands that are new to you, failed, or look risky — not ones you already know.

### Destructive command safety net
```bash
rm -rf somefolder    # BashTutor warns you before this runs
```

### Python support
```bash
qq install pandas
qq run my script
qq create a virtual environment
```

---

## 💡 All Commands

| Command | What it does |
|---------|-------------|
| `qq <english>` | Translate plain English to bash (main shortcut) |
| `bt <english>` | Same as qq |
| `bashme <english>` | Same as qq (full name) |
| `Ctrl+B` | Explain the last command you ran |
| `btx <command>` | Explain any specific command |
| `bth` | Show your BashTutor command history |
| `bashtutor_status` | Show plugin status and config |
| `bashtutor_clear_cache` | Clear the AI response cache |

---

## ⚙️ Configuration

Edit `~/.bashtutor/config`:

```bash
# Auto-explain commands? (0 = off, 1 = on — only explains new/failed commands)
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

**`command not found: bashme`**
Run `source ~/.zshrc` or restart your terminal.

**Explanations are slow**
If using the Claude edition, check your API key: `echo $ANTHROPIC_API_KEY`
BashTutor falls back to local patterns automatically if the API is unavailable.

**Ghost text not appearing**
Ghost text needs at least 2 characters typed. It learns from your history so it gets better the more you use it.

**OpenClaw not found**
BashTutor will use local patterns offline. Install OpenClaw separately to enable AI features for the OpenClaw edition.

---

## 📋 Requirements

- macOS (Intel or Apple Silicon)
- zsh 5.0+
- OpenClaw CLI (OpenClaw edition) or Anthropic API key (Claude edition)

---

## 📁 Files

```
~/.bashtutor/
├── bashtutor.zsh       # the plugin (copied here by installer)
├── config              # your settings
├── history.jsonl       # command history
├── sequences           # learned command patterns (powers ghost text)
└── cache/              # AI response cache
```

---

## 🔗 Links

- GitHub: [github.com/errorpleasetryagain/bashtutor](https://github.com/errorpleasetryagain/bashtutor)
- Homebrew tap: [github.com/errorpleasetryagain/homebrew-bashtutor](https://github.com/errorpleasetryagain/homebrew-bashtutor)
