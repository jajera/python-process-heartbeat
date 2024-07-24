FROM mcr.microsoft.com/devcontainers/python:1-3.12-bullseye

RUN apt-get update -y \
  && export DEBIAN_FRONTEND=noninteractive \
  # awscli
  && apt-get install -y awscli \
  # aws-vault
  && curl -L -o /usr/local/bin/aws-vault https://github.com/99designs/aws-vault/releases/latest/download/aws-vault-linux-amd64 \
  && chmod 755 /usr/local/bin/aws-vault \
  # terraform
  && apt-get install -y apt-utils gnupg software-properties-common \
  && curl -s https://apt.releases.hashicorp.com/gpg | gpg --dearmor > hashicorp.gpg \
  && install -o root -g root -m 644 hashicorp.gpg /etc/apt/trusted.gpg.d/ \
  && apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  && apt-get update -y \
  && apt-get install -y terraform \
  && rm hashicorp.gpg \
  # python module
  && pip install --upgrade pip \
  && pip install boto3
