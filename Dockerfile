# Use a stable Python 3.11 image
FROM python:3.11-slim

# Install system deps required to build/run numpy, scipy, pandas, xgboost
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc g++ gfortran \
    git \
    ca-certificates \
    pkg-config \
    libatlas3-base libatlas-base-dev \
    libopenblas-dev liblapack-dev libblas-dev \
    libgfortran5 \
    libffi-dev \
    libssl-dev \
    wget \
 && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements & install Python deps (upgrade pip tooling first)
COPY requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . /app

# Create and use non-root user (optional)
RUN useradd --create-home appuser || true
USER appuser

# Expose port for Railway (Railway sets $PORT at runtime)
ENV PORT 8080
EXPOSE 8080

# Default command
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:$PORT", "--workers", "2", "--threads", "4"]
