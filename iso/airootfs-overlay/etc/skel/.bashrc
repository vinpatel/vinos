# vinOS default .bashrc — brand-accent starship prompt, sensible aliases.

# Only run in interactive shells
[[ $- != *i* ]] && return

# ─── History ───
HISTCONTROL=ignoredups:erasedups
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-}"

# ─── Sensible defaults ───
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell 2>/dev/null || true
shopt -s autocd 2>/dev/null || true

# ─── Aliases ───
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# ─── vinOS shortcuts ───
alias ai='vinos-ai chat'
alias routines='vinos-routine list'
alias brief='vinos-brief'
alias themes='vinos-theme-pick'

# ─── Prompt: starship (semantic, brand-accent) ───
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# ─── Editor ───
export EDITOR=nvim
export VISUAL=nvim

# ─── XDG paths ───
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ─── Path ───
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
