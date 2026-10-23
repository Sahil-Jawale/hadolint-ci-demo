# Deliberately BAD Dockerfile - every line below breaks a best practice.
FROM python:latest

RUN apt-get update
RUN apt-get install curl

ADD . /app
WORKDIR /app

RUN pip install -r app/requirements.txt

USER root
EXPOSE 5000
CMD python app/app.py
