# Step 4: non-root USER (DL3002) and exec-form CMD (DL3025) -> clean.
FROM python:3.12.7-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Single layer, no extra packages, pinned version, apt cache removed.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=7.88.1-10+deb12u15 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first so this layer is cached between code changes.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Run as an unprivileged user instead of root.
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -fsS http://localhost:5000/health || exit 1

# Exec form so the process receives signals (SIGTERM) directly.
CMD ["python", "app.py"]
