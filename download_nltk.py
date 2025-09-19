import nltk
for pkg in ["stopwords","punkt","punkt_tab","averaged_perceptron_tagger","wordnet","omw-1.4"]:
    try:
        nltk.data.find(pkg if pkg=="punkt" or pkg=="punkt_tab" else f"corpora/{pkg}")
    except LookupError:
        nltk.download(pkg)
print("nltk downloads complete")