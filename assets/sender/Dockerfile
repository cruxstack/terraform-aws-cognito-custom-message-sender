# Builds the Go sender (cruxstack/cognito-custom-message-sender-go) for AWS
# Lambda (provided.al2023) and packages it with the email and SMS policies.

# --------------------------------------------------------------------- base ---

FROM golang:1.27 AS base

# a git tag or other ref of the sender; "latest" builds the default branch
ARG APP_VERSION=v3.0.0
ARG GOARCH=arm64

ENV GOOS=linux
ENV GOARCH=${GOARCH}
ENV CGO_ENABLED=0

WORKDIR /opt/app

RUN git clone https://github.com/cruxstack/cognito-custom-message-sender-go.git . \
    && if [ "$APP_VERSION" != "latest" ]; then git checkout "$APP_VERSION"; fi
RUN go mod download
RUN go build -trimpath -tags lambda.norpc -ldflags "-s -w -X main.version=${APP_VERSION}" -o dist/bootstrap .

# the policies are passed base64-encoded so any content survives a build arg;
# a sender that is disabled has no policy
ARG EMAIL_POLICY_ENCODED=""
ARG SMS_POLICY_ENCODED=""
RUN if [ -n "$EMAIL_POLICY_ENCODED" ]; then echo "$EMAIL_POLICY_ENCODED" | base64 -d > dist/policy.rego; fi \
    && if [ -n "$SMS_POLICY_ENCODED" ]; then echo "$SMS_POLICY_ENCODED" | base64 -d > dist/sms-policy.rego; fi

# ------------------------------------------------------------------ package ---

FROM alpine:3 AS package

COPY --from=base /opt/app/dist /opt/app/dist

RUN apk add --no-cache zip \
    && cd /opt/app/dist \
    && zip -r /tmp/package.zip .
