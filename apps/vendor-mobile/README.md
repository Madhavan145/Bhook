# Bhook Vendor App

Flutter mobile app for vendor owners, managers, and staff.

## Run

```powershell
cd apps/vendor-mobile
flutter pub get
flutter run
```

Uses the Identity, Catalog, and Order services. Login requires an account with any `VENDOR_*` role — typically created via `POST /api/v1/auth/register` with `accountType=VENDOR`, then `POST /api/v1/vendors/apply` followed by platform approval.
