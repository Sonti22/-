FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["gunicorn", "shop.wsgi:application", "--bind", "0.0.0.0:8000"]
