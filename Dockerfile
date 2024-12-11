# The python version must match the version in .python-version
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ARG HANDLER
ENV HANDLER=${HANDLER}

# Install node-js (we'll need it for jsii)
RUN apt-get update && apt-get install -y curl && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install api-spec-converter
RUN npm install -g api-spec-converter

ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy PYTHONPATH=.
WORKDIR /app
COPY uv.lock pyproject.toml /app/

RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-install-project --no-dev --no-python-downloads

COPY . /app

RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-dev --no-python-downloads

WORKDIR /app
# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Run the service using the path to the handler
CMD ["python", "./provider/main.py"]
