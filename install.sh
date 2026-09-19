#!/usr/bin/env bash
#
# ccroute — развёртывание комбо Claude Code + OmniRoute (точный клон)
# для Parrot OS / Debian-подобных систем БЕЗ sudo (в домашнюю папку).
#
# Что делает:
#   1. ставит Node.js LTS-версии в $HOME/node (без root)
#   2. настраивает npm-префикс $HOME/.npm-global
#   3. ставит claude-code 2.1.245 и omniroute 3.8.50
#   4. разворачивает данные OmniRoute (провайдеры, ключи, oauth) из omniroute-data.tar.gz
#   5. создаёт ~/.claude/omniroute-settings.json и ~/.local/bin/ccroute
#   6. поднимает сервер OmniRoute на 127.0.0.1:20128
#
# Запуск:  bash install.sh
# Скрипт сохраняем идемпотентным: повторный запуск безопасен.

set -euo pipefail

NODE_MAJOR="24"
NODE_FULL="24.19.0"
CLAUDE_VERSION="2.1.245"
OMNIROUTE_VERSION="3.8.50"
PORT="20128"
SETTINGS_FILE="$HOME/.claude/omniroute-settings.json"
CCROUTE_FILE="$HOME/.local/bin/ccroute"
DATA_TAR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/omniroute-data.tar.gz"

# «Точно такое же» комбо — эти значения из исходной машины:
OMNI_BASE_URL="http://127.0.0.1:20128"
OMNI_AUTH_TOKEN="sk-7a1eed6d2ce58e84-b76734-384de1ac"
OMNI_MODEL="static-best-coding[1m]"

c_green=$'\033[0;32m'; c_yellow=$'\033[0;33m'; c_red=$'\033[0;31m'; c_cyan=$'\033[0;36m'; c_reset=$'\033[0m'
info()  { printf '%s[i]%s %s\n' "$c_cyan" "$c_reset" "$*"; }
ok()    { printf '%s[ok]%s %s\n' "$c_green" "$c_reset" "$*"; }
warn()  { printf '%s[warn]%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()   { printf '%s[err]%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

# ---------- 0. проверки ----------
command -v curl >/dev/null 2>&1 || die "curl не найден (apt install curl)"
command -v tar  >/dev/null 2>&1 || die "tar не найден"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)  NODE_ARCH=linux-x64 ;;
  aarch64|arm64) NODE_ARCH=linux-arm64 ;;
  *) die "неизвестная архитектура: $ARCH" ;;
esac

export PATH="$HOME/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# ---------- 1. Node.js в $HOME/node (без sudo) ----------
if [ -x "$HOME/node/bin/node" ]; then
  INSTALLED_NODE="$("$HOME/node/bin/node" -v 2>/dev/null || true)"
  info "Node уже установлен: $INSTALLED_NODE"
else
  info "Устанавливаю Node.js $NODE_FULL ($NODE_ARCH) в $HOME/node ..."
  TMP_TAR="$HOME/.ccroute-node.tar.xz"
  curl -fsSL "https://nodejs.org/dist/v${NODE_FULL}/node-v${NODE_FULL}-${NODE_ARCH}.tar.xz" -o "$TMP_TAR"
  tar -C "$HOME" -xJf "$TMP_TAR"
  mv "$HOME/node-v${NODE_FULL}-${NODE_ARCH}" "$HOME/node"
  rm -f "$TMP_TAR"
  ok "Node $NODE_FULL установлен в $HOME/node"
fi

NODE_BIN="$(command -v node)"
info "node:  $NODE_BIN ($("$NODE_BIN" -v))"
NODE_OK=$("$NODE_BIN" -e 'const m=Number(process.versions.node.split(".")[0]); process.exit(m>=20?0:1)' && echo yes || echo no)
[ "$NODE_OK" = yes ] || warn "Node < 20 — возможны проблемы с claude-code; рекомендуется Node ${NODE_MAJOR}+"

# ---------- 2. npm-префикс ----------
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"
info "npm prefix: $HOME/.npm-global"

# ---------- 3. пакеты ----------
info "Устанавливаю claude-code@$CLAUDE_VERSION ..."
npm install -g "@anthropic-ai/claude-code@$CLAUDE_VERSION" >/dev/null || die "не удалось поставить claude-code"
info "Устанавливаю omniroute@$OMNIROUTE_VERSION ..."
npm install -g "omniroute@$OMNIROUTE_VERSION" >/dev/null || die "не удалось поставить omniroute"

CLAUDE_BIN="$(command -v claude || echo "$HOME/.npm-global/bin/claude")"
OMNI_BIN="$(command -v omniroute || echo "$HOME/.npm-global/bin/omniroute")"
info "claude:    $CLAUDE_BIN"
info "omniroute: $OMNI_BIN"

# ---------- 4. данные OmniRoute (точный клон провайдеров/ключей) ----------
if [ -f "$DATA_TAR" ]; then
  mkdir -p "$HOME/.omniroute"
  info "Разворачиваю данные OmniRoute из $(basename "$DATA_TAR") ..."
  tar -xzf "$DATA_TAR" -C "$HOME/.omniroute"
  ok "Данные OmniRoute развёрнуты в $HOME/.omniroute"
else
  warn "omniroute-data.tar.gz не найден рядом со скриптом — OmniRoute будет пустой (настрой провайдера в dashboard вручную)."
fi

# ---------- 5. настройки Claude Code + обёртка ----------
mkdir -p "$HOME/.claude" "$HOME/.local/bin"
cat > "$SETTINGS_FILE" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$OMNI_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN": "$OMNI_AUTH_TOKEN",
    "CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT": "1"
  },
  "model": "$OMNI_MODEL"
}
EOF
chmod 600 "$SETTINGS_FILE"
ok "Настройки: $SETTINGS_FILE"

cat > "$CCROUTE_FILE" <<EOF
#!/usr/bin/env bash
exec "$CLAUDE_BIN" --settings "$SETTINGS_FILE" "\$@"
EOF
chmod +x "$CCROUTE_FILE"
ok "Команда: $CCROUTE_FILE"

# ---------- 6. PATH в ~/.bashrc и ~/.zshrc ----------
for RC in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$RC" ] || continue
  tg="# --- ccroute combo ---"
  if ! grep -q "^$tg" "$RC"; then
    {
      echo "$tg"
      echo 'export PATH="$HOME/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
    } >> "$RC"
  fi
done
ok "PATH добавлен в shell-rc"

# ---------- 7. запуск сервера ----------
if curl -fsS "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
  ok "Сервер OmniRoute уже работает на http://127.0.0.1:$PORT"
else
  info "Запускаю OmniRoute на http://127.0.0.1:$PORT (фоновый демон) ..."
  "$OMNI_BIN" serve --port "$PORT" --no-open --daemon >/dev/null 2>&1 || \
    warn "Демон не поднялся — проверь логи: omniroute serve --port $PORT"
  sleep 2
fi

if curl -fsS "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
  ok "OmniRoute отвечает на http://127.0.0.1:$PORT"
else
  warn "OmniRoute пока не отвечает — попробуй: omniroute serve --port $PORT"
fi

# ---------- 8. итог ----------
echo
printf '%s\n' "$c_green======================================================================"
printf '  ccroute развёрнут!%s\n' "$c_reset"
echo "  node:      $("$HOME/node/bin/node" -v)"
echo "  npm:       $(npm -v)"
echo "  claude:    $CLAUDE_BIN"
echo "  omniroute: $OMNI_BIN"
echo "  сервер:    http://127.0.0.1:$PORT"
echo "  модель:    $OMNI_MODEL"
echo "  settings:  $SETTINGS_FILE"
echo "  команда:   ccroute"
echo
echo "Использование:"
echo "    source ~/.bashrc"
echo "    ccroute" $'            # Claude Code поверх OmniRoute\n'
echo "    omniroute serve --port $PORT   # (пере)запуск сервера вручную"
printf '%s\n' "$c_green======================================================================$c_reset"