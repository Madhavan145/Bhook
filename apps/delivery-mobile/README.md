# Bhook Delivery App

Flutter mobile app for delivery partners.

## Run

```powershell
cd apps/delivery-mobile
flutter pub get
flutter run
```

Uses the Identity, Delivery, Tracking, and Campus services. Login requires an account with any `DELIVERY_*` role — created via `POST /api/v1/auth/register` with `accountType=DELIVERY`, then `POST /api/v1/delivery/partners/register`, then platform approval.
