FROM node:lts-alpine3.19

# Arguments
ARG APP_HOME=/home/node/app
ARG PLUGINS="" 
ARG USERNAME=""
ARG PASSWORD=""

# Install system dependencies
RUN apk add --no-cache gcompat tini git unzip wget curl dos2unix rclone

# Create app directory
WORKDIR ${APP_HOME}

# Set environment variables (تمت إضافة بورتات Hugging Face هنا)
ENV NODE_ENV=production
ENV APP_HOME=${APP_HOME}
ENV USERNAME=${USERNAME}
ENV PASSWORD=${PASSWORD}
ENV PORT=7860
ENV LISTEN_PORT=7860

# --- BEGIN: Clone SillyTavern Core (Version 1.14.0) ---
RUN \
  echo "*** Cloning SillyTavern Core (Version 1.14.0) ***" && \
  git clone -b 1.14.0 --depth 1 https://github.com/SillyTavern/SillyTavern.git . && \
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

# إعداد الصلاحيات الخاصة بـ Hugging Face (يجب أن يكون المستخدم رقم 1000)
RUN git config --global --add safe.directory "${APP_HOME}"
RUN chown -R 1000:1000 ${APP_HOME}

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN dos2unix /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# فتح بورت 7860 بدلاً من 8000
EXPOSE 7860

# التبديل للمستخدم رقم 1000 (شرط أساسي في Hugging Face)
USER 1000

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
