# --------------------------------------------------------------------- base ---

FROM golang:1.22 as base

ARG APP_VERSION=latest

ENV GOOS=linux
ENV GOARCH=amd64
ENV CGO_ENABLED=0

RUN mkdir -p /opt/app
WORKDIR /opt/app

RUN git clone https://github.com/cruxstack/cognito-custom-message-sender-go.git .
RUN if [ "$APP_VERSION" != "latest" ] ; then git checkout $APP_VERSION ; fi
RUN go mod download
RUN go build -o bootstrap

ARG SERVICE_OPA_POLICY_ENCODED=cGFja2FnZSBjb2duaXRvX2N1c3RvbV9zZW5kZXJfZW1haWxfcG9saWN5CnJlc3VsdCA6PSB7CgkiYWN0aW9uIjogImJsb2NrIiwKCSJibG9jayI6IHsKCQkibWVzc2FnZSI6ICJwb2xpY3kgd2FzIG5vdCBkZWZpbmVkIgoJfSwKfQo=
RUN echo "$SERVICE_OPA_POLICY_ENCODED" | base64 -d > /opt/app/policy.rego

# ------------------------------------------------------------------ package ---

FROM alpine:latest as package

COPY --from=base /opt/app/bootstrap /opt/app/dist/bootstrap
COPY --from=base /opt/app/policy.rego /opt/app/dist/policy.rego

RUN apk add zip \
    && cd /opt/app/dist \
    && zip -r /tmp/package.zip .
