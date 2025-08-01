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

GitHub Actions прогоняет `flake8` и `pytest`, затем собирает Docker-образ,
пушит его на Docker Hub и триггерит деплой в Render. Полный workflow смотрите в
`.github/workflows/ci.yml`.

## Тесты

Для локального запуска тестов повторите шаги из CI:

```bash
pip install -r requirements.txt flake8 pytest pytest-django
export DJANGO_SECRET_KEY=test
python manage.py migrate --noinput
pytest -q
```

## Лицензия

Проект распространяется под лицензией MIT. Полный текст смотрите в файле
`LICENSE`.

## Сервисный скрипт

`phpmyadmin_users_dump.py` демонстрирует работу с phpMyAdmin через HTTP-запросы.
Скрипт логинится, выполняет `SELECT * FROM users` и выводит результат в консоль.
Перед запуском создайте `.env` и укажите в нём:

```
PHPMA_URL=https://example.com/phpmyadmin/
PHPMA_USERNAME=login
PHPMA_PASSWORD=secret
PHPMA_DB_NAME=testDB
PHPMA_TABLE_NAME=users
```

Затем установите зависимости и запустите файл:

```bash
pip install requests beautifulsoup4 lxml
python phpmyadmin_users_dump.py
```

Обратите внимание: в Codex сетевые запросы к указанному хосту могут быть заблокированы, поэтому пример может не выполниться.

## Служебные файлы

В корне репозитория присутствуют несколько текстовых файлов (`first`, `second`,
`Third.txt` и т.д.). Они использовались для демонстрации работы Git и не влияют
на функционирование проекта.

