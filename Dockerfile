FROM node:10.15.1-stretch AS test

RUN apt-get update \
    && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      jq \
      --no-install-recommends \
    && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y \
      google-chrome-stable \
      fontconfig \
      fonts-ipafont-gothic \
      fonts-wqy-zenhei \
      fonts-thai-tlwg \
      fonts-kacst \
      fonts-symbola \
      fonts-noto \
      ttf-freefont \
      --no-install-recommends \
    && apt-get purge --auto-remove -y gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r testuser \
    && useradd -r -g testuser -G audio,video testuser \
    && mkdir -p /home/testuser \
    && chown -R testuser:testuser /home/testuser \
    && mkdir -p /usr/src/app \
    && mkdir -p /usr/src/app/reports/coverage \
    && mkdir -p /usr/src/app/reports/lint \
    && chown -R testuser:testuser /usr/src/app

USER testuser
WORKDIR /usr/src/app

COPY package.json package-lock.json ./
RUN npm ci || cat npm-debug.log
RUN npm run update-webdriver-ci

COPY angular.json tsconfig.json tslint.json ./
COPY src ./src
COPY e2e ./e2e

FROM test AS build
RUN npm run build-ci

FROM nginx:1.14.2-alpine AS dist
COPY etc/nginx/conf.d /etc/nginx/conf.d
COPY --from=build /usr/src/app/dist /usr/share/app/dist
