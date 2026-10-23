# Step 2: one RUN, -y, --no-install-recommends, pinned version, clean apt cache
# (fixes DL3008, DL3009, DL3014, DL3015, DL3059).
FROM python:3.12.7-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=7.88.1-10+deb12u15 \
    && rm -rf /var/lib/apt/lists/*

ADD . /app
WORKDIR /app

RUN pip install -r app/requirements.txt

USER root
EXPOSE 5000
CMD python app/app.py
