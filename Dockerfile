FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt /app/
RUN python -m pip install --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt
COPY . /app
ENV PORT=8080
EXPOSE 8080
CMD ["gunicorn", "--workers", "3", "--bind", "0.0.0.0:8080", "app:app", "--timeout", "120"]
