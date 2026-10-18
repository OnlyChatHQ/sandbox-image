# Base image for the Only Chat sandbox: the toolchains, built here once and pulled by only-chat's own
# sandbox/Dockerfile, which adds what is tied to its code (run helpers, sandbox-shim, environment).
#
# Toolchains live in /opt and /usr/local so the backed-up HOME stays small.
# Nothing may exist under /workspace in this image: restoring a backup over an
# image-provided directory fails with EXDEV.

FROM debian:trixie-slim

ARG UV_VERSION=0.12.21
ARG NODE_VERSION=24.21.0
ARG PNPM_VERSION=12.8.2
ARG BUN_VERSION=1.4.2
# Quoted in only-chat's sandbox_exec tool description (src/plugins/sandbox/server/index.ts); change both together.
# The PyPI and npm packages must stay on this same version so they share one browser build.
ARG PLAYWRIGHT_VERSION=1.63.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git curl ca-certificates zip unzip jq ripgrep tmux procps less file build-essential xz-utils tini \
 && rm -rf /var/lib/apt/lists/*

# uv, Python 3.12 (python/python3 in /usr/local/bin) and the default venv.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_CACHE_DIR=/tmp/uv-cache
RUN set -eux; \
    case "$(uname -m)" in x86_64) a=x86_64;; aarch64) a=aarch64;; *) exit 1;; esac; \
    f="uv-${a}-unknown-linux-gnu.tar.gz"; u="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}"; \
    cd /tmp; curl -fsSLO "$u/$f"; curl -fsSLO "$u/$f.sha256"; sha256sum -c "$f.sha256"; \
    tar -xzf "$f" --strip-components=1 -C /usr/local/bin "uv-${a}-unknown-linux-gnu/uv" "uv-${a}-unknown-linux-gnu/uvx"; \
    rm -f "$f" "$f.sha256"; \
    uv python install 3.12 --default; \
    uv venv /opt/venv --python 3.12; \
    VIRTUAL_ENV=/opt/venv uv pip install --link-mode=copy \
      numpy pandas matplotlib requests openpyxl pillow beautifulsoup4 lxml; \
    rm -rf /tmp/uv-cache

# Node.js (official binary tarball) and pnpm.
RUN set -eux; \
    case "$(uname -m)" in x86_64) a=x64;; aarch64) a=arm64;; *) exit 1;; esac; \
    f="node-v${NODE_VERSION}-linux-${a}.tar.xz"; u="https://nodejs.org/dist/v${NODE_VERSION}"; \
    cd /tmp; curl -fsSLO "$u/$f"; curl -fsSLO "$u/SHASUMS256.txt"; \
    grep " $f\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
      --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'; \
    rm -f "$f" SHASUMS256.txt; \
    NPM_CONFIG_PREFIX=/usr/local npm install -g "pnpm@${PNPM_VERSION}"; \
    rm -rf /root/.npm /tmp/*

# bun (official release zip).
RUN set -eux; \
    case "$(uname -m)" in x86_64) a=x64;; aarch64) a=aarch64;; *) exit 1;; esac; \
    f="bun-linux-${a}.zip"; u="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}"; \
    cd /tmp; curl -fsSLO "$u/$f"; curl -fsSLO "$u/SHASUMS256.txt"; \
    grep " $f\$" SHASUMS256.txt | sha256sum -c -; \
    unzip -q "$f"; install -m 0755 "bun-linux-${a}/bun" /usr/local/bin/bun; \
    ln -s bun /usr/local/bin/bunx; \
    rm -rf /tmp/*

# Playwright with a headless Chromium shell. The browser lives in /opt (not HOME, never /workspace) and
# the Python and npm packages share it; npm must not download a second copy.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN set -eux; \
    VIRTUAL_ENV=/opt/venv uv pip install --link-mode=copy "playwright==${PLAYWRIGHT_VERSION}"; \
    /opt/venv/bin/playwright install --with-deps --only-shell chromium; \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 NPM_CONFIG_PREFIX=/usr/local npm install -g "playwright@${PLAYWRIGHT_VERSION}"; \
    rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /tmp/*
