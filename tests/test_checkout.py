import pytest
from checkout.models import Item, Order


@pytest.mark.django_db
def test_order_total_amount():
    i1 = Item.objects.create(name="a", price=100, currency="usd")
    i2 = Item.objects.create(name="b", price=200, currency="usd")
    order = Order.objects.create()
    order.items.set([i1, i2])
    assert order.total_amount() == 300
