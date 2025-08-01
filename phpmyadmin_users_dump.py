#!/usr/bin/env python3
"""
phpmyadmin_users_dump.py
-------------------------------------
Логинится в phpMyAdmin ➜ выполняет SELECT * FROM users ➜
печатает данные в консоль в удобочитаемом виде.

Зависимости:
    pip install requests beautifulsoup4 lxml
Python ≥ 3.8
"""

from __future__ import annotations

import os
from urllib.parse import urljoin

from dotenv import load_dotenv
import requests
from bs4 import BeautifulSoup

load_dotenv()

BASE_URL = os.getenv("PHPMA_URL", "https://example.com/phpmyadmin/")
USERNAME = os.getenv("PHPMA_USERNAME")
PASSWORD = os.getenv("PHPMA_PASSWORD")
DB_NAME = os.getenv("PHPMA_DB_NAME", "testDB")
TABLE_NAME = os.getenv("PHPMA_TABLE_NAME", "users")

if not USERNAME or not PASSWORD:
    raise RuntimeError(
        "PHPMA_USERNAME and PHPMA_PASSWORD environment variables must be set"
    )


def _extract_token(html: str) -> str:
    """Парсит CSRF-token из HTML-страницы phpMyAdmin."""
    soup = BeautifulSoup(html, "lxml")
    token_tag = soup.find("input", {"name": "token"})
    if not token_tag:
        raise RuntimeError("Не удалось найти CSRF-token. Проверьте версию phpMyAdmin.")
    return token_tag["value"]


def _pretty_print(rows: list[dict[str, str]]) -> None:
    """Красиво выводит список dict'ов в таблицу без сторонних библиотек."""
    if not rows:
        print("Таблица пуста.")
        return
    headers = rows[0].keys()
    widths = {h: max(len(h), *(len(r[h]) for r in rows)) for h in headers}
    sep = " | "
    header_line = sep.join(h.ljust(widths[h]) for h in headers)
    print(header_line)
    print("-" * len(header_line))
    for r in rows:
        print(sep.join(r[h].ljust(widths[h]) for h in headers))


def login() -> tuple[requests.Session, str]:
    """Возвращает залогиненую сессию и актуальный CSRF-token."""
    session = requests.Session()

    login_page = session.get(BASE_URL, timeout=10)
    token = _extract_token(login_page.text)

    payload = {
        "pma_username": USERNAME,
        "pma_password": PASSWORD,
        "server": 1,
        "target": "index.php",
        "token": token,
    }
    resp = session.post(urljoin(BASE_URL, "index.php"), data=payload, timeout=10)
    if USERNAME not in resp.text and "logout.php" not in resp.text:
        raise RuntimeError("Авторизация не удалась: проверьте логин/пароль либо защиту от ботов.")

    new_token = _extract_token(resp.text)
    print("[+] Logged in")
    return session, new_token


def fetch_users(session: requests.Session, token: str) -> list[dict[str, str]]:
    """Делает SELECT * FROM users и возвращает данные как список dict'ов."""
    query = f"SELECT * FROM `{TABLE_NAME}`"
    params = {
        "db": DB_NAME,
        "table": TABLE_NAME,
        "sql_query": query,
        "pos": 0,
        "is_browse_distinct": 0,
        "show_query": 0,
        "token": token,
    }
    resp = session.get(urljoin(BASE_URL, "sql.php"), params=params, timeout=10)
    soup = BeautifulSoup(resp.text, "lxml")

    results_table = soup.find("table", class_="table")
    if results_table is None:
        raise RuntimeError("Не удалось найти таблицу результатов. Проверьте параметры запроса/токен.")

    headers = [th.get_text(strip=True) for th in results_table.thead.find_all("th")]

    rows = []
    for tr in results_table.tbody.find_all("tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        data_cells = cells[1: len(headers) + 1]
        rows.append(dict(zip(headers, data_cells)))

    return rows


def main() -> None:
    session, token = login()
    users = fetch_users(session, token)
    _pretty_print(users)


if __name__ == "__main__":
    main()
