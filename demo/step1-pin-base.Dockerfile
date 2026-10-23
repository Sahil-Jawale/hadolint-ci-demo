# Step 1: pin the base image to an exact, small tag (fixes DL3007).
FROM python:3.12.7-slim-bookworm

RUN apt-get update
RUN apt-get install curl

ADD . /app
WORKDIR /app

RUN pip install -r app/requirements.txt

USER root
EXPOSE 5000
CMD python app/app.py
