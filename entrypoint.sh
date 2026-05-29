#!/bin/sh
set -e

CONFIG_FILE="${APP_HOME}/config.yaml"

# تحديد البورت تلقائياً
PORT_TO_USE="7860"
if [ -n "$PORT" ]; then
  PORT_TO_USE="$PORT"
fi

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  echo "--- Building Clean config.yaml ---"
  cat <<EOT > ${CONFIG_FILE}
dataRoot: ./data
listen: true
listenAddress:
  ipv4: 0.0.0.0
  ipv6: '[::]'
protocol:
    ipv4: true
    ipv6: true
dnsPreferIPv6: false
autorunHostname: "auto"
port: ${PORT_TO_USE}
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
sessionTimeout: 525600
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
    autoDownload: false
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
    rclone copy drive:ST-Backup ${APP_HOME}/data/ --config "${RCLONE_CONF}" --exclude "default-user/backups/**" --quiet || true
    chown -R node:node ${APP_HOME}/data 2>/dev/null || true
    echo "--- SUCCESS: Data restored from Google Drive. ---"
  else
    echo "Local data already exists, skipping restore."
  fi

  # استرجاع ملف الأسرار بأمان
  if [ -f "${APP_HOME}/data/secrets.json" ]; then
    echo "Restoring secrets.json from persistent data..."
    cp "${APP_HOME}/data/secrets.json" "${APP_HOME}/secrets.json"
    chown node:node "${APP_HOME}/secrets.json" 2>/dev/null || true
  fi

  echo "--- [SYNC] Starting Auto-Sync to Google Drive every 1 minute ---"
  (
    while true; do
      sleep 60
      if [ -f "${APP_HOME}/secrets.json" ]; then
        cp "${APP_HOME}/secrets.json" "${APP_HOME}/data/secrets.json" 2>/dev/null || true
      fi
      rclone sync ${APP_HOME}/data/ drive:ST-Backup --config "${RCLONE_CONF}" --exclude "access.log*" --exclude "default-user/backups/**" --quiet || true
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
      (cd "$plugin_dir" && npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force) || true
    fi || true
  done
  unset IFS
  chown -R node:node ./plugins 2>/dev/null || true
  echo "*** Plugin installation finished. ***"
fi

# تنصيب الإضافات بالخلفية بدون ما تعيق تشغيل السيرفر
(
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
            rm -rf "$extension_dir"
            git clone --depth 1 "$extension_url" "$extension_dir"
            if [ -f "$extension_dir/package.json" ]; then
                (cd "$extension_dir" && npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force)
            fi
        done
        unset IFS
        chown -R node:node "$EXTENSIONS_DIR" 2>/dev/null || true
    fi
) &

echo "*** Starting SillyTavern in Foreground ***"
# هذا هو الأمر الجذري اللي يمنع السيرفر من التعليق وينطي القيادة لـ Node
exec node ${APP_HOME}/server.js
