# 🎓 BashTutor

BashTutor is a zsh plugin that helps you learn bash by explaining what each command does — right when you run it. It's designed for dyslexic learning patterns and makes the terminal friendlier for beginners. Type commands in plain English with `bashme`, get instant explanations for every command you run, and build your confidence one command at a time.

---

## ⚡ Installation

```bash
# Clone or download the repository
git clone https://github.com/adamturton/bashtutor.git
cd bashtutor

# Run the installer
./install.sh

# Restart your terminal or run:
source ~/.zshrc
```

For AI-powered explanations, set your Anthropic API key:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Without the API key, BashTutor will use local pattern matching for common commands.

---

## 🚀 Quick Start

```bash
# Get a command from plain English
bashme show me files modified today

# Explain what a command does
bashme find files larger than 100MB

# Toggle automatic explanations for every command
bashtutor_toggle
```

---

## ⚙️ Configuration

Edit `~/.bashtutor/config` to customise your experience:

```bash
# ~/.bashtutor/config

# Auto-explain every command (0 = off, 1 = on)
# BASHTUTOR_AUTO_EXPLAIN=0

# Maximum cache age in hours (default: 24)
# BASHTUTOR_CACHE_TTL=24

# Maximum history entries to keep (default: 1000)
# BASHTUTOR_MAX_HISTORY=1000

# Enable verbose logging (default: 0)
# BASHTUTOR_VERBOSE=0
```

**Environment Variables:**
- `ANTHROPIC_API_KEY`: Your Anthropic API key for Claude-powered explanations (optional but recommended)
- `BASHTUTOR_AUTO_EXPLAIN`: Set to 1 to auto-explain every command

---

## 🛠️ Troubleshooting

### Issue: `command not found: bashme`

**Fix:** Restart your terminal or run `source ~/.zshrc` to load the plugin.

---

### Issue: Explanations are slow or timing out

**Fix:** If using Claude API, check your `ANTHROPIC_API_KEY` is set correctly:
```bash
echo $ANTHROPIC_API_KEY  # Should show your key
```

If the API is slow, BashTutor will fall back to local pattern-based explanations automatically (no waiting).

---

### Issue: History not being saved

**Fix:** Ensure the config directory exists: `mkdir -p ~/.bashtutor`. Check `history_enabled` is set to `true` in your config file.

---

## 📋 Requirements

- **OS:** macOS (Intel or Apple Silicon)
- **Shell:** zsh 5.0+
- **Optional (but recommended):** Anthropic API key for Claude-powered explanations
  - Get a free key at https://console.anthropic.com/

## 🚀 Getting Started

1. **Install the plugin** (see Installation above)
2. **Set your API key** (optional but recommended):
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```
3. **Try a command:**
   ```bash
   bashme show files modified today
   ```
4. **Toggle auto-explanations:**
   ```bash
   bashtutor_toggle
   ```
5. **View your history:**
   ```bash
   bashtutor_history
   ```

## 🎯 Key Features

- **Plain English to bash:** Just describe what you want to do
- **Auto-explanations:** Every command is explained (optional)
- **Smart fallback:** Uses local patterns if API isn't available
- **Command history:** Tracks all your commands with timestamps
- **Offline ready:** Works without API key using pattern matching
- **Dyslexia-friendly:** Simple emoji-based UI, plain language
