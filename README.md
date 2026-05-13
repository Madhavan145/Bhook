# Bhook

Production-focused campus food commerce platform.

## Monorepo structure

```text
Bhook/
├─ apps/
│  ├─ customer-mobile/   Flutter customer app
│  ├─ vendor-mobile/     Flutter vendor app
│  ├─ delivery-mobile/   Flutter delivery partner app
│  └─ admin-web/         Next.js platform operations console
├─ services/
│  ├─ common/            Shared DTOs, errors, security
│  ├─ identity/          Auth, users, sessions, roles, JWT
│  ├─ customer/          Profiles, memberships, verification
│  ├─ campus/            Campuses, hostels, pickup points
│  ├─ catalog/           Vendors and menu (planned)
│  ├─ order/             Cart, orders, snapshots (planned)
│  ├─ payment/           Attempts, refunds, callbacks (planned)
│  ├─ delivery/          Partners, jobs, handoff (planned)
│  ├─ tracking/          Live location, presence (planned)
│  ├─ social/            Friendships, sharing (planned)
│  ├─ notification/      Push, in-app messages (planned)
│  ├─ operations/        Admin workflows, audit (planned)
│  ├─ financial/         Ledger, payouts, settlement (planned)
│  └─ gateway/           Public API gateway
├─ shared/
│  └─ contracts/         OpenAPI, event schemas
├─ infra/
│  ├─ docker/            Compose, init SQL, dev tooling
│  ├─ k8s/               Kubernetes manifests (planned)
│  └─ scripts/           Ops scripts (planned)
├─ .gitignore
├─ docker-compose.yml
├─ package.json
└─ README.md
```

## Quick start

### 1. Bring up infrastructure

```powershell
Copy-Item .env.example .env
# Set non-empty local values for each required variable in .env.
docker compose up -d
```

Compose requires local values for the JWT, PostgreSQL, MinIO, and payment webhook secrets. Do not commit `.env`; use unique values and a secret manager outside local development.

Starts PostgreSQL (per-service databases auto-created), Redis, Kafka (KRaft mode), and MinIO.

### 2. Build the backend services

```powershell
cd services
mvn -T 1C -DskipTests package
```

### 3. Run the Identity service

When running a service outside Compose, set `SPRING_DATASOURCE_PASSWORD` to the same value as `POSTGRES_PASSWORD` in `.env`, and set `BHOOK_JWT_SECRET` to the local JWT value from `.env`.

```powershell
cd services/identity
mvn spring-boot:run
```

Health check: http://localhost:8081/actuator/health  
Endpoints:
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`

### 4. Customer app

```powershell
cd apps/customer-mobile
flutter pub get
flutter run
```

### 5. Admin console

```powershell
cd apps/admin-web
npm install
npm run dev
```

## Production principles

- Every service owns its own database (`bhook_identity`, `bhook_customer`, `bhook_campus`, ...) and a dedicated schema.
- No cross-service direct DB access. Integration is over versioned REST and Kafka domain events.
- Campus isolation is enforced server-side. Client-supplied campus/vendor IDs are never trusted for authorization.
- JWT access tokens are short-lived; refresh tokens are rotated on use and hashed at rest.
- All mutating operations that require idempotency must accept `Idempotency-Key`.
- Order snapshots are immutable once created; catalog mutation cannot alter historical orders.
- Payment provider integration is behind a provider-neutral adapter.
- All administrative actions must be auditable.

## Account types

The platform supports four account families, each with its own role space:

| Family | Roles | Default at register |
|---|---|---|
| Customer | `CUSTOMER` | `accountType=CUSTOMER` |
| Vendor | `VENDOR_OWNER`, `VENDOR_MANAGER`, `VENDOR_STAFF` | `accountType=VENDOR` |
| Delivery | `DELIVERY_PARTNER`, `DELIVERY_MANAGER` | `accountType=DELIVERY` |
| Platform | `PLATFORM_SUPER_ADMIN`, `PLATFORM_ADMIN`, `PLATFORM_OPERATIONS`, `PLATFORM_SUPPORT`, `PLATFORM_FINANCE`, `PLATFORM_MARKETING` | `accountType=PLATFORM` (support tier) |

Role elevation to higher-privilege tiers is a platform operations action, not a public API.
