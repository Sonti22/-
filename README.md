# Stripe Django Shop

Учебный pet-project: минимальный магазин на Django + Stripe Checkout.

## Live-demo

<https://stripe-django-shop.onrender.com>

## Быстрый старт

```bash
git clone https://github.com/Sonti22/stripe-django-shop.git
cd stripe-django-shop
cp .env.example .env          # заполните своими Stripe keys
docker compose up --build     # приложение будет на http://localhost:8000
```

## API

| Метод | URL | Описание |
| ----- | --- | -------- |
| `GET` | `/item/<id>` | HTML-карточка товара |
| `GET` | `/buy/<id>` | Создать Stripe Session на один товар |
| `POST` | `/order/create` | Создать заказ `{item_ids:[], discount_id?, tax_id?}` |
| `GET` | `/order/<id>` | Stripe Session на весь заказ |

## CI/CD

GitHub Actions прогоняет `flake8` и `pytest`, затем собирает Docker-образ, пушит его на Docker Hub и триггерит деплой в Render. Полный workflow смотрите в `.github/workflows/ci.yml`.

## Лицензия

MIT
