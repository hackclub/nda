# syntax=docker/dockerfile:1
ARG RUBY_DEV_IMAGE=dhi.io/ruby:3.4-dev
ARG RUBY_RUNTIME_IMAGE=dhi.io/ruby:3.4

FROM ${RUBY_DEV_IMAGE} AS build
USER root
WORKDIR /rails
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*
COPY --from=dhi.io/bun:1-debian13-dev /usr/local/bin/bun /usr/local/bin/bun
RUN ln -sf bun /usr/local/bin/bunx
COPY Gemfile Gemfile.lock ./
RUN bundle config set jobs 1 && bundle install && \
    rm -rf /root/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build && \
    bundle exec bootsnap precompile -j 1 app/ lib/ && \
    VITE_RUBY_SKIP_ASSETS_PRECOMPILE_EXTENSION=true SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    chmod -R 0755 bin && chmod -R 0770 storage tmp && \
    rm -rf node_modules /root/.bun
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

FROM ${RUBY_RUNTIME_IMAGE} AS production
WORKDIR /rails
ENV SOLID_QUEUE_IN_PUMA=true \
    RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    PATH=/usr/local/bundle/ruby/3.4.0/bin:/usr/local/bundle/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY --chown=65532:65532 --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=65532:65532 --from=build /rails /rails
USER 65532:65532
ENTRYPOINT ["ruby", "/rails/bin/docker-entrypoint"]
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["ruby", "-rnet/http", "-e", "exit(Net::HTTP.get_response(URI(\"http://127.0.0.1:#{ENV.fetch('PORT', 3000)}/up\")).is_a?(Net::HTTPSuccess) ? 0 : 1)"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
