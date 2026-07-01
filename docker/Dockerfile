# pre-build stage
FROM node:24-alpine as node
FROM ruby:3.4.4-alpine3.21 AS pre-builder

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ARG BUNDLER_VERSION="2.5.11"
ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_ENV=production
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16

ENV NODE_VERSION=${NODE_VERSION} \
PNPM_VERSION=${PNPM_VERSION} \
BUNDLER_VERSION=${BUNDLER_VERSION} \
BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
RAILS_ENV=${RAILS_ENV} \
RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES} \
POSTMARK_API_TOKEN=${POSTMARK_API_TOKEN} \
SOURCE_TOKEN=${SOURCE_TOKEN} \
INGESTING_HOST=${INGESTING_HOST} \
CDN_ACCESS_KEY=${CDN_ACCESS_KEY} \
CDN_ACCESS_SECRET=${CDN_ACCESS_SECRET} \
CDN_REGION=${CDN_REGION} \
CDN_BUCKET=${CDN_BUCKET} \
ASSET_CDN_HOST=${ASSET_CDN_HOST} \
NODE_OPTIONS="--max-old-space-size=8192 --openssl-legacy-provider" \
GENERATE_SOURCEMAP=false \
BUNDLE_PATH="/gems" \
BUNDLE_JOBS=2 \
BUNDLE_RETRY=2

# Install build dependencies (including openssl-dev and git)
RUN apk update && apk add --no-cache \
  openssl \
  tar \
  build-base \
  tzdata \
  postgresql-dev \
  postgresql-client \
  git \
  curl \
  xz \
  linux-headers \
  imagemagick \
  imagemagick-dev \
  && mkdir -p /var/app \
  && gem install bundler -v "$BUNDLER_VERSION"

# Setup App Directory
WORKDIR /app

# Install Bundler
RUN gem install bundler -v "${BUNDLER_VERSION}"

# Copy Node from Node stage
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
&& ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
&& npm install -g pnpm@${PNPM_VERSION} \
&& npm cache clean --force

# Add PNPM to PATH
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Install Gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local force_ruby_platform true \
&& bundle config set without "${BUNDLE_WITHOUT}" \
&& bundle install

# Install JS dependencies
COPY package.json pnpm-lock.yaml ./
RUN echo "engine-strict=false" > .npmrc \
&& pnpm install --frozen-lockfile \
&& pnpm store prune \
&& pnpm cache clean \
&& rm -rf ~/.pnpm-store .npmrc

# Copy full source
COPY . /app

# Ensure log dir
RUN mkdir -p /app/log

ARG SECRET_KEY_BASE
ENV SECRET_KEY_BASE=$SECRET_KEY_BASE

# Precompile assets
RUN if [ "$RAILS_ENV" = "production" ]; then \
NODE_OPTIONS="--max-old-space-size=8192" \
bundle exec vite build && \
bundle exec rake assets:precompile && \
rm -rf spec node_modules tmp/cache /root/.cache /root/.npm; \
fi

# Store git SHA for tracking (using file instead of git command)
RUN if [ -f /app/.git_sha ]; then echo "Git SHA already exists"; else echo "0000000" > /app/.git_sha; fi

# Remove unnecessary files
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git \
  && rm .gitignore

# final build stage
FROM ruby:3.4.4-alpine3.21

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16

ARG EXECJS_RUNTIME="Disabled"
ENV EXECJS_RUNTIME ${EXECJS_RUNTIME}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES ${RAILS_SERVE_STATIC_FILES}

ARG BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_FORCE_RUBY_PLATFORM ${BUNDLE_FORCE_RUBY_PLATFORM}

ARG RAILS_ENV=production
ENV RAILS_ENV ${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

# Runtime dependencies (keep git!)
RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  git \
  vips \
  && gem install bundler -v "$BUNDLER_VERSION"

# Copy Node runtime only
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
&& ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
&& npm install -g pnpm@10.2.0 && npm cache clean --force

# Copy application
COPY --from=pre-builder /gems /gems
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha

WORKDIR /app

EXPOSE 3000
