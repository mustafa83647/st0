#!/bin/sh
set -e
CONFIG_FILE="${APP_HOME}/config.yaml"
if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "--- Custom Secure Form Auth enabled: Creating config.yaml and Proxy. ---"
  cat <<EOT > ${CONFIG_FILE}
dataRoot: ./data
listen: false
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
securityOverride: true
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
  # إنشاء كود البروكسي الآمن مع الواجهة الزجاجية الجديدة
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
const AUTH_TOKEN = crypto.createHash('sha256').update(USERNAME + ':' + PASSWORD + ':SillyTavernSecureSalt2026').digest('hex');
app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: '<div style="color: #ff4d4d; text-align: center; font-family: sans-serif; margin-top: 50px;">Too many attempts. Please try again in 15 minutes.</div>'
});
const loginHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Login</title>
<style>
  body {
    margin: 0;
    padding: 0;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    /* خلفية متدرجة بنفسجية ساحرة تتحرك ببطء */
    background: linear-gradient(135deg, #1e0b36, #4a154b, #6a1b5a, #2b1055);
    background-size: 400% 400%;
    animation: gradientBG 15s ease infinite;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  @keyframes gradientBG {
    0% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
  /* تأثير الزجاج الشفاف */
  .glass-panel {
    background: rgba(255, 255, 255, 0.08);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 16px;
    padding: 40px 35px;
    width: 100%;
    max-width: 320px;
    box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
    text-align: center;
    color: white;
    box-sizing: border-box;
  }
  .glass-panel h2 {
    margin-top: 0;
    margin-bottom: 35px;
    font-size: 26px;
    font-weight: 600;
    letter-spacing: 1px;
  }
  .input-container {
    position: relative;
    margin-bottom: 20px;
  }
  .input-container input {
    width: 100%;
    padding: 12px 40px 12px 15px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    color: white;
    font-size: 14px;
    box-sizing: border-box;
    outline: none;
    transition: 0.3s;
  }
  .input-container input::placeholder {
    color: rgba(255, 255, 255, 0.6);
  }
  .input-container input:focus {
    border-color: rgba(255, 255, 255, 0.6);
    background: rgba(255, 255, 255, 0.15);
  }
  .input-container svg {
    position: absolute;
    right: 12px;
    top: 50%;
    transform: translateY(-50%);
    width: 18px;
    height: 18px;
    fill: rgba(255, 255, 255, 0.7);
  }
  .login-btn {
    width: 100%;
    padding: 12px;
    background: white;
    color: #4a154b;
    border: none;
    border-radius: 25px;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    transition: 0.3s;
    margin-top: 15px;
  }
  .login-btn:hover {
    background: #f0f0f0;
    box-shadow: 0 0 15px rgba(255,255,255,0.4);
  }
  .error {
    color: #ff7675;
    margin-bottom: 15px;
    font-size: 13px;
  }
</style>
</head>
<body>
  <div class="glass-panel">
    <h2>Login</h2>
    <form method="POST" action="/st-login">
      <div class="input-container">
        <input type="text" name="username" placeholder="Username" required autocomplete="username" />
        <!-- أيقونة المستخدم -->
        <svg viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
      </div>
      <div class="input-container">
        <input type="password" name="password" placeholder="Password" required autocomplete="current-password" />
        <!-- أيقونة القفل -->
        <svg viewBox="0 0 24 24"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/></svg>
      </div>
      <button type="submit" class="login-btn">Login</button>
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
            maxAge: 365 * 24 * 60 * 60 * 1000
        });
        res.redirect('/');
    } else {
        res.status(401).send(loginHtml.replace('</form>', '<div class="error">Invalid credentials!</div></form>'));
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
    CURL_COMMAND="curl -s"
else
    HEALTH_CHECK_URL="http://127.0.0.1:7860/"
    CURL_COMMAND="curl -s"
fi
RETRY_COUNT=0
MAX_RETRIES=15
while ! eval "${CURL_COMMAND} ${HEALTH_CHECK_URL}" > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
        echo "SillyTavern failed to start. Exiting."
        kill ${SERVER_PID}
        exit 1
    fi
    echo "SillyTavern is still starting, waiting 5 seconds... (Attempt ${RETRY_COUNT}/${MAX_RETRIES})"
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
