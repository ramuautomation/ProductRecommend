# Dockerfile — python 3.11 slim with NLTK corpora predownload
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps required for numeric libs and build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ gfortran git ca-certificates pkg-config \
    libopenblas-dev liblapack-dev libblas-dev libgfortran5 libffi-dev \
    libssl-dev wget unzip curl \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user (security)
ARG APP_USER=appuser
ARG APP_UID=1000
RUN groupadd -g ${APP_UID} ${APP_USER} || true \
 && useradd -m -s /bin/bash -u ${APP_UID} -g ${APP_USER} ${APP_USER}

WORKDIR /app

# Copy requirements and install python deps
COPY requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r /app/requirements.txt

# Configure NLTK data location and create folder
ENV NLTK_DATA=/usr/share/nltk_data
RUN mkdir -p ${NLTK_DATA}

# Pre-download required NLTK packages at build time to avoid runtime lookup errors
# (adjust list if you need more/less)
RUN python - <<'PY'
import nltk, sys
pkgs = ['punkt', 'stopwords', 'averaged_perceptron_tagger', 'wordnet','punkt_tab','omw-1.4','averaged_perceptron_tagger_eng']
for pkg in pkgs:
    try:
        nltk.download(pkg, download_dir='/usr/share/nltk_data')
    except Exception as e:
        print('NLTK download failed for', pkg, e, file=sys.stderr)
PY

# Copy app code
COPY . /app

# Ensure app and nltk_data owned by non-root user
RUN chown -R ${APP_USER}:${APP_USER} /app /usr/share/nltk_data

# Expose port and switch to non-root user
ENV PORT=8080
EXPOSE 8080
USER ${APP_USER}

# Start gunicorn (respects $PORT)
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4"]
