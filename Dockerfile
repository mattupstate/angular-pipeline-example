FROM node:10.15.1-stretch AS test
RUN apt-get update \
    && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      jq \
      tree \
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
ARG app_src_dir
RUN groupadd -r testuser \
    && useradd -r -g testuser -G audio,video testuser \
    && mkdir -p /home/testuser \
    && chown -R testuser:testuser /home/testuser \
    && mkdir -p ${app_src_dir} \
    && mkdir -p ${app_src_dir}/reports \
    && mkdir -p ${app_src_dir}/dist \
    && chown -R testuser:testuser ${app_src_dir}
USER testuser
WORKDIR ${app_src_dir}
COPY --chown=testuser:testuser package.json package-lock.json ./
RUN npm install
COPY --chown=testuser:testuser . ./
ARG git_branch
ARG git_branch_href
ARG git_commit_sha
ARG git_commit_href
ARG git_is_dirty
ENV GIT_BRANCH=${git_branch} \
    GIT_BRANCH_HREF=${git_branch_href} \
    GIT_COMMIT_SHA=${git_commit_sha} \
    GIT_COMMIT_HREF=${git_commit_href} \
    GIT_IS_DIRTY=${git_is_dirty}
RUN npm run build-prod
VOLUME /usr/src/app/dist


FROM nginx:1.14.2-alpine AS dist
ARG app_src_dir
COPY --chown=nginx:nginx etc/nginx/conf.d /etc/nginx/conf.d
COPY --chown=nginx:nginx --from=test ${app_src_dir}/dist /usr/share/app/dist
