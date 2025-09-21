# app.py (Option A - Eager load, use with --preload)
from flask import Flask, request, render_template
import nltk
import os
from nltk.data import find
from nltk import data as nltk_data


app = Flask(__name__)

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
