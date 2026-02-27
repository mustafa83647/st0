FROM node:lts-alpine3.19

# Arguments
ARG APP_HOME=/home/node/app
ARG PLUGINS="" 
ARG USERNAME=""
ARG PASSWORD=""

# Install system dependencies (تم إضافة rclone هنا بنجاح)
RUN apk add --no-cache gcompat tini git unzip wget curl dos2unix rclone

# Create app directory
WORKDIR ${APP_HOME}

# Set environment variables
ENV NODE_ENV=production
ENV APP_HOME=${APP_HOME}
ENV USERNAME=${USERNAME}
ENV PASSWORD=${PASSWORD}

# --- BEGIN: Clone SillyTavern Core (Latest Release) ---
RUN \
  echo "*** Cloning SillyTavern Core (Latest Version) ***" && \
  # تم إزالة تحديد النسخة القديمة لسحب أحدث إصدار تلقائياً
  git clone -b release --depth 1 https://github.com/SillyTavern/SillyTavern.git . && \
  echo "*** Cloning complete. ***"
# --- END: Clone SillyTavern Core ---

RUN rm -f .gitignore

RUN \
  echo "*** Install Base npm packages ***" && \
  if [ -f package.json ]; then \
    npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force; \
  else \
    echo "No package.json found, skipping."; \
  fi

WORKDIR ${APP_HOME}
RUN mkdir -p config

RUN \
  echo "*** Run Webpack ***" && \
  if [ -f "./docker/build-lib.js" ]; then \
    node "./docker/build-lib.js"; \
  elif [ -f "./build-lib.js" ]; then \
    node "./build-lib.js"; \
  else \
    echo "build-lib.js not found, skipping."; \
  fi

RUN git config --global --add safe.directory "${APP_HOME}"
RUN chown -R node:node ${APP_HOME}

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
