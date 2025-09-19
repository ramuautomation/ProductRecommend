# app.py (Option A - Eager load, use with --preload)
from flask import Flask, request, render_template
import nltk
import os

app = Flask(__name__)

#import nltk

def ensure_nltk_data():
    # list of (nltk.data.find path, nltk.download name) pairs
    resources = [
        ("tokenizers/punkt", "punkt"),
        ("tokenizers/punkt_tab/english", "punkt_tab"),
        ("corpora/stopwords", "stopwords"),
        ("corpora/wordnet", "wordnet"),
        ("corpora/omw-1.4", "omw-1.4"),
        # averaged_perceptron_tagger JSON resource & language-specific variant
        ("taggers/averaged_perceptron_tagger", "averaged_perceptron_tagger"),
        ("taggers/averaged_perceptron_tagger_eng", "averaged_perceptron_tagger"),
    ]

    for path, pkg in resources:
        try:
            nltk.data.find(path)
        except LookupError:
            print(f"NLTK: downloading {pkg} for path {path} ...")
            nltk.download(pkg)

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
