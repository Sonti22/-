#!/usr/bin/env bash
set -e

REPO_URL="git@github.com:Sonti22/stripe-django-shop.git"
REPO_DIR="stripe-django-shop"

# --- клонируем, если нужно ---
[[ -d $REPO_DIR ]] || git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# --- структура каталогов ---
mkdir -p shop checkout checkout/templates .github/workflows tests

# --- .gitignore ---
cat > .gitignore <<'EOF2'
__pycache__/
*.pyc
.env
venv/
EOF2

# --- requirements.txt ---
cat > requirements.txt <<'EOF2'
Django==4.2.11
stripe==9.3.0
python-dotenv==1.0.1
gunicorn==22.0.0
pytest==8.2.1
pytest-django==4.8.0
flake8==7.0.0
EOF2

# --- manage.py ---
cat > manage.py <<'EOF2'
#!/usr/bin/env python
import os, sys
if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "shop.settings")
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)
EOF2
chmod +x manage.py

# --- shop/__init__.py ---
touch shop/__init__.py

# --- shop/settings.py ---
cat > shop/settings.py <<'EOF2'
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "dev-secret")
DEBUG = True
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "checkout",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
]

ROOT_URLCONF = "shop.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.debug",
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]
WSGI_APPLICATION = "shop.wsgi.application"

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3",
                         "NAME": BASE_DIR / "db.sqlite3"}}

STATIC_URL = "/static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
EOF2

# --- shop/urls.py ---
cat > shop/urls.py <<'EOF2'
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("checkout.urls")),
]
EOF2

# --- shop/wsgi.py ---
cat > shop/wsgi.py <<'EOF2'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "shop.settings")
application = get_wsgi_application()
EOF2

# --- checkout/__init__.py ---
touch checkout/__init__.py

# --- checkout/models.py ---
cat > checkout/models.py <<'EOF2'
from django.db import models

class Item(models.Model):
    CURRENCIES = (("usd", "USD"), ("eur", "EUR"))
    name = models.CharField(max_length=120)
    description = models.TextField()
    price = models.PositiveIntegerField(help_text="в копейках/центах")
    currency = models.CharField(max_length=3, choices=CURRENCIES, default="usd")
    def __str__(self): return self.name

class Discount(models.Model):
    stripe_coupon_id = models.CharField(max_length=50)
    name = models.CharField(max_length=50, default="discount")
    def __str__(self): return self.name

class Tax(models.Model):
    stripe_tax_id = models.CharField(max_length=50)
    name = models.CharField(max_length=50, default="tax")
    def __str__(self): return self.name

class Order(models.Model):
    items = models.ManyToManyField(Item)
    discount = models.ForeignKey(Discount, null=True, blank=True, on_delete=models.SET_NULL)
    tax = models.ForeignKey(Tax, null=True, blank=True, on_delete=models.SET_NULL)
    created = models.DateTimeField(auto_now_add=True)

    def total_amount(self): return sum(i.price for i in self.items.all())
    def currency(self): return self.items.first().currency if self.items.exists() else "usd"
    def __str__(self): return f"Order #{self.pk}"
EOF2

# --- checkout/admin.py ---
cat > checkout/admin.py <<'EOF2'
from django.contrib import admin
from .models import Item, Order, Discount, Tax
admin.site.register((Item, Order, Discount, Tax))
EOF2

# --- checkout/stripe.py ---
cat > checkout/stripe.py <<'EOF2'
import os, stripe
from functools import lru_cache

@lru_cache
def pub_key(cur): return os.getenv(f"STRIPE_PUB_KEY_{cur.upper()}")
@lru_cache
def sec_key(cur): return os.getenv(f"STRIPE_SEC_KEY_{cur.upper()}")
def set_api(cur): stripe.api_key = sec_key(cur)
EOF2

# --- checkout/views.py ---
cat > checkout/views.py <<'EOF2'
import json, stripe
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render
from django.urls import path
from .models import Item, Order
from .stripe import pub_key, sec_key

def item_detail(request, id):
    item = get_object_or_404(Item, pk=id)
    return render(request, "item.html", {"item": item, "stripe_pub": pub_key(item.currency)})

def buy(request, id):
    item = get_object_or_404(Item, pk=id)
    session = stripe.checkout.Session.create(
        line_items=[{
            "price_data": {
                "currency": item.currency,
                "product_data": {"name": item.name},
                "unit_amount": item.price,
            }, "quantity": 1}],
        mode="payment",
        success_url=request.build_absolute_uri("/success"),
        cancel_url=request.build_absolute_uri(f"/item/{id}"),
        api_key=sec_key(item.currency),
    )
    return JsonResponse({"id": session.id})

def create_order(request):
    data = json.loads(request.body)
    order = Order.objects.create(discount_id=data.get("discount_id"), tax_id=data.get("tax_id"))
    order.items.set(data["item_ids"])
    return JsonResponse({"order_id": order.id})

def order_checkout(request, id):
    order = get_object_or_404(Order, pk=id)
    lines=[{"price_data":{"currency":order.currency(),
                          "product_data":{"name":it.name},
                          "unit_amount":it.price},"quantity":1}
           for it in order.items.all()]
    session = stripe.checkout.Session.create(
        line_items=lines,
        mode="payment",
        success_url=request.build_absolute_uri("/success"),
        cancel_url=request.build_absolute_uri(f"/order/{id}"),
        api_key=sec_key(order.currency()),
    )
    return JsonResponse({"id": session.id})

urlpatterns = [
    path("item/<int:id>", item_detail),
    path("buy/<int:id>", buy),
    path("order/create", create_order),
    path("order/<int:id>", order_checkout),
]
EOF2

# --- checkout/templates/item.html ---
cat > checkout/templates/item.html <<'EOF2'
<!doctype html><html><head>
  <title>{{ item.name }}</title>
  <script src="https://js.stripe.com/v3/"></script>
</head><body>
  <h1>{{ item.name }}</h1><p>{{ item.description }}</p>
  <p>{{ item.price }} {{ item.currency|upper }}</p>
  <button id="buy-btn">Buy</button>
  <script>
    const stripe = Stripe("{{ stripe_pub }}");
    document.getElementById("buy-btn").onclick = async () => {
      const r = await fetch("/buy/{{ item.id }}"); const {id} = await r.json();
      stripe.redirectToCheckout({sessionId: id});
    };
  </script>
</body></html>
EOF2

# --- Dockerfile ---
cat > Dockerfile <<'EOF2'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["gunicorn", "shop.wsgi:application", "--bind", "0.0.0.0:8000"]
EOF2

# --- docker-compose.yml ---
cat > docker-compose.yml <<'EOF2'
version: "3.9"
services:
  web:
    build: .
    ports: ["8000:8000"]
    env_file: .env
EOF2

# --- pytest.ini ---
cat > pytest.ini <<'EOF2'
[pytest]
DJANGO_SETTINGS_MODULE = shop.settings
python_files = tests.py test_*.py *_tests.py
EOF2

# --- tests/test_checkout.py ---
cat > tests/test_checkout.py <<'EOF2'
import pytest
from checkout.models import Item, Order

@pytest.mark.django_db
def test_total_amount():
    i1 = Item.objects.create(name="A", price=100, currency="usd")
    i2 = Item.objects.create(name="B", price=200, currency="usd")
    o = Order.objects.create(); o.items.set([i1, i2])
    assert o.total_amount() == 300
EOF2

# --- .flake8 ---
cat > .flake8 <<'EOF2'
[flake8]
max-line-length = 120
exclude = venv, .git, __pycache__, migrations
EOF2

# --- .env.example ---
cat > .env.example <<'EOF2'
DJANGO_SECRET_KEY=changeme
STRIPE_PUB_KEY_USD=pk_test_xxx
STRIPE_SEC_KEY_USD=sk_test_xxx
STRIPE_PUB_KEY_EUR=pk_live_xxx
STRIPE_SEC_KEY_EUR=sk_live_xxx
EOF2

# --- GitHub Actions workflow ---
cat > .github/workflows/ci.yml <<'EOF2'
name: CI/CD
on: {push: {branches: [main]}, pull_request: {branches: [main]}}
env: {IMAGE_NAME: sonti22/stripe-django-shop}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: '3.11'}
      - run: pip install -r requirements.txt flake8 pytest pytest-django
      - run: flake8 .
      - run: |
          export DJANGO_SECRET_KEY=test
          python manage.py migrate
          pytest -q
  docker:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.IMAGE_NAME }}:latest
  render-deploy:
    needs: docker
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Render Deploy
        run: |
          curl -X POST \
          -H "Authorization: Bearer ${{ secrets.RENDER_API_KEY }}" \
          -H "Content-Type: application/json" \
          -d '{"serviceId":"${{ secrets.RENDER_SERVICE_ID }}"}' \
          https://api.render.com/v1/services/${{ secrets.RENDER_SERVICE_ID }}/deploys
EOF2

# --- render.yaml ---
cat > render.yaml <<'EOF2'
services:
  - type: web
    name: stripe-django-shop
    env: docker
    plan: free
    region: frankfurt
    dockerContext: .
    healthCheckPath: /
    envVars:
      - key: DJANGO_SECRET_KEY
        sync: false
      - key: STRIPE_PUB_KEY_USD
        sync: false
      - key: STRIPE_SEC_KEY_USD
        sync: false
      - key: STRIPE_PUB_KEY_EUR
        sync: false
      - key: STRIPE_SEC_KEY_EUR
        sync: false
EOF2

# --- README.md ---
cat > README.md <<'EOF2'
# Stripe\u00a0Django\u00a0Shop

\u041c\u0438\u043d\u0438\u2011\u043c\u0430\u0433\u0430\u0437\u0438\u043d \u043d\u0430 Django\u00a0+\u00a0Stripe Checkout.

## \u041b\u043e\u043a\u0430\u043b\u044c\u043d\u044b\u0439 \u0437\u0430\u043f\u0443\u0441\u043a

```bash
git clone https://github.com/Sonti22/stripe-django-shop.git
cd stripe-django-shop
cp .env.example .env      # \u0432\u0441\u0442\u0430\u0432\u044c\u0442\u0435 Stripe\u2011\u043a\u043b\u044e\u0447\u0438
docker compose up --build # http://localhost:8000
API
\u041c\u0435\u0442\u043e\u0434\tURL\t\u041e\u043f\u0438\u0441\u0430\u043d\u0438\u0435
GET\t/item/<id>\t\u0421\u0442\u0440\u0430\u043d\u0438\u0446\u0430 \u0442\u043e\u0432\u0430\u0440\u0430
GET\t/buy/<id>\tStripe \u0447\u0435\u043a \u043d\u0430 \u0442\u043e\u0432\u0430\u0440
POST\t/order/create\t\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0437\u0430\u043a\u0430\u0437 JSON body
GET\t/order/<id>\tStripe \u0447\u0435\u043a \u043d\u0430 \u0437\u0430\u043a\u0430\u0437

CI/CD
GitHub Actions: flake8 + pytest \u2192 Docker Hub push \u2192 Render deploy

Secrets: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN, RENDER_API_KEY, RENDER_SERVICE_ID

\u041b\u0438\u0446\u0435\u043d\u0437\u0438\u044f MIT.
EOF2

--- \u043f\u0435\u0440\u0432\u044b\u0439 \u043a\u043e\u043c\u043c\u0438\u0442 ---
git add .
git commit -m "bootstrap project v2"
git push origin main
