#!/usr/bin/env bash
# Восстанавливает браузерную способность Claude в облачной сессии.
# Контейнер эфемерный — браузер каждый раз надо ставить заново.
#
# Запуск:  bash apps/instagram-blog/tools/setup.sh
#
# Важно: загрузчик Playwright (Node) уважает NODE_EXTRA_CA_CERTS, поэтому
# скачивание проходит через TLS-прокси среды. Загрузчик agent-browser (Rust)
# этого не умеет — поэтому используем именно Playwright.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Ставлю playwright (npm)…"
[ -f package.json ] || npm init -y >/dev/null 2>&1
npm i playwright >/dev/null 2>&1

echo "==> Скачиваю Chromium + системные зависимости…"
npx playwright install --with-deps chromium

echo
echo "Готово. Примеры запуска:"
echo "  node igapi.js <username>     # профиль через публичный API IG (сейчас обычно 401: нужен вход)"
echo "  node viewer.js <username>    # пробует зеркала-вьюеры (часто блок Cloudflare с серверного IP)"
echo
echo "Браузер работает для ЛЮБЫХ других сайтов (скриншоты, формы, парсинг)."
echo "Запуск headless со снятием ошибок прокси-сертификата: ignoreHTTPSErrors:true + args ['--no-sandbox']."
