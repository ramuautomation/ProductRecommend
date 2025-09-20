# Dockerfile — deterministic build using python 3.11 and required system libs
FROM python:3.11-slim

# Install system deps required to build/run numpy, scipy, pandas, xgboost
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc g++ gfortran \
    git \
    ca-certificates \
    pkg-config \
    libopenblas-dev \
    liblapack-dev \
    libblas-dev \
    libgfortran5 \
    libffi-dev \
    libssl-dev \
    wget \
	 unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements & install Python deps (upgrade pip tooling first)
COPY requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

# Copy vendored NLTK data into the image (deterministic)
COPY nltk_data /usr/local/share/nltk_data
RUN chmod -R a+rX /usr/local/share/nltk_data || true

# Ensure NLTK searches our directory first
ENV NLTK_DATA=/usr/local/share/nltk_data:/home/appuser/nltk_data

# Copy application code
COPY . /app

# Create a writable home nltk_data for appuser and set permissions
RUN useradd --create-home appuser || true \
 && mkdir -p /home/appuser/nltk_data \
 && chown -R appuser:appuser /home/appuser/nltk_data \
 && chmod -R 755 /usr/local/share/nltk_data

# Make sure NLTK_DATA env includes build-time location first, then user home
ENV NLTK_DATA=/usr/local/share/nltk_data:/home/appuser/nltk_data

# Switch to non-root user
USER appuser

# Railway will set $PORT at runtime; expose a default
ENV PORT 8080
EXPOSE 8080

# Use shell form so $PORT expands inside container
CMD gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --threads 4
