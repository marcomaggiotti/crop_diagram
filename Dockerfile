# ── Stage 1: builder ─────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# System deps needed to compile some wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM python:3.11-slim

# OpenCV headless runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user for security
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

COPY diagram_cropping_api.py .

USER appuser

# Render injects $PORT at runtime; default to 8000 for local dev
ENV PORT=8000

EXPOSE $PORT

# Graceful shutdown with --timeout-graceful-shutdown gives in-flight requests
# time to finish before the container stops.
CMD ["sh", "-c", \
     "uvicorn diagram_cropping_api:app \
       --host 0.0.0.0 \
       --port $PORT \
       --workers 2 \
       --timeout-graceful-shutdown 10 \
       --log-level info"]