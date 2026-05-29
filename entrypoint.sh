#!/bin/sh
set -e

CONFIG_FILE="${APP_HOME}/config.yaml"

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "--- Creating config.yaml with User Accounts enabled. ---"
  cat <<EOT > ${CONFIG_FILE}
dataRoot: ./data
listen: true
listenAddress:
  ipv4: 0.0.0.0
  ipv6: '[::]'
protocol:
    ipv4: true
    ipv6: false
dnsPreferIPv6: false
autorunHostname: "auto"
port: 7860
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
  username: "${USERNAME}"
  password: "${PASSWORD}"
enableCorsProxy: false
requestProxy:
  enabled: false
  url: "socks5://username:password@example.com:1080"
  bypass:
    - localhost
    - 127.0.0.1
enableUserAccounts: true
enableDiscreetLogin: false
autheliaAuth: false
perUserBasicAuth: false
sessionTimeout: 31536000000
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

elif [ -n "${CONFIG_YAML}" ]; then
  echo "--- Found CONFIG_YAML, creating config.yaml from environment variable. ---"
  printf '%s\n' "${CONFIG_YAML}" > ${CONFIG_FILE}
else
    echo "--- No user/pass or CONFIG_YAML provided. App will use its default settings. ---"
fi

# ملاحظة: تم إزالة كود التحديث التلقائي (git pull) للحفاظ على ثبات نسخة 1.14 الخفيفة وعدم العودة لنسخة 1.16 تلقائياً

# ====================================================================
# --- BEGIN: RCLONE AUTO-RESTORE & SYNC TO GOOGLE DRIVE ---
if [ -n "${RCLONE_CONFIG_CONTENT}" ]; then
  echo "--- Configuring Rclone for Google Drive ---"
  RCLONE_CONF="/tmp/rclone.conf"
  echo "${RCLONE_CONFIG_CONTENT}" > "${RCLONE_CONF}"
  
  echo "--- [RESTORE] Checking for existing data in Google Drive ---"
  if [ ! -d "${APP_HOME}/data/default-user/chats" ] || [ -z "$(ls -A ${APP_HOME}/data/default-user/chats 2>/dev/null)" ]; then
    echo "No existing chats found locally. Restoring from Google Drive..."
    # التعديل: استثناء مجلد backups عند الاستعادة
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
      # التعديل: منع رفع ملف اللوق ومجلد backups الداخلي المزعج
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

echo "*** Setting up persistent secrets for Google Drive... ***"
if [ ! -f "${APP_HOME}/data/secrets.json" ]; then
    echo '{}' > "${APP_HOME}/data/secrets.json"
fi
ln -sf "${APP_HOME}/data/secrets.json" "${APP_HOME}/secrets.json"

echo "*** Starting SillyTavern... ***"
node ${APP_HOME}/server.js &
SERVER_PID=$!

# تم التعديل هنا ليكون 7860
HEALTH_CHECK_URL="http://localhost:7860/"
CURL_COMMAND="curl -sf"

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
    CURL_COMMAND="curl -sf" # تم التعديل هنا ليتناسب مع الحسابات
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
    # تم التعديل هنا ليكون 7860
    echo "SillyTavern is still starting or not responsive on port 7860, waiting 5 seconds..."
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
