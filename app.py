# app.py (Option A - Eager load, use with --preload)
from flask import Flask, request, render_template
import nltk
import os
from nltk.data import find
app = Flask(__name__)

#import nltk

def ensure_nltk_data():
    """
    Ensure required NLTK resources exist. Do NOT download by default at runtime.
    If resources are missing, behavior depends on ALLOW_RUNTIME_NLTK_DOWNLOAD env var:
      - "true"  => attempt runtime download (dev only; may race if multiple workers)
      - otherwise => raise RuntimeError so the process exits with a clear error.
    """
    resources = [
        ("tokenizers/punkt", "punkt"),
        ("tokenizers/punkt_tab/english", "punkt_tab"),
        ("corpora/stopwords", "stopwords"),
        ("corpora/wordnet", "wordnet"),
        ("corpora/omw-1.4", "omw-1.4"),
        ("taggers/averaged_perceptron_tagger", "averaged_perceptron_tagger"),
        ("taggers/averaged_perceptron_tagger_eng", "averaged_perceptron_tagger"),
    ]

    missing = []
    for path, pkg in resources:
        try:
            find(path)
        except LookupError:
            missing.append((path, pkg))

    if not missing:
        print("NLTK data ensured (found all resources).")
        return

    # If runtime downloads are explicitly allowed (for dev), perform them
    allow_runtime = os.getenv("ALLOW_RUNTIME_NLTK_DOWNLOAD", "false").lower() == "true"
    if allow_runtime:
        print("NLTK: missing resources detected; ALLOW_RUNTIME_NLTK_DOWNLOAD=true -> attempting downloads")
        for path, pkg in missing:
            print(f"NLTK: downloading {pkg} for path {path} ...")
            nltk.download(pkg)
        # re-check and raise if still missing
        still_missing = []
        for path, pkg in resources:
            try:
                find(path)
            except LookupError:
                still_missing.append((path, pkg))
        if still_missing:
            raise RuntimeError(f"NLTK runtime download failed for: {still_missing}")
        print("NLTK runtime downloads complete.")
        return

    # Otherwise fail fast with a helpful message
    missing_paths = [p for p, _ in missing]
    raise RuntimeError(
        "Missing NLTK resources: {}. Pre-download resources in your Dockerfile or set "
        "ALLOW_RUNTIME_NLTK_DOWNLOAD=true for dev (not recommended in production).".format(missing_paths)
    )

# call once at startup (before importing modules that use NLTK)
ensure_nltk_data()
print("NLTK data ensured — now importing model module")

# import AFTER ensure_nltk_data
from model import SentimentRecommenderModel

# Eagerly load the model at module import time.
# With gunicorn --preload this happens once in master process and memory can be shared.
sentiment_model = SentimentRecommenderModel()


@app.route("/health")
def health():
    return {"status": "ok"}

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/predict', methods=['POST'])
def prediction():
    user = request.form['userName'].lower()
    items = sentiment_model.getSentimentRecommendations(user)

    if items is not None:
        return render_template("index.html",
                               column_names=items.columns.values,
                               row_data=list(items.values.tolist()),
                               zip=zip)
    else:
        return render_template("index.html", message="User Name doesn't exists, No product recommendations at this point of time!", alert_type="danger")


if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
