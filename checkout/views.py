import json
import stripe
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render
from django.urls import path

from .models import Item, Order
from .stripe import pub_key, sec_key


def item_detail(request, id):
    item = get_object_or_404(Item, pk=id)
    return render(request, "item.html", {
        "item": item,
        "stripe_pub": pub_key(item.currency),
    })


def buy(request, id):
    item = get_object_or_404(Item, pk=id)
    session = stripe.checkout.Session.create(
        line_items=[{
            "price_data": {
                "currency": item.currency,
                "product_data": {"name": item.name},
                "unit_amount": item.price,
            },
            "quantity": 1,
        }],
        mode="payment",
        success_url=request.build_absolute_uri("/success"),
        cancel_url=request.build_absolute_uri(f"/item/{id}"),
        api_key=sec_key(item.currency),
    )
    return JsonResponse({"id": session.id})


# --- NEW ---
def create_order(request):
    """
    POST /order/create
    body = { "item_ids": [1,2,3], "discount_id": 1, "tax_id": 1 }
    """
    data = json.loads(request.body)
    order = Order.objects.create(
        discount_id=data.get("discount_id"),
        tax_id=data.get("tax_id"),
    )
    order.items.set(data["item_ids"])
    return JsonResponse({"order_id": order.id})


def order_checkout(request, id):
    """GET /order/<id> — создаёт Stripe Session на весь заказ"""
    order = get_object_or_404(Order, pk=id)

    line_items = [{
        "price_data": {
            "currency": order.currency(),
            "product_data": {"name": it.name},
            "unit_amount": it.price,
        },
        "quantity": 1,
    } for it in order.items.all()]

    session_kwargs = dict(
        line_items=line_items,
        mode="payment",
        success_url=request.build_absolute_uri("/success"),
        cancel_url=request.build_absolute_uri(f"/order/{id}"),
        api_key=sec_key(order.currency()),
    )

    if order.discount:
        session_kwargs["discounts"] = [{"coupon": order.discount.stripe_coupon_id}]
    if order.tax:
        session_kwargs["automatic_tax"] = {"enabled": True}
        # либо tax_rates=[order.tax.stripe_tax_id]

    session = stripe.checkout.Session.create(**session_kwargs)
    return JsonResponse({"id": session.id})


urlpatterns = [
    path("item/<int:id>", item_detail),
    path("buy/<int:id>", buy),
    path("order/create", create_order, name="order-create"),
    path("order/<int:id>", order_checkout, name="order-checkout"),
]
