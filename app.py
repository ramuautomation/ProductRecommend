# app.py (Option A - Eager load, use with --preload)
from flask import Flask, request, render_template
import nltk
import os
from model import SentimentRecommenderModel

app = Flask(__name__)

def ensure_nltk_data():
    packages = ["stopwords", "punkt", "averaged_perceptron_tagger", "wordnet", "omw-1.4"]
    for pkg in packages:
        try:
            if pkg == "punkt":
                nltk.data.find("tokenizers/punkt")
            else:
                nltk.data.find(f"corpora/{pkg}")
        except LookupError:
            nltk.download(pkg)

# Ensure NLTK packages are present before loading the model
ensure_nltk_data()

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
        return render_template("index.html",
                               message="User Name doesn't exists, No product recommendations at this point of time!")

@app.route('/predictSentiment', methods=['POST'])
def predict_sentiment():
    review_text = request.form["reviewText"]
    pred_sentiment = sentiment_model.classify_sentiment(review_text)
    return render_template("index.html", sentiment=pred_sentiment)

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
