# Agentic API (BFF) container image — built remotely in ACR via azd.
# PYTHON_IMAGE selects the base image. The default below is the PUBLIC Docker Hub image, which on
# shared CI/ACR build agents is frequently rate-limited ("toomanyrequests") and may require a
# Docker Hub login. Override PYTHON_IMAGE to point at ANY registry you have access to — e.g. your
# own ACR (cr*.azurecr.io/python:3.11-slim), the Microsoft Artifact Registry Docker mirror
# (mcr.microsoft.com/mirror/docker/library/python:3.11-slim), or an authenticated Docker Hub.
# azd sets it to the project ACR copy via azure.yaml buildArgs (see infra/scripts/postprovision).
ARG PYTHON_IMAGE=python:3.11-slim
FROM ${PYTHON_IMAGE}

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app

COPY pyproject.toml ./
RUN pip install --no-cache-dir .

COPY . .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
