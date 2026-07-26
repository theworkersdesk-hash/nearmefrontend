# Builds the Flutter *web* target and serves it via nginx.
# (Mobile iOS/Android builds run on developer machines / CI, not in Docker.)

# ---- Build stage ----
FROM debian:bookworm-slim AS build
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    flutter --version && flutter config --enable-web

WORKDIR /app
COPY . .
# Generate any missing platform scaffolding (web/, etc.) without touching lib/.
RUN flutter create . --platforms=web --project-name vibe && flutter pub get
# API base URL is injected at build time; override with --build-arg.
ARG API_BASE_URL=https://nearme.theworkersdesk.tech
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# ---- Runtime stage ----
FROM nginx:1.27-alpine AS runtime
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
