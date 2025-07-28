from django.urls import path
from .views import item_detail, buy, create_order, order_checkout

urlpatterns = [
    path("item/<int:id>", item_detail),
    path("buy/<int:id>", buy),
    path("order/create", create_order, name="order-create"),
    path("order/<int:id>", order_checkout, name="order-checkout"),
]
