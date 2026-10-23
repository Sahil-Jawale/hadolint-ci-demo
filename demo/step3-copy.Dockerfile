# Step 3: COPY instead of ADD (DL3020) and pip --no-cache-dir (DL3042).
FROM python:3.12.7-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=7.88.1-10+deb12u15 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .

USER root
EXPOSE 5000
CMD python app.py
