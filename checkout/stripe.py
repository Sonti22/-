import os
import stripe
from functools import lru_cache


@lru_cache
def pub_key(cur):
    return os.getenv(f"STRIPE_PUB_KEY_{cur.upper()}")


@lru_cache
def sec_key(cur):
    return os.getenv(f"STRIPE_SEC_KEY_{cur.upper()}")


def set_api(cur):
    stripe.api_key = sec_key(cur)
