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

# --- Install NLTK data by downloading the nltk_data gh-pages tarball and copying packages ---
RUN set -eux; \
    DEST=/usr/local/share/nltk_data; \
    mkdir -p "$DEST"; \
    # download the gh-pages tarball and extract only the packages/* subdir
    TAR_URL="https://github.com/nltk/nltk_data/archive/refs/heads/gh-pages.tar.gz"; \
    echo "Downloading $TAR_URL"; \
    wget -q -O /tmp/nltk_data.tar.gz "$TAR_URL"; \
    mkdir -p /tmp/nltk_data_unpack; \
    tar -xzf /tmp/nltk_data.tar.gz -C /tmp/nltk_data_unpack --strip-components=2 "nltk_data-gh-pages/packages/"; \
    # copy the necessary package directories into DEST (create parents)
    mkdir -p "$DEST/tokenizers" "$DEST/corpora" "$DEST/taggers"; \
    cp -R /tmp/nltk_data_unpack/tokenizers/punkt "$DEST/tokenizers/punkt"; \
    cp -R /tmp/nltk_data_unpack/tokenizers/punkt_tab "$DEST/tokenizers/punkt_tab"; \
    cp -R /tmp/nltk_data_unpack/corpora/stopwords "$DEST/corpora/stopwords"; \
    cp -R /tmp/nltk_data_unpack/corpora/wordnet "$DEST/corpora/wordnet"; \
    cp -R /tmp/nltk_data_unpack/corpora/omw-1.4 "$DEST/corpora/omw-1.4"; \
    cp -R /tmp/nltk_data_unpack/taggers/averaged_perceptron_tagger "$DEST/taggers/averaged_perceptron_tagger"; \
    cp -R /tmp/nltk_data_unpack/taggers/averaged_perceptron_tagger_eng "$DEST/taggers/averaged_perceptron_tagger_eng"; \
    # cleanup
    rm -rf /tmp/nltk_data.tar.gz /tmp/nltk_data_unpack; \
    # make sure files are readable by non-root user and directories accessible
    chmod -R a+rX "$DEST"; \
    echo "NLTK data copied to $DEST"

# Ensure NLTK searches our directory first
ENV NLTK_DATA=/usr/local/share/nltk_data:/home/appuser/nltk_data

# Verify presence
RUN python - <<'PY'
from nltk.data import find
req = ['tokenizers/punkt','tokenizers/punkt_tab/english','corpora/stopwords',
       'corpora/wordnet','corpora/omw-1.4',
       'taggers/averaged_perceptron_tagger','taggers/averaged_perceptron_tagger_eng']
missing=[]
for r in req:
    try:
        p=find(r)
        print("FOUND", r, "->", p)
    except Exception as e:
        print("MISSING", r, ":", e)
        missing.append(r)
if missing:
    raise SystemExit("Missing NLTK resources after copy: "+str(missing))
print("NLTK verification OK")
PY

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
