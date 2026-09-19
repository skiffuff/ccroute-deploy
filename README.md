# ccroute — Установка без прав администратора

> Репозиторий **приватный**: перед скачиванием твой GitHub-аккаунт должен быть добавлен в коллабораторы (пишет `skiffuff`), а сам `curl`/`git` — под твоим авторизованным доступом.

## Способ A — git clone (самый надёжный, нужен вход в GitHub)

```sh
cd ~
git clone https://github.com/skiffuff/ccroute-deploy.git
cd ccroute-deploy
bash install.sh
source ~/.bashrc
ccroute
```

Если `git clone` просит пароль — авторизуйся через браузер/PAT (репо приватное, не пуская анонимов).

## Способ B — одним архивом (нужен токен, если репо приватное)

```sh
cd ~ && curl -fsSL -o ccroute-deploy.tar.gz https://codeload.github.com/skiffuff/ccroute-deploy/tar.gz/refs/heads/master
tar -xzf ccroute-deploy.tar.gz && cd ccroute-deploy-master
bash install.sh
source ~/.bashrc
ccroute
```

Для приватного репо `codeload` без авторизации вернёт 404 — тогда используй способ A либо добавь ссылку в доверенные и скачай через браузер (кнопка **Code → Download ZIP**).

## Что это

Комбо **Claude Code + OmniRoute** — «точно такой же» рабочий набор, как у исходной машины:
- Node.js 24 устанавливается в `~/node` (без `sudo`)
- пакеты в `~/.npm-global`: `claude-code@2.1.245`, `omniroute@3.8.50`
- данные OmniRoute (провайдеры, ключи, oauth) клонируются в `~/.omniroute`
- сервер поднимается на `http://127.0.0.1:20128`
- команда `ccroute` запускает Claude Code поверх OmniRoute

## Требования

- Linux (Debian/Parrot OS), архитектура x86_64 или arm64
- `curl` и `tar` (обычно уже есть)
- права root **не нужны**

## Проверка после установки

```sh
node -v                 # v24.19.0
claude --version        # 2.1.245
omniroute --version     # 3.8.50
omniroute serve --help  # сервер на порту 20128
ccroute                 # Claude Code
```

Если `ccroute` не находится — перезапусти терминал или выполни:

```sh
export PATH="$HOME/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
```

## Ручной запуск сервера

Если после перезагрузки сервер не запустился автоматически:

```sh
omniroute serve --port 20128 --no-open --daemon
```

## Что если что-то не так

- `npm install` падает → нет сети: проверь `ping github.com` / `ping registry.npmjs.org`
- сервер не отвечает на `127.0.0.1:20128` → запусти вручную без `--daemon` и смотри вывод/логи в `~/.omniroute/logs`
- ошибка авторизации (401) → токен в `~/.claude/omniroute-settings.json` не совпадает с ключами в БД OmniRoute

## Безопасность

Репозиторий и бандл данных содержат секреты (ключи провайдеров, oauth) — не расшаривай ссылку и не делай репо публичным. Неоавторизованным скачивание тут же вернёт 404 — это защита GitHub, а не ошибка.

## Если скрипт лежит у тебя на флешке/диске (без интернет-доступа к GitHub)

Просто открой папку с `install.sh` и `omniroute-data.tar.gz` в терминале:

```sh
bash install.sh
source ~/.bashrc
ccroute
```