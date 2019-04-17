FROM node:10.15.1-stretch AS test
ARG git_branch
ARG git_commit_sha
ARG git_is_dirty
ENV GIT_BRANCH=${git_branch} \
    GIT_COMMIT_SHA=${git_commit_sha} \
    GIT_IS_DIRTY=${git_is_dirty}
RUN apt-get update \
    && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      jq \
      awscli \
      --no-install-recommends \
    && curl -sSL https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip > terraform.zip \
    && unzip terraform.zip \
    && mv terraform /usr/local/bin/ \
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
    && mkdir -p /usr/share/app \
    && mkdir -p /usr/src/app/reports/coverage \
    && mkdir -p /usr/src/app/reports/lint \
    && chown -R testuser:testuser /usr/src/app \
    && chown -R testuser:testuser /usr/share/app
USER testuser
WORKDIR /usr/src/app
COPY --chown=testuser:testuser package.json package-lock.json ./
RUN npm ci
COPY --chown=testuser:testuser . ./
RUN npm run build-prod


FROM nginx:1.14.2-alpine AS dist
COPY --chown=nginx:nginx etc/nginx/conf.d /etc/nginx/conf.d
COPY --chown=nginx:nginx --from=test /usr/src/app/dist /usr/share/app/dist


FROM test as deploy
WORKDIR /usr/share/app
COPY --chown=testuser:testuser --from=test /usr/src/app/dist /usr/share/app/dist
COPY --chown=testuser:testuser --from=test /usr/src/app/etc/terraform /usr/share/app/terraform
