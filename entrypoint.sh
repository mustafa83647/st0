#!/bin/sh
set -e
CONFIG_FILE="${APP_HOME}/config.yaml"
if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "--- Custom Secure Form Auth enabled: Creating config.yaml and Proxy. ---"
  cat <<EOT > ${CONFIG_FILE}
dataRoot: ./data
listen: true
listenAddress:
  ipv4: 127.0.0.1
  ipv6: '[::1]'
protocol:
    ipv4: true
    ipv6: false
dnsPreferIPv6: false
autorunHostname: "auto"
port: 7861
autorunPortOverride: -1
ssl:
  enabled: false
  certPath: "./certs/cert.pem"
  keyPath: "./certs/privkey.pem"
whitelistMode: false
enableForwardedWhitelist: false
whitelist:
  - ::1
  - 127.0.0.1
whitelistDockerHosts: true
basicAuthMode: false
basicAuthUser:
  username: ""
  password: ""
enableCorsProxy: false
requestProxy:
  enabled: false
  url: "socks5://username:password@example.com:1080"
  bypass:
    - localhost
    - 127.0.0.1
enableUserAccounts: false
enableDiscreetLogin: false
autheliaAuth: false
perUserBasicAuth: false
sessionTimeout: -1
disableCsrfProtection: false
securityOverride: false
logging:
  enableAccessLog: true
  minLogLevel: 0
rateLimiting:
  preferRealIpHeader: false
autorun: false
avoidLocalhost: false
thumbnails:
  enabled: true
  format: "jpg"
  quality: 95
  dimensions: { 'bg': [160, 90], 'avatar': [96, 144] }
performance:
  lazyLoadCharacters: false
  memoryCacheCapacity: '100mb'
  useDiskCache: true
allowKeysExposure: true
skipContentCheck: false
whitelistImportDomains:
  - localhost
  - cdn.discordapp.com
  - files.catbox.moe
  - raw.githubusercontent.com
requestOverrides: []
extensions:
  enabled: true
  autoUpdate: false
  models:
    autoDownload: true
    classification: Cohee/distilbert-base-uncased-go-emotions-onnx
    captioning: Xenova/vit-gpt2-image-captioning
    embedding: Cohee/jina-embeddings-v2-base-en
    speechToText: Xenova/whisper-small
    textToSpeech: Xenova/speecht5_tts
enableDownloadableTokenizers: true
promptPlaceholder: "[Start a new chat]"
openai:
  randomizeUserId: false
  captionSystemPrompt: ""
deepl:
  formality: default
mistral:
  enablePrefix: false
ollama:
  keepAlive: -1
  batchSize: -1
claude:
  enableSystemPromptCache: false
  cachingAtDepth: -1
enableServerPlugins: true
enableServerPluginsAutoUpdate: false
EOT
  # إنشاء كود البروكسي الآمن
  cat << 'EOF' > /tmp/auth-proxy.js
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cookieParser = require('cookie-parser');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const app = express();
app.set('trust proxy', 1);
const TARGET_PORT = 7861;
const PROXY_PORT = 7860;
const USERNAME = process.env.USERNAME;
const PASSWORD = process.env.PASSWORD;
// إنشاء توكن ثابت يعتمد على بياناتك حتى لا يخرجك النظام عند إعادة تشغيل السيرفر
const AUTH_TOKEN = crypto.createHash('sha256').update(USERNAME + ':' + PASSWORD + ':SillyTavernSecureSalt2026').digest('hex');
app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));
// نظام الحماية من التخمين (10 محاولات كل 15 دقيقة)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: '<div style="color: #ff4d4d; text-align: center; font-family: sans-serif; margin-top: 50px;">تم حظر المحاولات المتكررة. يرجى المحاولة بعد 15 دقيقة.</div>'
});
const loginHtml = `
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>تسجيل الدخول</title>
<style>
  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f0f11; color: #e0e0e0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
  .login-box { background: #1a1a1e; padding: 2.5rem; border-radius: 12px; box-shadow: 0 8px 16px rgba(0,0,0,0.5); text-align: center; width: 100%; max-width: 350px; border: 1px solid #333; }
  .login-box h2 { margin-top: 0; color: #fff; font-size: 1.5rem; margin-bottom: 1.5rem; }
  input { display: block; width: 100%; margin: 15px 0; padding: 12px; border: 1px solid #444; border-radius: 6px; background: #222; color: #fff; box-sizing: border-box; font-size: 1rem; transition: border-color 0.3s; }
  input:focus { border-color: #007bff; outline: none; }
  button { background: #007bff; color: white; padding: 12px; border: none; border-radius: 6px; cursor: pointer; width: 100%; font-size: 1.1rem; font-weight: bold; transition: background 0.3s; }
  button:hover { background: #0056b3; }
  .error { color: #ff4d4d; margin-bottom: 15px; font-size: 0.9rem; }
</style>
</head>
<body>
  <div class="login-box">
    <h2>تسجيل الدخول</h2>
    <form method="POST" action="/st-login">
      <input type="text" name="username" placeholder="اسم المستخدم" required autocomplete="username" />
      <input type="password" name="password" placeholder="كلمة المرور" required autocomplete="current-password" />
      <button type="submit">دخول</button>
    </form>
  </div>
</body>
</html>
`;
app.get('/st-login', (req, res) => {
    res.send(loginHtml);
});
app.post('/st-login', loginLimiter, (req, res) => {
    const inputUser = String(req.body.username || '');
    const inputPass = String(req.body.password || '');

    let isMatch = false;
    // استخدام timingSafeEqual للحماية من هجمات التوقيت
    if (inputUser.length === USERNAME.length && inputPass.length === PASSWORD.length) {
        const userMatch = crypto.timingSafeEqual(Buffer.from(inputUser), Buffer.from(USERNAME));
        const passMatch = crypto.timingSafeEqual(Buffer.from(inputPass), Buffer.from(PASSWORD));
        isMatch = userMatch && passMatch;
    }
    if (isMatch) {
        res.cookie('st_auth', AUTH_TOKEN, {
            httpOnly: true,
            secure: true,
            sameSite: 'strict',
            maxAge: 365 * 24 * 60 * 60 * 1000 // صالحة لمدة سنة كاملة
        });
        res.redirect('/');
    } else {
        res.status(401).send(loginHtml.replace('</form>', '<div class="error">بيانات الدخول غير صحيحة!</div></form>'));
    }
});
app.get('/st-logout', (req, res) => {
    res.clearCookie('st_auth');
    res.redirect('/st-login');
});
app.use((req, res, next) => {
    if (req.cookies.st_auth === AUTH_TOKEN) {
        next();
    } else {
        res.redirect('/st-login');
    }
});
const proxy = createProxyMiddleware({
    target: `http://127.0.0.1:${TARGET_PORT}`,
    changeOrigin: true,
    ws: true,
    logLevel: 'silent'
});
app.use('/', proxy);
const server = app.listen(PROXY_PORT, '0.0.0.0', () => {
    console.log(`Secure Auth Proxy listening on port ${PROXY_PORT}`);
});
server.on('upgrade', proxy.upgrade);
EOF
  echo "--- Installing proxy dependencies ---"
  cd /tmp
  npm install express cookie-parser http-proxy-middleware express-rate-limit > /dev/null 2>&1
  cd "${APP_HOME}"
  echo "--- Starting Secure Auth Proxy ---"
  node /tmp/auth-proxy.js &
  PROXY_PID=$!
elif [ -n "${CONFIG_YAML}" ]; then
  echo "--- Found CONFIG_YAML, creating config.yaml from environment variable. ---"
  printf '%s\n' "${CONFIG_YAML}" > ${CONFIG_FILE}
else
    echo "--- No user/pass or CONFIG_YAML provided. App will use its default settings. ---"
fi
# ====================================================================
# --- BEGIN: RCLONE AUTO-RESTORE & SYNC TO GOOGLE DRIVE ---
if [ -n "${RCLONE_CONFIG_CONTENT}" ]; then
  echo "--- Configuring Rclone for Google Drive ---"
  RCLONE_CONF="/tmp/rclone.conf"
  echo "${RCLONE_CONFIG_CONTENT}" > "${RCLONE_CONF}"

  echo "--- [RESTORE] Checking for existing data in Google Drive ---"
  if [ ! -d "${APP_HOME}/data/default-user/chats" ] || [ -z "$(ls -A ${APP_HOME}/data/default-user/chats 2>/dev/null)" ]; then
    echo "No existing chats found locally. Restoring from Google Drive..."
    rclone copy drive:ST-Backup ${APP_HOME}/data/ --config "${RCLONE_CONF}" --exclude "default-user/backups/**" --quiet || echo "WARN: Restore failed or Drive is empty."
    chown -R node:node ${APP_HOME}/data 2>/dev/null || true
    echo "--- SUCCESS: Data restored from Google Drive. ---"
  else
    echo "Local data already exists, skipping restore."
  fi
  echo "--- [SYNC] Starting Auto-Sync to Google Drive every 1 minute ---"
  (
    while true; do
      sleep 60
      echo "--- Auto-Syncing data to Google Drive... ---"
      rclone sync ${APP_HOME}/data/ drive:ST-Backup --config "${RCLONE_CONF}" --exclude "access.log*" --exclude "default-user/backups/**" --quiet || echo "WARN: Sync failed."
    done
  ) &
fi
# --- END: RCLONE AUTO-RESTORE & SYNC ---
# ====================================================================
echo '--- Checking for PLUGINS environment variable ---'
if [ -n "$PLUGINS" ]; then
  echo "*** Installing Plugins specified in PLUGINS environment variable: $PLUGINS ***"
  mkdir -p ./plugins && chown node:node ./plugins 2>/dev/null || true
  IFS=','
  for plugin_url in $PLUGINS; do
    plugin_url=$(echo "$plugin_url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$plugin_url" ]; then continue; fi
    plugin_name_git=$(basename "$plugin_url")
    plugin_name=${plugin_name_git%.git}

    if [ "$plugin_name" = "cloud-saves" ]; then
       echo "--- Skipping cloud-saves plugin as Rclone is now handling backups ---"
       continue
    fi

    plugin_dir="./plugins/$plugin_name"
    echo "--- Installing plugin: $plugin_name from $plugin_url into $plugin_dir ---"
    rm -rf "$plugin_dir"
    git clone --depth 1 "$plugin_url" "$plugin_dir"
    if [ -f "$plugin_dir/package.json" ]; then
      (cd "$plugin_dir" && npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force) || echo "WARN: Failed to install dependencies"
    fi || echo "WARN: Failed to clone $plugin_name from $plugin_url, skipping..."
  done
  unset IFS
  chown -R node:node ./plugins 2>/dev/null || true
  echo "*** Plugin installation finished. ***"
fi
echo "*** Starting SillyTavern... ***"
node ${APP_HOME}/server.js &
SERVER_PID=$!
if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
    HEALTH_CHECK_URL="http://127.0.0.1:7861/"
    CURL_COMMAND="curl -sf"
else
    HEALTH_CHECK_URL="http://127.0.0.1:7860/"
    CURL_COMMAND="curl -sf"
fi
RETRY_COUNT=0
MAX_RETRIES=12
while ! eval "${CURL_COMMAND} ${HEALTH_CHECK_URL}" > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
        echo "SillyTavern failed to start. Exiting."
        kill ${SERVER_PID}
        exit 1
    fi
    echo "SillyTavern is still starting, waiting 5 seconds..."
    sleep 5
done
echo "SillyTavern started successfully! Beginning periodic keep-alive..."
install_extensions() {
    sleep 40
    if [ -n "$EXTENSIONS" ]; then
        echo "*** Installing Extensions specified in EXTENSIONS environment variable: $EXTENSIONS ***"
        if [ "$INSTALL_FOR_ALL_USERS" = "true" ]; then
            EXTENSIONS_DIR="./public/scripts/extensions/third-party"
        else
            EXTENSIONS_DIR="./data/default-user/extensions"
        fi
        mkdir -p "$EXTENSIONS_DIR" && chown node:node "$EXTENSIONS_DIR" 2>/dev/null || true
        IFS=','
        for extension_url in $EXTENSIONS; do
            extension_url=$(echo "$extension_url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -z "$extension_url" ]; then continue; fi
            extension_name_git=$(basename "$extension_url")
            extension_name=${extension_name_git%.git}
            extension_dir="$EXTENSIONS_DIR/$extension_name"
            echo "--- Installing extension: $extension_name ---"
            rm -rf "$extension_dir"
            git clone --depth 1 "$extension_url" "$extension_dir"
            if [ -f "$extension_dir/package.json" ]; then
                (cd "$extension_dir" && npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force)
            fi
        done
        unset IFS
        chown -R node:node "$EXTENSIONS_DIR" 2>/dev/null || true
    fi
}
install_extensions &
while kill -0 ${SERVER_PID} 2>/dev/null; do
    eval "${CURL_COMMAND} ${HEALTH_CHECK_URL}" > /dev/null || true
    sleep 1800
done &
wait ${SERVER_PID}
