# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# ── zsh-autosuggestions e zsh-syntax-highlighting ──────────────────────────
#
# autosuggestions      sugere em cinza o comando mais recente do histórico que
#                      casa com o que você já digitou. → aceita a sugestão
#                      inteira, Ctrl+→ aceita só a próxima palavra.
# syntax-highlighting  colore a linha enquanto você digita: verde = comando
#                      existe, vermelho = não existe. Pega typo antes do Enter.
#
# Carregados aqui em vez de em plugins=(...) por dois motivos: o
# syntax-highlighting precisa ser o ÚLTIMO a envolver a linha de comando, e
# assim o zsh não reclama na abertura quando um deles não está instalado.
#
# Os dois podem vir do pacote do Arch (/usr/share/zsh/plugins) ou de um clone
# em ~/.oh-my-zsh/custom/plugins — a busca abaixo cobre os dois. Hoje o
# syntax-highlighting está como clone e o autosuggestions vem do pacote:
#   sudo pacman -S zsh-autosuggestions
#
# A ordem importa: autosuggestions antes de syntax-highlighting.
for _plug in zsh-autosuggestions zsh-syntax-highlighting; do
  for _dir in "/usr/share/zsh/plugins/$_plug" "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$_plug"; do
    if [[ -r "$_dir/$_plug.zsh" ]]; then
      source "$_dir/$_plug.zsh"
      break
    fi
  done
done
unset _plug _dir

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# ── Editor padrão ──────────────────────────────────────────────────────────
#
# Sem isso, tudo que abre um editor sozinho (git commit, git rebase -i,
# crontab -e, systemctl edit, visudo) cai no `vi` — que não é o seu nvim nem
# lê ~/.config/nvim.
#
# VISUAL é o que programas "de tela cheia" consultam primeiro; EDITOR é o
# fallback para os de linha. Definir os dois evita surpresas.
#
# Sobre SSH: nvim é um binário estático sem dependência de servidor gráfico,
# então funciona igual numa sessão remota. Se um dia precisar de algo mais
# leve lá, troque por:
#   [[ -n $SSH_CONNECTION ]] && export EDITOR='vim'
export EDITOR='nvim'
export VISUAL='nvim'

# Abre o pager do git, do man e do systemctl sem perder as cores e sem limpar
# a tela ao sair (-X), e sem paginar quando cabe numa tela só (-F).
export LESS='-FRX'

# ── nmtui, whiptail e outros TUIs do newt ──────────────────────────────────
#
# Sem esse arquivo o newt usa a paleta embutida dele, que pinta as janelas em
# "preto sobre cinza-claro" — dois slots que, no terminal tematizado, são
# praticamente a mesma cor, e o texto some. O arquivo é gerado por
# ~/.config/theme/apply.py e acompanha a variante ativa.
#
# O mesmo já está em hypr/conf/env.lua, que cobre o que a barra abre via
# `sh -c` (nenhum rc é lido ali). Aqui é para shell no TTY e por SSH.
export NEWT_COLORS_FILE="$HOME/.config/newt/palette"

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias c="clear"
alias mkdir="mkdir -p"

# ── Histórico ──────────────────────────────────────────────────────────────
#
# O oh-my-zsh deixa HISTSIZE em 50000 e SAVEHIST em 10000, o que é um
# desencontro: HISTSIZE é quanto fica na memória da sessão, SAVEHIST é quanto
# sobrevive em disco. Com os valores padrão, 40 mil comandos eram descartados
# ao fechar o terminal.
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history

setopt HIST_IGNORE_ALL_DUPS  # um comando repetido só ocupa uma linha
setopt HIST_REDUCE_BLANKS    # normaliza espaços antes de gravar
setopt HIST_VERIFY           # !! e !$ expandem na linha, não executam direto
setopt SHARE_HISTORY         # terminais abertos enxergam o histórico um do outro
setopt EXTENDED_HISTORY      # grava timestamp e duração de cada comando

export PATH="$HOME/.local/bin:$PATH"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# ╭──────────────────────────────────────────────────────────────────────────╮
# │  fastfetch ao abrir um terminal                                          │
# │                                                                          │
# │  Config visual: ~/.config/fastfetch/config.jsonc                         │
# │                                                                          │
# │  NÃO precisa configurar nada no kitty: ele abre o zsh, então este gancho │
# │  já cobre os dois. Duplicar no kitty faria imprimir duas vezes.          │
# │                                                                          │
# │  As quatro guardas abaixo existem para ele NÃO aparecer onde atrapalha:  │
# │                                                                          │
# │    -o interactive   pula em scripts e em `zsh -c "comando"`              │
# │    $FASTFETCH_SHOWN só uma vez por terminal. Como é exportada, um zsh    │
# │                     aberto dentro de outro herda a variável e pula —     │
# │                     mas um terminal NOVO começa limpo e mostra.          │
# │    $NVIM            pula no `:terminal` do Neovim                        │
# │    -t 1             pula quando a saída é um pipe, não uma tela          │
# │                     (senão `zsh -ic algo | grep` vem cheio de lixo)      │
# │                                                                          │
# │  Para desligar de vez: comente o bloco.                                  │
# │  Para pular só desta vez:  FASTFETCH_SHOWN=1 kitty                       │
# ╰──────────────────────────────────────────────────────────────────────────╯
if [[ -o interactive ]] \
  && [[ -z $FASTFETCH_SHOWN ]] \
  && [[ -z $NVIM ]] \
  && [[ -t 1 ]] \
  && command -v fastfetch >/dev/null 2>&1
then
  export FASTFETCH_SHOWN=1
  fastfetch
fi

# Rodar de novo quando quiser (ex.: depois de um `clear`).
alias ff="fastfetch"
