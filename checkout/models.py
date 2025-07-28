from django.db import models


class Item(models.Model):
    CURRENCIES = (("usd", "USD"), ("eur", "EUR"))
    name = models.CharField(max_length=120)
    description = models.TextField()
    price = models.PositiveIntegerField(help_text="в копейках/центах")
    currency = models.CharField(max_length=3, choices=CURRENCIES, default="usd")

    def __str__(self):
        return self.name

# --- NEW ---


class Discount(models.Model):
    """Stripe-coupon wrapper: сумма/процент лежит в Stripe."""

    stripe_coupon_id = models.CharField(max_length=50)
    name = models.CharField(max_length=50, default="discount")

    def __str__(self):
        return self.name


class Tax(models.Model):
    """Stripe-tax-rate wrapper."""

    stripe_tax_id = models.CharField(max_length=50)
    name = models.CharField(max_length=50, default="tax")

    def __str__(self):
        return self.name


class Order(models.Model):
    items = models.ManyToManyField(Item)
    discount = models.ForeignKey(Discount, null=True, blank=True, on_delete=models.SET_NULL)
    tax = models.ForeignKey(Tax, null=True, blank=True, on_delete=models.SET_NULL)
    created = models.DateTimeField(auto_now_add=True)

    def total_amount(self) -> int:
        return sum(item.price for item in self.items.all())

    def currency(self) -> str:
        """Заказ может содержать товары только в одной валюте (упрощение)."""

        return self.items.first().currency if self.items.exists() else "usd"

    def __str__(self):
        return f"Order #{self.pk} — {self.items.count()} items"
