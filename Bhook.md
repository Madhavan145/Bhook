# Bhook

**Project:** Bhook
**Specification:** SRS v1.0 + System Architecture Specification

Yes — and there is one **important correction** to your Kafka assumption before we freeze the architecture.

## First: Kafka clarification — this is critical

You said:

> "Kafka event stream should be the source for different applications like customer, delivery partner, vendor, super admin."

**Almost right, but I would not make Kafka the source of truth.**

For this system, the correct model is:

```text
                    DOMAIN DATABASES
                    SOURCE OF TRUTH
                          │
                          │
                  Transaction + Outbox
                          │
                          ▼
                       KAFKA
                 EVENT DISTRIBUTION BUS
                          │
          ┌───────────────┼────────────────┐
          │               │                │
          ▼               ▼                ▼
      Customer        Delivery          Vendor
      consumers       consumers         consumers
          │               │                │
          └───────────────┼────────────────┘
                          ▼
                   Platform/Admin
```

**Databases own authoritative state. Kafka distributes business events.**

For example, if an order is `PREPARING`, the authoritative state lives in the Order Service database. Kafka carries `OrderPreparationStarted` so notification, delivery, analytics, customer realtime updates, etc. can react.

Kafka is excellent as an event backbone, and Spring Kafka supports transactional processing/EOS patterns, but even Spring's documentation describes exactly-once semantics around a `read → process → write` sequence; it doesn't mean Kafka automatically replaces your domain database. ([Home][1])

For **customer initial state**, you call the appropriate API/query service.

For **live changes**, WebSocket/SSE or a realtime gateway can consume event streams and push updates.

For **analytics/audit/read models**, Kafka consumers can build their own projections.

That gives us:

> **Database = truth. Kafka = nervous system. Redis = fast ephemeral state.**

That is the architecture I recommend locking in.

I also double-checked the multi-tenant/security direction. PostgreSQL supports row-level security, including default-deny behavior when enabled without applicable policies, which can provide an additional database-level defense—but application/service authorization must remain the primary boundary. ([PostgreSQL][2])

Kubernetes' HorizontalPodAutoscaler can independently adjust replica counts based on metrics, so our services can scale independently later. ([Kubernetes][3])

With those corrections, **the architecture we discussed is stable enough to turn into the SRS.**

Below is the **Pakka SRS v1.0**. I am intentionally making it implementation-oriented so a human developer or another AI agent can pick it up and understand what to build, why, and what must not be violated.

# CAMPUSFOOD

## Multi-Campus Food Delivery & Campus Logistics Platform

### Software Requirements Specification + System Architecture Specification

**Version:** 1.0
**Status:** Architecture Baseline
**Initial Market:** India
**Initial Use Case:** Residential college/university hostels
**Long-Term Market:** Worldwide campus residential ecosystems
**Primary Backend:** Java + Spring Boot
**Event Backbone:** Apache Kafka
**Cache / Ephemeral State:** Redis
**Primary Database:** PostgreSQL
**Containerization:** Docker
**Orchestration:** Kubernetes
**Mobile:** Flutter
**Architecture Style:** Domain-oriented microservices + event-driven architecture
**Deployment Model:** Cloud-native, multi-campus, logically multi-tenant

---

# 1. Executive Summary

CampusFood is a campus-restricted food marketplace and delivery platform designed specifically for students and other verified campus residents who live in hostels/residential facilities.

The platform connects:

1. **Customers**

   * Students
   * Postgraduate students
   * PhD scholars
   * Faculty/staff residing in eligible campus accommodation
   * Other verified campus residents

2. **Food Vendors**

   * Food outlets physically operating inside or immediately within an approved campus environment
   * Manually onboarded and approved by CampusFood
   * Generally campus-specific

3. **Delivery Partners**

   * Delivery personnel hired/approved by CampusFood
   * Authorized to deliver within defined campus boundaries
   * Potentially issued official CampusFood delivery identification

4. **CampusFood Platform**

   * Platform administrators
   * Operations
   * Support
   * Finance
   * Marketing
   * Vendor management
   * Delivery management
   * Customer verification
   * Platform governance

The college/university itself is **not a mandatory software actor**.

A campus exists in the system because it is the physical/geographical operating boundary. The institution does not need an administrative dashboard in the initial product.

The Bhook platform team must be able to perform campus operations from the Platform Operations/Super Admin application, including creating and configuring campuses, importing hostels, creating pickup points, approving vendors, verifying customers, managing delivery partners, monitoring orders, handling support and finance operations, and maintaining audit records.

---

# 2. Product Vision

CampusFood is not merely a restaurant-ordering application.

It is a:

> **Campus-restricted commerce and logistics platform.**

Food delivery is the first vertical.

The architecture must eventually be capable of supporting other campus-local commerce categories without requiring a fundamental rewrite.

Potential future verticals:

* Food
* Grocery
* Convenience
* Stationery
* Laundry
* Pharmacy where legally appropriate
* Other campus-local services

However:

> **V1 product scope is FOOD.**

Future verticals must not complicate V1 unnecessarily.

---

# 3. Core Problem

Traditional food delivery platforms are optimized for city-wide delivery.

For hostel residents, this creates a specific problem:

```text
External Restaurant
       ↓
Campus Gate
       ↓
Student walks 500m–1km
       ↓
Food collected
```

CampusFood changes the logistics model:

```text
On-campus Vendor
       ↓
Authorized CampusFood Delivery Partner
       ↓
Hostel Delivery/Pickup Point
       ↓
Student
```

The platform therefore solves:

* campus access restrictions
* external delivery personnel restrictions
* large hostel walking distances
* fragmented campus food ordering
* lack of centralized ordering
* lack of campus-specific delivery logistics
* vendor digitization
* delivery tracking

---

# 4. Product Principles

The following principles are architectural invariants.

## P1 — Campus isolation

A customer belonging to Campus A must never receive or manipulate resources belonging to Campus B.

Example:

```text
VIT Vellore customer
        ↓
VIT vendors only
```

The UI must not merely hide other vendors.

The backend must enforce the restriction.

---

## P2 — Database is authoritative

Domain databases are the source of authoritative business state.

Kafka is not the primary database.

Redis is not the primary database.

Client devices are never authoritative.

---

## P3 — Kafka is the event backbone

Kafka distributes domain events to:

* customer realtime systems
* vendor systems
* delivery systems
* notification systems
* analytics
* search/read models
* administrative dashboards
* audit pipelines
* future applications

---

## P4 — Server-side authorization

Never trust:

```text
campus_id
vendor_id
role
user_type
```

sent by the mobile application.

These must be derived/validated from authenticated server-side identity and authorization context.

---

## P5 — One active campus context

A user may eventually have multiple valid campus memberships, but only one campus is active in a customer session at a time.

---

## P6 — Idempotency everywhere money or orders are involved

Requests and events may be retried.

Duplicate delivery must not produce duplicate:

* orders
* payments
* refunds
* settlements
* notifications where duplication is harmful
* delivery assignments

---

## P7 — VIT is data, not code

No business logic should contain:

```text
if VIT
if SRM
if IIT
```

Campus-specific behavior must be configuration/data-driven.

---

## P8 — India-first, globally capable

India-specific functionality such as UPI must be implemented first.

However, the core domain must not assume:

* INR
* Indian phone numbers
* Indian addresses
* Indian taxes
* Indian payment methods
* Indian timezone
* Indian language

---

# 5. Actors

## 5.1 Customer

Represents an approved person allowed to use CampusFood within a campus.

Possible membership types:

```text
UNDERGRADUATE
POSTGRADUATE
PHD
FACULTY
STAFF
OTHER
```

Application role:

```text
CUSTOMER
```

Membership type is metadata, not the primary authorization role.

---

# 5.2 Vendor

A food business operating within an approved campus.

Roles:

```text
VENDOR_OWNER
VENDOR_MANAGER
VENDOR_STAFF
```

A vendor is normally associated with one campus in V1.

---

# 5.3 Delivery Partner

A CampusFood-approved/hired delivery worker.

Role:

```text
DELIVERY_PARTNER
```

Potential additional internal role:

```text
DELIVERY_MANAGER
```

---

# 5.4 Platform Personnel

Internal CampusFood users.

Initial roles:

```text
PLATFORM_SUPER_ADMIN
PLATFORM_ADMIN
PLATFORM_OPERATIONS
PLATFORM_SUPPORT
PLATFORM_FINANCE
PLATFORM_MARKETING
```

Roles and permissions must be separate concepts.

---

# 6. Non-Actors

The university/college administration is **not required to be a platform actor**.

A campus may exist without a university administrator account.

The platform can independently:

* onboard the campus
* configure hostels
* configure pickup points
* approve vendors
* verify customers
* employ delivery partners

Future integrations may allow institutional participation, but this is outside V1.

---

# 7. Core Domain Hierarchy

```text
PLATFORM
    │
    ├── Country
    │
    ├── Region
    │
    └── Campus
           │
           ├── Delivery Locations
           │      ├── Hostel
           │      ├── Building
           │      ├── Pickup Point
           │      └── Zone
           │
           ├── Vendors
           │      └── Catalog
           │
           ├── Customers
           │      └── Campus Membership
           │
           └── Delivery Partners
```

"University" or "college" may be stored as informational metadata, but it is not required to own application permissions.

---

# 8. Multi-Tenancy Strategy

## 8.1 Recommended strategy

Use:

> **Logical multi-tenancy / campus isolation from day one.**

Do not initially create one database per campus.

Do not initially implement physical database sharding.

Instead, entities that require isolation contain the appropriate:

```text
campus_id
```

and, where appropriate:

```text
tenant_id
```

The exact distinction between platform tenant and campus will be retained in the model so physical sharding can be introduced later.

---

# 8.2 Why not database-per-campus initially?

Because it creates operational complexity:

* migrations
* backups
* monitoring
* connection management
* reporting
* schema upgrades
* disaster recovery
* tenant movement

before the business actually requires it.

---

# 8.3 Future sharding

The architecture must permit future:

```text
Shard India
Shard Europe
Shard North America
Shard Asia-Pacific
```

without changing business-domain semantics.

Use globally unique identifiers such as UUID/UUIDv7-style identifiers.

Maintain explicit:

```text
campus_id
```

on relevant entities.

---

# 9. Customer Identity Model

Do NOT model the fundamental identity as:

```text
User -> college_id
```

Instead:

```text
User
  │
  └── CampusMembership
           │
           ├── campus_id
           ├── membership_type
           ├── verification_status
           ├── verification_method
           ├── valid_from
           └── valid_until
```

This allows one person to potentially have multiple memberships over time.

---

# 10. Active Campus

A user may have:

```text
CampusMembership A → VIT Vellore
CampusMembership B → another campus
```

but the current application context is:

```text
active_campus_id = VIT_VELLORE
```

Only one active campus is allowed per session/context.

Changing active campus requires:

1. authenticated user
2. valid membership
3. membership status = ACTIVE/VERIFIED
4. campus = supported
5. context-switch authorization

---

# 11. Customer Verification

A customer must be verified before ordering.

The architecture must support multiple verification mechanisms.

Initial possibilities:

```text
INSTITUTION_EMAIL
STUDENT_ID
DOCUMENT_REVIEW
HOSTEL_INFORMATION
MANUAL_PLATFORM_VERIFICATION
```

Future:

```text
SSO
UNIVERSITY_API
OTHER_IDENTITY_PROVIDER
```

Verification must be abstracted behind a verification subsystem.

Do not hardcode email-domain verification into the customer service.

---

# 12. Customer State Machine

```text
REGISTERED
    ↓
VERIFICATION_PENDING
    ↓
VERIFIED
    ↓
ACTIVE
```

Possible terminal/exception states:

```text
REJECTED
SUSPENDED
BLOCKED
DEACTIVATED
EXPIRED
```

Only eligible states may place orders.

---

# 13. Vendor Model

Core concept:

```text
Vendor
```

not:

```text
Restaurant
```

because future verticals may require broader commerce.

For V1:

```text
vendor_type = FOOD
```

A vendor has:

```text
vendor_id
campus_id
legal_name
display_name
description
contact_information
operating_status
approval_status
address/location
business_hours
commission_configuration
payment_configuration
```

---

# 14. Vendor Approval

Vendors are manually approved by CampusFood.

Vendor lifecycle:

```text
PROSPECT
    ↓
APPLICATION
    ↓
UNDER_REVIEW
    ↓
APPROVED
    ↓
ACTIVE
```

Other states:

```text
REJECTED
SUSPENDED
CLOSED
DEACTIVATED
```

A vendor must never become orderable merely because its database record exists.

Conditions for customer visibility:

```text
vendor.approval_status = APPROVED
vendor.operating_status = OPEN/ACTIVE
campus.status = ACTIVE
```

---

# 15. Vendor Campus Restriction

A vendor has a primary campus association.

Normal V1 invariant:

```text
Vendor.campus_id = one campus
```

If a future chain operates across campuses, the model may evolve into:

```text
VendorBrand
     │
     ├── VendorLocation → Campus A
     ├── VendorLocation → Campus B
     └── VendorLocation → Campus C
```

This is intentionally not required for V1.

---

# 16. Catalog

The catalog hierarchy:

```text
Vendor
  ↓
Menu
  ↓
Category
  ↓
Item
  ↓
Variant / Option
  ↓
Modifier / Add-on
```

Example:

```text
Burger
 ├── Regular
 └── Large

Add-ons:
 ├── Cheese
 ├── Extra Patty
 └── Sauce
```

Catalog must support:

* item availability
* item price
* tax configuration
* images
* descriptions
* variants
* modifiers
* dietary metadata
* preparation time
* inventory/availability
* scheduled availability

Vendors with the appropriate vendor-scoped permissions may manage their own catalog from the Vendor application. This includes creating, reading, updating, reordering, pricing, making available/unavailable, archiving, and deleting menus, categories, food items, variants, modifiers, add-ons, images, dietary metadata, preparation times, and scheduled availability.

Catalog mutations must be audited and protected by optimistic concurrency/versioning. A vendor must never modify another vendor's catalog. If an item has been used in an order, archive/soft-delete is preferred over hard deletion. Historical orders and financial records must retain immutable item, variant, modifier, price, tax, discount, and fee snapshots; catalog changes must never rewrite past orders.

---

# 17. Customer Vendor Discovery

Customer request:

```text
GET /vendors
```

must derive campus from authenticated context.

The request must NOT trust:

```text
GET /vendors?campusId=SRM
```

as an authorization mechanism.

The server determines:

```text
authenticated_customer
        ↓
active membership
        ↓
active campus
        ↓
vendors belonging to campus
```

This is the primary isolation rule.

---

# 18. Defense-in-Depth Tenant Isolation

Application-level authorization is mandatory.

Database-level protections may also be applied where appropriate.

PostgreSQL supports row-level security policies that can restrict rows by policy expressions and can default to deny access when no applicable policy allows access. ([PostgreSQL][2])

Recommended model:

```text
Layer 1:
JWT / identity

Layer 2:
RBAC

Layer 3:
Resource authorization

Layer 4:
Campus scope validation

Layer 5:
Database constraints / optional RLS
```

RLS must not become an excuse to omit service-layer authorization.

---

# 19. Authorization Model

Use:

> **RBAC + resource scope**

rather than role-only authorization.

Example:

```text
Role:
VENDOR_MANAGER

Scope:
vendor_id = VIT_VENDOR_123
campus_id = VIT_VELLORE
```

That manager cannot access:

```text
SRM_VENDOR_123
```

or another unrelated VIT vendor.

---

# 20. Permissions

Permissions should be granular.

Examples:

```text
CUSTOMER:
    vendor.read
    catalog.read
    cart.write
    order.create
    order.read.own
    delivery.track.own

VENDOR_STAFF:
    order.read.vendor
    order.accept
    order.reject
    order.update_status

VENDOR_MANAGER:
    menu.read
    menu.write
    order.read.vendor
    analytics.read.vendor

DELIVERY_PARTNER:
    delivery.read.assigned
    delivery.accept
    delivery.location.write
    delivery.status.update

PLATFORM_OPERATIONS:
    customer.verify
    vendor.approve
    delivery.assign
    order.support
```

---

# 21. Order Domain

Order is one of the central domains.

Order must contain immutable historical information sufficient to reconstruct what happened.

Do not rely on the current vendor menu to reconstruct historical orders.

When an order is placed, store a snapshot of:

* item name
* variant
* modifier
* quantity
* unit price
* tax
* discounts
* subtotal
* fees

---

# 22. Order State Machine

Recommended:

```text
CART
  ↓
ORDER_CREATED
  ↓
PAYMENT_PENDING
  ↓
PAID
  ↓
VENDOR_ACCEPTED
  ↓
PREPARING
  ↓
READY_FOR_PICKUP
  ↓
DELIVERY_ASSIGNED
  ↓
PICKED_UP
  ↓
OUT_FOR_DELIVERY
  ↓
ARRIVED_AT_PICKUP_POINT
  ↓
READY_FOR_COLLECTION
  ↓
COLLECTED
  ↓
COMPLETED
```

Exception states:

```text
PAYMENT_FAILED
VENDOR_REJECTED
CANCELLED
REFUND_PENDING
REFUNDED
DELIVERY_FAILED
CUSTOMER_NO_SHOW
```

Transitions must be server-controlled.

---

# 23. Order Invariants

Examples:

A vendor cannot mark another vendor's order as ready.

A customer cannot change an order after a defined irreversible state.

A delivery partner cannot pick up an order that is not assigned to them.

A delivery partner cannot mark an order delivered if it has not been picked up.

A customer cannot access an order belonging to another customer.

---

# 24. Cart

Cart belongs to a customer and active campus context.

Recommended V1 rule:

> One cart = one vendor.

This avoids complicated multi-vendor order splitting.

Future versions may support multi-vendor carts, but they should not be part of the first financial/order implementation.

## 24A. Social Friendship and Order Sharing

Bhook may provide a lightweight platform-only friendship feature without becoming a chat application or general social network.

Recommended relationship flow:

```text
Customer A sends friend request
  ↓
Customer B accepts
  ↓
Customer A <-> Customer B = FRIENDS
```

Friendships should default to users in the same active campus context. The model must support `PENDING`, `ACCEPTED`, `DECLINED`, `BLOCKED`, and `REMOVED` states, together with remove, block, report, and privacy controls. Friendship must not expose phone numbers, email addresses, institution identifiers, private account data, orders, payment information, or delivery information by itself.

The customer order-sharing toggle is separate from friendship and is **OFF by default**. A customer may enable `share_with_friends` for an individual order. Only accepted Bhook friends may view the shared order, and the owner may revoke sharing later.

The friend-facing card should contain only a limited summary, such as:

```text
friend display name
vendor display name
campus-safe item summary or item names
order status where product policy allows
shared timestamp
```

It must not expose payment method or payment details, total price by default, delivery address, hostel room information, pickup OTP/QR, live delivery location, phone number, private notes, or support/fraud information. Friends have read-only visibility and never gain order mutation rights.

Suggested social events are:

```text
FriendRequestSent
FriendRequestAccepted
FriendshipRemoved
UserBlocked
OrderSharingEnabled
OrderSharingRevoked
```

These events must not contain sensitive payment, address, OTP, or location data. This capability may initially be implemented near Customer Service, with its own authorization, privacy, moderation/audit rules, and friend-feed projection.

## 24B. Future Group Ordering and Shared Delivery

In a later phase, an accepted friend in the same or a nearby hostel/building block may join an explicitly shared active order. This targets dense campus hostels, where multiple friends can order from the same vendor and receive their food at the same or nearby pickup point.

The feature must use independent participant orders rather than a shared wallet or shared cart:

```text
OrderGroup / SharedDeliveryBatch
    ├── Customer A independent order
    ├── Customer B independent order
    └── Customer C independent order
```

Recommended flow:

```text
Customer A selects vendor and items
  ↓
A enables sharing and an order join window opens
  ↓
Friend B views the eligible shared order
  ↓
B selects personal items and pays independently
  ↓
Join window closes
  ↓
Vendor prepares one compatible batch
  ↓
Bhook dispatches a shared delivery where possible
  ↓
Each customer completes their own OTP/QR handoff
```

Each participant retains independent ownership, items, payment, cancellation, refund, and handoff status. The host cannot see a friend's payment details or private address. A participant cannot modify another participant's order.

Bhook may combine orders for preparation and delivery only when compatibility rules pass, including same vendor, same campus, same or nearby pickup point, compatible promised time, vendor capacity, partner capacity, and operational safety. If compatibility fails, the orders fall back to separate delivery. A late join, failed payment, cancellation, or missed handoff by one participant must not corrupt another participant's order.

This capability requires an `OrderGroup` or `SharedDeliveryBatch` model with a host, vendor, campus, pickup point/delivery zone, join deadline, capacity limits, participant membership, and group status. It is a post-MVP capability and must not change the V1 one-customer/one-vendor cart rule.

---

# 25. Payment Architecture

Payment must be a dedicated domain.

Initial India requirement:

```text
UPI
```

Also support:

```text
CARD
WALLET
OTHER
```

through a provider abstraction.

The core order system must not directly depend on one payment provider.

---

# 26. Payment Lifecycle

```text
PAYMENT_INITIATED
        ↓
PAYMENT_PENDING
        ↓
PAYMENT_SUCCESS
```

or:

```text
PAYMENT_FAILED
PAYMENT_EXPIRED
PAYMENT_CANCELLED
```

Refund:

```text
REFUND_REQUESTED
    ↓
REFUND_PROCESSING
    ↓
REFUNDED
```

---

# 27. Payment Idempotency

Every payment initiation must include an idempotency key.

Example:

```text
payment_attempt_id
idempotency_key
```

Retrying the same payment request must not create a second financial charge.

Payment callbacks must also be idempotent.

---

# 28. Financial Ledger

Never rely solely on:

```text
order.total_amount
```

for accounting.

Create a financial transaction/ledger model.

Example:

```text
Customer payment
        │
        ├── food subtotal
        ├── tax
        ├── platform fee
        ├── delivery fee
        ├── discount
        └── adjustment
```

Settlement:

```text
Customer
   ↓
Platform
   ├── Vendor payable
   ├── Delivery payable
   ├── Payment processing cost
   └── Platform revenue
```

The ledger must support:

* debit
* credit
* refund
* adjustment
* settlement
* reconciliation

---

# 29. Revenue Model

Initial revenue:

```text
Vendor Commission
+
Platform Fee
+
Advertising
```

Potential future revenue:

```text
Subscription
Premium delivery
Vendor SaaS
Sponsored listings
Campus-wide campaigns
```

---

# 30. Vendor Commission

Commission must be configurable.

Potential scopes:

```text
GLOBAL
CAMPUS
VENDOR
ORDER
PROMOTION
```

Example:

```text
Vendor A:
commission = 10%

Vendor B:
commission = 12%
```

Do not hardcode commission percentages.

---

# 31. Advertising

Advertising is a separate domain.

Campaign model:

```text
Campaign
    ├── vendor_id
    ├── campus_id
    ├── budget
    ├── billing_model
    ├── targeting
    ├── start_at
    ├── end_at
    └── status
```

A campaign must respect campus isolation.

A VIT campaign cannot automatically appear to SRM users.

---

# 32. Delivery Model

Delivery is a first-class domain.

Core entities:

```text
DeliveryPartner
DeliveryAssignment
DeliveryTask
DeliveryLocation
DeliveryZone
DeliveryRoute
```

---

# 33. Delivery Partner Lifecycle

```text
APPLIED
   ↓
VERIFICATION_PENDING
   ↓
VERIFIED
   ↓
APPROVED
   ↓
ACTIVE
```

Other states:

```text
SUSPENDED
OFFLINE
DEACTIVATED
BLOCKED
```

---

# 34. Delivery Partner Campus Assignment

A delivery partner must have explicit campus authorization.

```text
DeliveryPartner
      ↓
CampusAssignment
      ↓
Campus
```

This prevents a partner authorized for one campus from automatically receiving jobs in another.

---

# 35. Delivery Point Model

Do not hardcode hostel logic.

Use:

```text
DeliveryLocation
```

Types:

```text
HOSTEL
BUILDING
PICKUP_POINT
GATE
ZONE
OTHER
```

Example:

```text
VIT Vellore
    ↓
Hostel Block 18
    ↓
Pickup Point A
    ↓
GPS coordinates
```

---

# 36. Hostel Data

Initial hostel data may be populated through:

* manual entry
* CSV
* approved data extraction
* operational tools

Scraping may be an ingestion mechanism.

It must never be a runtime dependency.

The platform must remain functional if a college website changes its HTML structure.

For the first draft and pilot, named hostel blocks, buildings, and pickup points are sufficient. Detailed map rendering, routing, polygon geofences, and live map navigation are future enhancements. The initial delivery workflow may use configured pickup-point names, instructions, and manually maintained location data.

---

# 37. Delivery Architecture

Recommended V1 flow:

```text
Vendor
  ↓
Order READY
  ↓
Dispatch Service
  ↓
Delivery Partner assigned
  ↓
Partner accepts
  ↓
Partner navigates to vendor
  ↓
Food picked up
  ↓
Partner navigates to hostel pickup point
  ↓
ARRIVED
  ↓
Student notified
  ↓
Student collects
  ↓
OTP/QR confirmation
  ↓
COMPLETED
```

---

# 38. Batch Delivery

The dispatch engine should eventually optimize by:

* campus
* vendor
* hostel
* pickup point
* distance
* partner capacity
* current workload
* order age
* promised delivery time

Example:

```text
Hostel 18

Orders:
O1
O2
O3
...
O15

Delivery Partner:
DP12

Capacity:
20
```

The system can batch them.

This is a key advantage over generic city delivery.

Future group-order dispatch may match compatible orders by same vendor, campus, hostel/building block, pickup point, promised time, partner capacity, and current workload. The goal is to reduce repeated preparation and partner travel while preserving independent order ownership, payment, authorization, cancellation, refund, and handoff confirmation for every customer.

---

# 39. Real-Time Tracking

Delivery partner application periodically sends location updates.

Architecture:

```text
Delivery Flutter App
        ↓
Tracking API
        ↓
Redis
        ↓
Realtime Gateway
        ↓
Customer Flutter App
```

Kafka may additionally receive selected location events for:

* analytics
* historical tracking
* ETA systems
* anomaly detection

Do not write every GPS coordinate directly to PostgreSQL.

---

# 40. Redis Responsibilities

Redis should be used for ephemeral/high-speed state.

Potential uses:

```text
Active delivery location
Online delivery partners
Delivery partner availability
Short-lived OTPs
Rate limiting
Distributed locks where necessary
Temporary session/state
Hot catalog/cache data
Realtime presence
```

Redis is not the authoritative order database.

---

# 41. Location Update Strategy

Do not necessarily send GPS every second.

Use adaptive update intervals.

Example:

```text
Stationary:
low frequency

Moving:
higher frequency

Active delivery:
higher frequency

Near pickup:
highest relevant frequency
```

The exact algorithm should be configurable.

---

# 42. Notifications

Use a dedicated Notification Service.

Sources:

```text
Kafka events
```

Examples:

```text
OrderCreated
PaymentSucceeded
VendorAcceptedOrder
FoodReady
DeliveryAssigned
DeliveryPickedUp
DeliveryArriving
OrderReadyForCollection
OrderCompleted
RefundCompleted
```

Notification Service decides:

```text
push
email
SMS
in-app
```

based on event + user preferences.

---

# 43. Kafka Architecture

Kafka is the event backbone.

It is not the primary query database.

Conceptual flow:

```text
Order Service
    ↓
Order DB transaction
    ↓
Transactional Outbox
    ↓
Kafka
    ↓
Consumers
```

The outbox prevents the classic failure:

```text
DB commit succeeds
Kafka publish fails
```

or:

```text
Kafka publish succeeds
DB commit fails
```

---

# 44. Event Design

Events should represent meaningful business facts.

Good:

```text
OrderCreated
PaymentCompleted
VendorAcceptedOrder
FoodPreparationStarted
FoodReady
DeliveryAssigned
DeliveryAccepted
FoodPickedUp
DeliveryArrived
OrderCollected
OrderCompleted
```

Bad:

```text
DatabaseRowUpdated
UserTableChanged
SomeBooleanChanged
```

Events should represent domain meaning.

---

# 45. Kafka Event Envelope

All events should use a consistent envelope.

Conceptually:

```json
{
  "eventId": "uuid",
  "eventType": "OrderCreated",
  "eventVersion": 1,
  "occurredAt": "timestamp",
  "producer": "order-service",
  "correlationId": "uuid",
  "causationId": "uuid",
  "campusId": "uuid",
  "aggregateType": "ORDER",
  "aggregateId": "uuid",
  "payload": {}
}
```

Required metadata:

```text
eventId
eventType
eventVersion
occurredAt
producer
correlationId
aggregateType
aggregateId
campusId where applicable
```

---

# 46. Kafka Topic Strategy

Avoid one giant topic.

Possible initial topics:

```text
customer-events
vendor-events
order-events
payment-events
delivery-events
notification-events
campus-events
promotion-events
```

As scale increases, partitioning strategy should be revisited.

For order-related ordering guarantees, partitioning should generally preserve ordering for the relevant aggregate.

Example:

```text
partition key = orderId
```

for order lifecycle events.

---

# 47. Consumer Groups

Each independently processing application/domain should have its own consumer group.

Example:

```text
notification-service
analytics-service
delivery-service
realtime-gateway
search-projection-service
audit-service
```

All can consume the same logical events independently.

---

# 48. Customer App and Kafka

The customer Flutter application should **not directly connect to Kafka**.

Correct:

```text
Kafka
   ↓
Realtime Gateway
   ↓
WebSocket/SSE
   ↓
Flutter
```

Initial page state:

```text
REST/API
```

Live changes:

```text
WebSocket/SSE
```

This is the correct architecture.

---

# 49. Vendor App and Kafka

Same principle.

Vendor Flutter application does not directly consume Kafka.

Instead:

```text
Kafka
 ↓
Vendor-facing realtime/API infrastructure
 ↓
Vendor App
```

Vendor's authoritative operations go through Vendor/Order APIs.

---

# 50. Delivery App and Kafka

Delivery application should not directly consume Kafka.

Use:

```text
Delivery APIs
Realtime Gateway
Push notifications
```

Kafka remains internal infrastructure.

---

# 51. Platform Admin

Admin dashboards can consume:

```text
APIs
+
Realtime Gateway
+
Read models
```

Kafka can feed dedicated operational/analytics projections.

Again:

> **Kafka is behind the platform, not exposed directly to mobile clients.**

---

# 52. Eventual Consistency

Because Kafka is asynchronous, some read models may be eventually consistent.

Example:

```text
Order Service:
PAID

Notification projection:
still PAYMENT_PENDING for 100ms
```

This is acceptable.

Authoritative transactional operations must use the owning domain service/database.

---

# 53. Exactly-Once vs Idempotency

Do not design the entire system around the assumption that "Kafka exactly once" eliminates duplicate processing.

Consumers must still be idempotent.

For important workflows:

```text
eventId
consumer
processing record
```

can be used to prevent duplicate effects.

Spring Kafka provides transactional/EOS mechanisms, but application-level idempotency remains important for robust distributed workflows. ([Home][1])

---

# 54. Recommended Microservices

Initial service boundaries:

```text
1. Identity Service
2. Customer Service
3. Campus Service
4. Vendor Service
5. Catalog Service
6. Order Service
7. Payment Service
8. Delivery Service
9. Dispatch Service
10. Tracking Service
11. Notification Service
12. Promotion Service
13. Financial/Settlement Service
14. Support Service
15. Platform Operations Service
16. Analytics Service
```

Every listed service is an independently deployable architectural boundary from day one. During the first few-campus pilot, services may run on one host or a small cluster to control infrastructure cost, but they must retain separate processes, APIs, migration ownership, deployment units, and service-owned data. They must not directly update one another's tables.

---

# 55. Identity Service

Responsibilities:

* authentication
* access tokens
* refresh tokens
* password/OTP mechanisms where applicable
* identity lifecycle
* session management
* role claims
* security events

It does not own:

* orders
* vendors
* payments

---

# 56. Customer Service

Responsibilities:

* customer profile
* campus memberships
* verification
* customer status
* preferences
* active campus context

---

# 57. Campus Service

Responsibilities:

* campus
* geographical information
* hostel/building metadata
* pickup points
* zones
* operating configuration
* delivery boundaries

It does not need a college-admin UI.

It is platform-operated.

---

# 58. Vendor Service

Responsibilities:

* vendor onboarding
* approval
* vendor profile
* operating hours
* vendor staff
* vendor status

---

# 59. Catalog Service

Responsibilities:

* menus
* categories
* items
* variants
* modifiers
* pricing
* availability
* images

---

# 60. Order Service

Responsibilities:

* cart/order lifecycle
* order validation
* order state machine
* order snapshots
* order history

It is the authoritative owner of order state.

---

# 61. Payment Service

Responsibilities:

* payment initiation
* provider integration
* callbacks
* payment state
* refunds
* idempotency

---

# 62. Delivery Service

Responsibilities:

* delivery partner profiles
* campus assignments
* delivery lifecycle
* delivery tasks
* delivery status

---

# 63. Dispatch Service

Responsibilities:

* assignment
* batching
* partner selection
* capacity
* distance
* delivery prioritization

Dispatch should be independently evolvable because this is one of the platform's major competitive components.

---

# 64. Tracking Service

Responsibilities:

* active location
* location ingestion
* presence
* realtime delivery state
* ETA-related data

Redis is central here.

---

# 65. Notification Service

Responsibilities:

* push
* email
* SMS
* in-app notifications
* templates
* preferences
* notification history

---

# 66. Promotion Service

Responsibilities:

* coupons
* campaigns
* discounts
* sponsored listings
* advertising

---

# 67. Financial Service

Responsibilities:

* ledger
* vendor payable
* delivery partner payable
* platform revenue
* commissions
* reconciliation
* settlements

---

# 68. Platform Operations Service

This is the primary administrative control plane.

It handles:

```text
Campus onboarding
Vendor approval
Customer verification
Delivery partner approval
Support operations
Order intervention
Fraud actions
Configuration
```

---

# 69. Support Service

Support tickets:

```text
CUSTOMER
VENDOR
DELIVERY_PARTNER
PAYMENT
ORDER
REFUND
```

Every support intervention must be auditable.

---

# 70. Analytics Service

Consumes Kafka events and creates analytical projections.

Potential metrics:

```text
Orders/day
GMV
Revenue
AOV
Vendor performance
Delivery time
Cancellation rate
Refund rate
Customer retention
Campus performance
Partner utilization
Peak ordering periods
```

Analytics must not put reporting load on transactional databases.

---

# 71. Database Strategy

Each service logically owns its data.

Preferred architecture:

```text
Identity DB
Customer DB
Campus DB
Vendor DB
Catalog DB
Order DB
Payment DB
Delivery DB
Financial DB
...
```

They may initially run on the same PostgreSQL cluster.

The important rule:

> **Service ownership is logical before it becomes physically separate.**

A service must not directly update another service's tables.

---

# 72. Database Design Principles

Use:

```text
UUID/UUIDv7-style identifiers
created_at
updated_at
version where required
status
```

Use foreign keys inside service-owned data where appropriate.

Do not create cross-service database foreign keys.

Cross-service references are IDs.

---

# 73. Optimistic Concurrency

Use optimistic locking/versioning for resources where concurrent updates matter.

Examples:

```text
Vendor menu
Order state
Delivery assignment
Payment state
```

Example:

```text
version = 7
```

Update only if:

```text
version = 7
```

then increment.

---

# 74. Transaction Boundaries

A single database transaction should own a single service's atomic business operation.

Avoid:

```text
Order DB transaction
+
Payment DB transaction
+
Vendor DB transaction
```

as one distributed transaction.

Use:

```text
local transaction
+
event
+
saga/process manager
```

where necessary.

---

# 75. Order Saga Example

```text
Create Order
    ↓
Payment
    ↓
Payment Successful
    ↓
Vendor accepts
    ↓
Food prepared
    ↓
Delivery assigned
    ↓
Delivery completed
```

Failure examples:

```text
Vendor rejects
      ↓
Refund

Payment succeeds but vendor rejects
      ↓
Refund

Delivery impossible
      ↓
Support/cancellation/refund workflow
```

---

# 76. Outbox Pattern

Every event-producing service should use:

```text
Business DB
+
Outbox table
```

Transaction:

```text
BEGIN

update order

insert OrderCreated into outbox

COMMIT
```

Separate publisher:

```text
Outbox
 ↓
Kafka
```

This ensures database state and intended event publication remain coordinated.

---

# 77. Dead Letter Topics

Kafka consumers must have failure handling.

Example:

```text
order-events
    ↓
consumer
    ↓
retry
    ↓
retry
    ↓
dead-letter topic
```

Do not silently discard failed events.

---

# 78. Event Replay

Important consumers should be replayable.

Example:

```text
analytics-service
```

can rebuild its read model from historical Kafka events where retention policy permits.

This is one reason meaningful domain events matter.

---

# 79. Search

Initially PostgreSQL search may be sufficient.

Later:

```text
OpenSearch/Elasticsearch
```

can be introduced.

Search indexes must be treated as projections, not authoritative data.

---

# 80. Realtime Architecture

```text
Domain Service
     ↓
Kafka
     ↓
Realtime Gateway
     ↓
WebSocket
     ↓
Flutter
```

The realtime gateway should filter events according to authorization.

A VIT customer must never receive an SRM event merely because they happen to be connected.

---

# 81. Realtime Security

The gateway must know:

```text
user_id
role
active_campus_id
authorized_resources
```

before forwarding events.

Never trust a client-provided subscription like:

```text
subscribe(orderId=somebodyElseOrder)
```

without authorization.

---

# 82. Push Notifications

Push notifications can be generated from events.

Example:

```text
FoodReady
 ↓
Notification Service
 ↓
FCM/APNs
 ↓
Customer
```

The app should still query authoritative order state after opening the notification.

---

# 83. Flutter Architecture

One Flutter ecosystem with role-specific experiences.

Potential application surfaces:

```text
Customer App
Vendor App
Delivery Partner App
```

The Platform Admin interface may be better as a web application rather than Flutter, although Flutter Web remains technically possible.

Recommended architecture:

```text
Presentation
    ↓
State Management
    ↓
Domain
    ↓
Repository
    ↓
API / Realtime
```

Avoid putting business rules directly inside widgets.

---

# 84. Customer App

Core screens:

```text
Splash
Authentication
Verification
Campus Selection
Home
Vendor Listing
Vendor Details
Menu
Cart
Checkout
Payment
Order Tracking
Order History
Notifications
Friends
Friend Requests
Shared Orders
Privacy Settings
Profile
Support
```

Checkout includes an order-level `share_with_friends` toggle that is OFF by default. Future group-order screens may show an eligible open order, join deadline, vendor, pickup point, and participant-safe status without revealing private payment or delivery information.

---

# 85. Vendor App

Core screens:

```text
Login
Dashboard
Incoming Orders
Order Details
Accept/Reject
Preparation
Ready
Menu
Availability
Operating Hours
Earnings
Analytics
Profile
Support
```

---

# 86. Delivery App

Core screens:

```text
Login
Verification
Availability
Job Requests
Active Delivery
Navigation
Pickup
Hostel Delivery
Order Handoff
Earnings
History
Profile
Support
```

---

# 87. Platform Admin

Recommended web application:

```text
Dashboard
Campuses
Hostels
Pickup Points
Customers
Verification Queue
Vendors
Vendor Approval
Delivery Partners
Delivery Monitoring
Orders
Payments
Refunds
Settlements
Advertising
Support
Analytics
Audit Logs
System Configuration
```

The Platform Operations/Super Admin application is the Bhook team's control plane. It must support campus creation and configuration, geography and delivery boundaries, hostel/building/pickup-point setup, vendor onboarding and approval, catalog/operational oversight, customer verification, delivery-partner approval and assignment, order intervention, payments, refunds, settlements, advertising, support, analytics, system configuration, and immutable audit review.

---

# 88. API Gateway

External clients should communicate through an API gateway/BFF layer.

Responsibilities:

* authentication
* routing
* rate limiting
* request correlation
* API versioning
* security headers
* request validation
* aggregation where appropriate

Do not put business logic in the gateway.

---

# 89. API Versioning

Use explicit versioning:

```text
/api/v1/...
```

Breaking changes require:

```text
/api/v2/...
```

Events also require event versioning.

---

# 90. API Idempotency

Important commands should support:

```text
Idempotency-Key
```

especially:

```text
Create order
Initiate payment
Create refund
Accept delivery
Complete delivery
```

---

# 91. Authentication

Recommended:

```text
OAuth2/OIDC-style identity architecture
JWT access token
refresh token
short-lived access tokens
```

Never store long-lived access tokens insecurely in Flutter.

Use secure platform storage.

---

# 92. Sensitive Data

Never put sensitive information into:

* Kafka event payloads unnecessarily
* logs
* analytics events
* URLs
* client-visible error messages

PII should be minimized.

---

# 93. Audit Logging

Important administrative actions require immutable audit records.

Examples:

```text
Vendor approved
Customer verified
Customer suspended
Refund issued
Order manually cancelled
Settlement adjusted
Delivery partner blocked
Promotion created
```

Audit entry:

```text
actor
action
resource
resource_id
timestamp
reason
before/after where appropriate
correlation_id
```

---

# 94. Observability

Every service should expose:

```text
metrics
logs
traces
health
readiness
liveness
```

Recommended ecosystem:

```text
OpenTelemetry
Prometheus
Grafana
centralized logs
distributed tracing
```

Every request should carry:

```text
trace_id
correlation_id
```

---

# 95. Error Handling

Standard error envelope:

```json
{
  "code": "ORDER_NOT_MODIFIABLE",
  "message": "The order can no longer be modified.",
  "correlationId": "uuid",
  "details": {}
}
```

Never expose stack traces to clients.

---

# 96. Resilience

Services must handle:

* timeouts
* retries
* circuit breaking
* connection failures
* Kafka failures
* duplicate events
* provider outages
* Redis failures
* partial service degradation

Retries must use exponential backoff and must not blindly retry non-idempotent operations.

---

# 97. Caching

Potential cache targets:

```text
Vendor listing
Vendor details
Catalog
Menu availability
Campus configuration
Pickup points
```

Never cache authoritative payment/order state in a way that allows stale data to cause financial corruption.

---

# 98. Redis Failure

The system must define behavior if Redis becomes unavailable.

For example:

```text
Tracking degraded
```

rather than:

```text
All orders destroyed
```

Transactional data must remain in PostgreSQL/service databases.

---

# 99. Kafka Failure

If Kafka is temporarily unavailable:

* transactional operations should not silently claim events were published
* outbox records remain pending
* publisher retries
* user-facing synchronous operations should degrade gracefully where possible

---

# 100. PostgreSQL Failure

Use:

```text
automated backups
point-in-time recovery
replication
monitoring
```

The exact topology depends on deployment scale.

---

# 101. Kubernetes

All services should be containerized.

Conceptual deployment:

```text
Kubernetes Cluster
│
├── API Gateway
├── Identity
├── Customer
├── Campus
├── Vendor
├── Catalog
├── Order
├── Payment
├── Delivery
├── Dispatch
├── Tracking
├── Notification
├── Promotion
├── Financial
├── Support
└── Analytics
```

Infrastructure such as Kafka, PostgreSQL, and Redis may initially be managed services rather than self-hosted in Kubernetes.

---

# 102. Scaling

Each service must be independently scalable.

Example:

Dinner peak:

```text
Order Service:
10 replicas

Catalog:
4 replicas

Notification:
8 replicas

Tracking:
20 replicas
```

The exact numbers are dynamic.

Kubernetes supports horizontal autoscaling through HorizontalPodAutoscaler. ([Kubernetes][3])

---

# 103. Environments

Minimum:

```text
LOCAL
DEV
STAGING
PRODUCTION
```

Never develop directly against production.

---

# 104. CI/CD

Pipeline:

```text
Git push
 ↓
Build
 ↓
Unit tests
 ↓
Static analysis
 ↓
Security scanning
 ↓
Integration tests
 ↓
Docker image
 ↓
Registry
 ↓
Deploy staging
 ↓
Smoke tests
 ↓
Production approval
 ↓
Production deployment
```

---

# 105. Deployment Strategy

Use:

```text
rolling deployment
```

initially.

Eventually:

```text
blue/green
canary
feature flags
```

for critical services.

---

# 106. Secrets

Never store:

```text
DB password
JWT secret
payment credentials
FCM credentials
Kafka credentials
```

inside source control.

Use:

```text
Kubernetes Secrets
+
cloud secret manager
```

where appropriate.

---

# 107. Configuration

Configuration must be externalized.

Examples:

```text
payment provider
commission rates
order timeout
delivery radius
GPS update interval
notification preferences
campus operating hours
```

No hardcoded VIT-specific values.

---

# 108. Campus Configuration

Each campus should be configurable.

Example:

```text
Campus:
VIT Vellore

Timezone:
Asia/Kolkata

Currency:
INR

Delivery:
Enabled

Hostel Pickup:
Enabled

Delivery Partner Access:
Enabled

Customer Verification:
EMAIL + MANUAL
```

Another campus may differ.

---

# 109. Campus Operating Model

Campus is a platform-managed entity.

Fields:

```text
campus_id
name
display_name
country
region
timezone
currency
latitude
longitude
boundary
status
verification_configuration
delivery_configuration
```

---

# 110. Geographic Boundary

Campus should eventually support:

```text
polygon/geofence
```

This allows the system to determine whether:

* a delivery partner is inside the campus
* a delivery location is valid
* a customer location is plausible

GPS should not be treated as perfectly trustworthy; it is one signal.

Map engine integration is not required for the first version. A future version may add a map provider, route calculation, polygon geofencing, ETA visualization, and stronger location validation without changing the campus/location domain model.

---

# 111. Delivery Pickup Point

Pickup point:

```text
id
campus_id
delivery_location_id
name
coordinates
instructions
operating_hours
status
```

Example:

```text
Hostel 18 Main Pickup Point
```

---

# 112. Delivery Completion

Recommended verification:

```text
OTP
```

or:

```text
QR
```

Potential flow:

```text
Partner arrives
 ↓
Customer receives notification
 ↓
Customer shows OTP
 ↓
Partner verifies
 ↓
Order COMPLETED
```

This reduces false delivery claims.

---

# 113. Order Tracking UI

Customer should see:

```text
Order confirmed
      ✓
Food being prepared
      ✓
Food ready
      ✓
Delivery partner assigned
      ✓
Picked up
      ✓
On the way
      ●
Arrived at Hostel 18
```

Map:

```text
Vendor
  ↓
Delivery partner
  ↓
Hostel pickup point
```

---

# 114. ETA

Initial ETA can be rule-based.

Inputs:

```text
food preparation time
vendor readiness
distance
delivery partner location
queue
campus traffic
historical delivery time
```

Future ML may improve prediction.

Do not make ML a V1 dependency.

---

# 115. Delivery Dispatch

Initial algorithm:

```text
Eligible partners
        ↓
Filter by campus
        ↓
Filter availability
        ↓
Filter capacity
        ↓
Calculate distance
        ↓
Calculate workload
        ↓
Calculate ETA
        ↓
Rank
        ↓
Assign
```

Later optimization can introduce batching and route optimization.

---

# 116. Vendor Preparation

Vendor receives:

```text
NEW_ORDER
```

Vendor accepts:

```text
ACCEPTED
```

Then:

```text
PREPARING
```

Then:

```text
READY
```

Delivery assignment should account for vendor readiness and preparation estimates.

---

# 117. Cancellation Rules

Cancellation policy must depend on order state.

Example:

```text
Before vendor acceptance:
customer cancellation allowed

After preparation:
limited/no cancellation

After pickup:
customer cancellation normally not allowed
```

Exact policy must be configurable.

---

# 118. Refund Rules

Refund can be:

```text
FULL
PARTIAL
NONE
```

depending on:

* payment state
* order state
* vendor fault
* delivery fault
* platform decision

Refund rules must be centralized and auditable.

---

# 119. Reviews

Customer can review:

```text
Vendor
Order
Delivery
```

Reviews must be associated with completed orders.

Prevent arbitrary reviews from users who never ordered.

---

# 120. Fraud Prevention

Future subsystem should detect:

```text
multiple fake accounts
payment abuse
coupon abuse
refund abuse
GPS spoofing
delivery fraud
review manipulation
```

Signals can include:

```text
device
IP
account history
campus
payment
order patterns
GPS
```

Do not block solely on one weak signal.

---

# 121. Customer Notifications

Examples:

```text
Welcome
Verification approved
Order confirmed
Payment successful
Vendor accepted
Food ready
Partner assigned
Partner nearby
Partner arrived
Order completed
Refund processed
Promotion
```

Users must be able to control non-essential marketing notifications.

---

# 122. Marketing Notifications

Marketing messages must be separated from transactional notifications.

Transactional:

```text
Your order is ready.
```

Marketing:

```text
Try today's special burger.
```

Different consent/preferences.

---

# 123. Data Retention

Define retention policies for:

```text
orders
payments
financial records
delivery locations
logs
audit logs
support tickets
verification documents
notifications
```

Do not retain GPS history indefinitely by default.

---

# 124. Privacy

Collect only data necessary for:

* identity
* ordering
* payment
* delivery
* support
* fraud prevention
* analytics

Sensitive documents should have restricted access.

---

# 125. Security Threat Model

Must consider:

```text
Unauthorized campus access
JWT theft
IDOR
horizontal privilege escalation
vendor data leakage
payment tampering
order manipulation
GPS spoofing
API abuse
brute force
coupon fraud
fake accounts
Kafka event injection
admin abuse
```

---

# 126. IDOR Prevention

Every resource request must verify ownership/scope.

Bad:

```text
GET /orders/{id}
```

with only authentication.

Correct:

```text
Authenticated customer
+
order.customer_id == authenticated user
+
order.campus_id == active campus
```

---

# 127. Vendor Authorization

Vendor staff:

```text
authenticated user
+
vendor membership
+
permission
+
vendor resource ownership
```

before accessing an order.

---

# 128. Delivery Authorization

Delivery partner:

```text
authenticated partner
+
delivery assignment belongs to partner
+
assignment active
```

before modifying delivery.

---

# 129. Admin Authorization

Platform administrators require:

```text
role
+
permission
+
audit
```

High-risk actions should require additional controls.

Examples:

```text
large refund
financial adjustment
admin impersonation
vendor suspension
```

---

# 130. Admin Impersonation

If ever implemented:

* explicit reason
* visible impersonation banner
* audit log
* limited duration
* restricted actions

Never silently impersonate customers/vendors.

---

# 131. Event Security

Kafka is internal.

Mobile clients never receive raw Kafka credentials.

Kafka topics require:

* authentication
* authorization
* encryption in transit
* controlled producer/consumer ACLs

---

# 132. API Security

Implement:

```text
rate limiting
request validation
authentication
authorization
input sanitization
secure headers
TLS
```

Sensitive APIs receive stricter limits.

---

# 133. Database Security

Each service should have its own database credentials with only the privileges required.

Avoid:

```text
one superuser credential
```

for every service.

---

# 134. Database Row-Level Security

Where useful, PostgreSQL RLS may provide an additional isolation layer. PostgreSQL policies can restrict SELECT/INSERT/UPDATE/DELETE based on policy expressions. ([PostgreSQL][2])

However:

> Application authorization remains mandatory.

---

# 135. Testing Strategy

Testing layers:

```text
Unit
Integration
Contract
Component
End-to-End
Load
Security
Chaos/Failure
```

---

# 136. Unit Tests

Every service tests:

* domain rules
* state transitions
* pricing
* permissions
* validation
* financial calculations

---

# 137. Integration Tests

Test:

```text
PostgreSQL
Redis
Kafka
Payment providers
FCM/APNs
```

using appropriate test infrastructure.

---

# 138. Contract Testing

Especially important for microservices.

Verify:

```text
Order Service
 ↔ Payment Service

Order Service
 ↔ Delivery Service

Kafka producer
 ↔ Kafka consumer
```

Event schemas should be versioned.

---

# 139. End-to-End Test

Canonical test:

```text
Customer registers
 ↓
Customer verified
 ↓
Campus selected
 ↓
Vendor discovered
 ↓
Item selected
 ↓
Order created
 ↓
UPI/payment succeeds
 ↓
Vendor accepts
 ↓
Food prepared
 ↓
Delivery assigned
 ↓
Partner picks up
 ↓
Partner reaches hostel
 ↓
Customer receives notification
 ↓
OTP verified
 ↓
Order completed
 ↓
Vendor settlement recorded
```

---

# 140. Failure Testing

Must explicitly test:

```text
payment timeout
payment duplicate callback
Kafka unavailable
Kafka duplicate event
Redis unavailable
vendor app offline
delivery app offline
customer app killed
network switch
GPS unavailable
partner rejects assignment
vendor rejects order
refund failure
database connection exhaustion
```

---

# 141. Load Testing

Important scenarios:

### Dinner spike

```text
19:00–22:00
```

### Campus spike

One campus suddenly has:

```text
thousands of concurrent users
```

### Multi-campus spike

Hundreds of campuses simultaneously experience meal-time traffic.

---

# 142. Scalability Model

Do not assume every campus has the same traffic.

Model:

```text
Campus A
1000 users

Campus B
20,000 users

Campus C
100,000 users
```

Services must scale based on actual load.

---

# 143. Hot Campus Problem

One campus can become disproportionately busy.

Partitioning and caching must prevent:

```text
VIT dinner spike
```

from taking down:

```text
entire platform
```

---

# 144. Campus-Level Isolation in Kafka

Events should carry:

```text
campusId
```

where applicable.

Consumers may use partitioning strategies that preserve useful locality.

However, authorization must still occur downstream.

A `campusId` in an event is not itself an authorization credential.

---

# 145. Analytics Architecture

```text
Domain Services
      ↓
Kafka
      ↓
Analytics Consumers
      ↓
Analytics Store
      ↓
Dashboards
```

Transactional DBs should not be used for large analytical aggregation.

---

# 146. Data Warehouse

Eventually:

```text
Kafka
 ↓
Streaming / ETL
 ↓
Data Warehouse
 ↓
BI
```

Possible future stack:

```text
BigQuery
Snowflake
ClickHouse
Redshift
etc.
```

Do not commit to one until traffic and business needs justify it.

---

# 147. Observability Dashboard

Platform team should see:

```text
Requests/sec
Latency
Error rate
Kafka lag
Database connections
Redis health
Active orders
Orders/min
Payment failures
Delivery assignments
Notification failures
```

---

# 148. Business Dashboard

Separate from infrastructure monitoring:

```text
GMV
Revenue
Orders
AOV
Commission
Delivery cost
Vendor performance
Campus performance
Customer retention
```

---

# 149. Globalization

International readiness requires:

```text
country
currency
timezone
locale
language
tax rules
payment methods
address model
phone format
legal configuration
```

---

# 150. Currency

Never use floating point for money.

Use:

```text
DECIMAL/NUMERIC
```

or integer minor units where appropriate.

Example:

```text
₹250.50
```

must not be represented using a binary floating-point `double`.

---

# 151. Time

Store timestamps consistently in UTC.

Convert to campus timezone at presentation/business-boundary level.

Campus configuration contains:

```text
timezone
```

---

# 152. Localization

Do not hardcode UI strings.

Use localization keys:

```text
order.status.preparing
order.status.ready
```

rather than embedding English everywhere.

---

# 153. India Configuration

Initial:

```text
Currency: INR
Timezone: Asia/Kolkata
Payment: UPI + cards
Tax: India configuration
```

UPI is a required first-class payment method.

---

# 154. Global Payment Abstraction

Payment domain exposes a generic interface:

```text
createPayment()
verifyPayment()
refundPayment()
getPaymentStatus()
```

Provider implementation handles:

```text
UPI provider
Card provider
Stripe
Adyen
other providers
```

The Order Service should not know provider-specific details.

---

# 155. Mobile Offline Behavior

Customer app should gracefully handle temporary network loss.

Delivery app especially needs offline tolerance.

Examples:

```text
location queue
status update queue
retry mechanism
```

Critical state transitions must be confirmed by server.

---

# 156. Delivery Offline

If delivery partner loses network:

```text
GPS buffered locally
```

where privacy/security policies permit.

Status actions are retried.

Server resolves duplicate actions using idempotency.

---

# 157. App Security

Flutter applications must:

* use secure storage
* validate server responses
* avoid embedded secrets
* use TLS
* handle token expiry
* detect compromised sessions where appropriate

No secret API keys should be embedded in the app.

---

# 158. Version Compatibility

Backend must tolerate multiple mobile app versions during rollout.

Example:

```text
Customer App 1.0
Customer App 1.1
Customer App 2.0
```

API changes should be backward compatible where practical.

---

# 159. Feature Flags

Use feature flags for:

```text
new checkout
new dispatch algorithm
new payment provider
new campus
new promotion
experimental UI
```

This allows gradual rollout.

---

# 160. Campus Rollout

New campus onboarding:

```text
Create campus
 ↓
Configure geography
 ↓
Import hostels
 ↓
Create pickup points
 ↓
Onboard vendors
 ↓
Configure vendor menus
 ↓
Hire/assign delivery partners
 ↓
Configure verification
 ↓
Test delivery
 ↓
Soft launch
 ↓
Full launch
```

---

# 161. VIT Pilot

VIT should be treated as:

```text
Campus ID = data/configuration
```

not as a special application.

The pilot should validate:

* student verification
* vendor onboarding
* order flow
* delivery logistics
* pickup points
* partner access
* payments
* notifications
* tracking
* economics

---

# 162. Initial VIT Delivery Model

Recommended:

```text
Vendor
 ↓
CampusFood Delivery Partner
 ↓
Hostel Block Pickup Point
 ↓
Customer
```

Do not initially require room-to-room delivery.

---

# 163. Why Pickup Points

Benefits:

* fewer walking routes
* faster delivery
* batch delivery
* less hostel intrusion
* simpler security
* easier partner management
* lower delivery cost
* easier campus approval

---

# 164. Delivery Partner ID

Future operational capability:

```text
CampusFood Delivery ID
```

Contains:

```text
photo
partner_id
authorized campuses
validity
status
QR verification
```

Security can verify the partner.

---

# 165. Vendor Operating Hours

Vendor can define:

```text
Monday
Tuesday
...
```

with:

```text
open
close
breaks
```

Catalog availability may differ from vendor operating hours.

---

# 166. Vendor Capacity

Future:

```text
maximum active orders
estimated preparation time
temporary pause
item-level availability
```

Vendor can pause new orders.

---

# 167. Order Queue

Vendor dashboard should sort orders based on:

```text
priority
order age
promised time
preparation time
```

---

# 168. Customer Ordering Flow

```text
Login
 ↓
Verification
 ↓
Active Campus
 ↓
Vendor Discovery
 ↓
Vendor
 ↓
Menu
 ↓
Item
 ↓
Cart
 ↓
Delivery Location
 ↓
Checkout
 ↓
Payment
 ↓
Order Tracking
```

---

# 169. Vendor Ordering Flow

```text
New Order
 ↓
Accept
 ↓
Prepare
 ↓
Ready
 ↓
Handoff
```

---

# 170. Delivery Flow

```text
Available
 ↓
Receive assignment
 ↓
Accept
 ↓
Navigate to vendor
 ↓
Pickup
 ↓
Navigate to pickup point
 ↓
Arrive
 ↓
Customer handoff
 ↓
Complete
```

---

# 171. Platform Operations Flow

```text
Campus
 ↓
Hostel configuration
 ↓
Vendor approval
 ↓
Customer verification
 ↓
Partner approval
 ↓
Monitor orders
 ↓
Resolve incidents
 ↓
Settlement
 ↓
Analytics
```

---

# 172. Order Event Example

When order is created:

```text
Order DB
    ↓
transaction
    ├── order row
    └── outbox row
            ↓
         Kafka
            ↓
     OrderCreated
```

Consumers:

```text
Notification
Analytics
Realtime
Fraud
Customer Projection
```

---

# 173. Why Kafka Should Not Be the Mobile Backend

Incorrect:

```text
Flutter
   ↓
Kafka
```

Correct:

```text
Flutter
 ↓
API Gateway / Realtime Gateway
 ↓
Services
 ↓
Kafka
```

Kafka is internal infrastructure.

---

# 174. Source of Truth Model

Final decision:

```text
POSTGRES / DOMAIN DATABASE
        ↓
   AUTHORITATIVE STATE

KAFKA
        ↓
   EVENT DISTRIBUTION

REDIS
        ↓
   EPHEMERAL/HOT STATE

READ MODELS
        ↓
   OPTIMIZED PROJECTIONS

FLUTTER
        ↓
   PRESENTATION
```

This is a core architectural invariant.

---

# 175. Recommended Source-of-Truth Table

| Data                       | Source of Truth                          |
| -------------------------- | ---------------------------------------- |
| Customer profile           | Customer DB                              |
| Membership                 | Customer DB                              |
| Campus                     | Campus DB                                |
| Vendor                     | Vendor DB                                |
| Menu                       | Catalog DB                               |
| Order                      | Order DB                                 |
| Payment                    | Payment DB                               |
| Ledger                     | Financial DB                             |
| Delivery assignment        | Delivery DB                              |
| Current location           | Redis/Tracking system                    |
| Historical business events | Kafka + durable event retention strategy |
| Notifications              | Notification DB/provider                 |
| Analytics                  | Analytics store                          |
| Search                     | Search projection                        |

---

# 176. Event Sourcing Decision

Do **not** make the entire platform event-sourced in V1.

Use:

> CRUD/transactional domain state + event-driven integration.

Event sourcing can be introduced for specific domains if justified later.

---

# 177. Why This Is Better

It avoids requiring every developer to understand:

```text
event replay
aggregate reconstruction
event versioning
snapshotting
```

for every entity.

Yet you still obtain:

* asynchronous processing
* scalability
* decoupling
* realtime updates
* analytics
* replayable downstream projections

---

# 178. Portfolio Positioning

The project should be presented as:

> **A multi-tenant, campus-restricted, event-driven commerce and logistics platform built for high-density residential campuses.**

Technologies:

```text
Java
Spring Boot
Spring Security
Spring Kafka
PostgreSQL
Redis
Kafka
Docker
Kubernetes
Flutter
WebSockets
OpenTelemetry
Prometheus
Grafana
```

The portfolio should demonstrate architecture, not merely screenshots.

---

# 179. Portfolio Demonstrations

You should eventually demonstrate:

### Tenant isolation

```text
VIT customer
→ VIT vendors

SRM vendors
→ inaccessible
```

### Event-driven order flow

```text
OrderCreated
→ Payment
→ Vendor
→ Delivery
→ Notification
```

### Failure recovery

```text
Kafka temporarily unavailable
→ outbox retains event
→ event eventually published
```

### Idempotency

```text
duplicate payment callback
→ one financial transaction
```

### Realtime tracking

```text
delivery partner GPS
→ Redis
→ realtime gateway
→ customer
```

### Kubernetes scaling

```text
dinner spike
→ Order Service scales independently
```

---

# 180. Definition of Done — Core Ordering

Ordering MVP is complete when:

* customer can authenticate
* customer is verified
* customer has active campus
* only campus vendors are visible
* customer can browse menu
* customer can create cart
* customer can checkout
* payment succeeds
* vendor receives order
* vendor accepts
* vendor prepares
* vendor marks ready
* delivery assignment occurs
* partner accepts
* partner picks up
* partner arrives
* customer receives notification
* customer collects
* order completes
* financial records reconcile

---

# 181. Definition of Done — Security

* authentication works
* authorization works
* campus isolation tested
* IDOR tests pass
* vendor isolation tested
* delivery-partner isolation tested
* admin permissions tested
* payment APIs idempotent
* secrets secured
* audit logs active
* rate limiting active

---

# 182. Definition of Done — Distributed Architecture

* service boundaries documented
* database ownership documented
* Kafka topics documented
* event schemas versioned
* outbox implemented
* consumers idempotent
* retry policies implemented
* DLQ implemented
* correlation IDs implemented
* tracing implemented
* health probes implemented

---

# 183. Definition of Done — Production

* CI/CD
* staging environment
* production environment
* automated backups
* monitoring
* alerting
* disaster recovery plan
* rollback procedure
* security scanning
* load testing
* incident procedures

---

# 184. Implementation Order

Do not attempt to implement every microservice simultaneously.

Recommended sequence:

```text
PHASE 0
Architecture + repository + coding standards
```

```text
PHASE 1
Identity + Customer + Campus
```

```text
PHASE 2
Vendor + Catalog
```

```text
PHASE 3
Cart + Order
```

```text
PHASE 4
Payment + Financial Ledger
```

```text
PHASE 5
Delivery + Dispatch
```

```text
PHASE 6
Tracking + Redis + Realtime
```

```text
PHASE 7
Kafka + Outbox + Notification
```

```text
PHASE 8
Promotion + Advertising
```

```text
PHASE 9
Platform Operations
```

```text
PHASE 10
Observability + Security Hardening
```

```text
PHASE 11
Docker + Kubernetes + CI/CD
```

```text
PHASE 12
VIT production pilot
```

```text
PHASE 13
Multi-campus expansion
```

---

# 185. Architectural Decisions That Are Now Locked

The following decisions should be treated as baseline architectural decisions unless later evidence proves them wrong:

```text
1. Campus is the primary operational isolation boundary.

2. University administration is not a required application actor.

3. Customer is the generic customer role.
   Student/PhD/faculty/staff are membership types.

4. One active campus context per user at a time.

5. Users may have multiple campus memberships over time.

6. Vendors are normally campus-specific in V1.

7. Vendors are manually approved by CampusFood.

8. Delivery partners are hired/approved by CampusFood.

9. Hostel/block/pickup-point data is configuration.

10. Scraping is an ingestion mechanism, not a runtime dependency.

11. Logical multi-tenancy first.

12. No database-per-campus initially.

13. Architecture must permit future sharding.

14. Microservices are domain-oriented.

15. PostgreSQL/domain databases are authoritative.

16. Kafka is the event backbone, not the database of record.

17. Mobile apps never directly consume Kafka.

18. Realtime Gateway consumes internal events and exposes
    authorized realtime updates.

19. Redis is used for ephemeral/hot state.

20. Order/payment/financial operations require idempotency.

21. Transactional Outbox is used for reliable event publication.

22. Consumers must be idempotent.

23. RBAC + resource/campus scope is used.

24. No VIT/SRM-specific code paths.

25. India-first, globally capable.

26. UPI is mandatory for Indian launch.

27. Payment providers are abstracted.

28. Financial ledger is a dedicated concern.

29. Advertising is a dedicated domain.

30. Campus admin dashboard is not required for V1.

31. Pickup-point delivery is preferred over room-to-room delivery.

32. Customer/vendor/delivery applications use APIs and
    authorized realtime channels—not Kafka directly.

33. Analytics consumes events rather than querying transactional
    databases heavily.

34. Event sourcing is not the default architecture.

35. Kubernetes is the deployment target, but infrastructure
    complexity should scale with actual business needs.

36. Bhook platform/super-admin operations can onboard and configure
  campuses, hostels, pickup points, vendors, customers, and delivery
  partners from the platform control plane.

37. Vendors can manage their own catalog with vendor-scoped CRUD,
  pricing, availability, variants, modifiers, and schedules; historical
  order and financial snapshots are immutable.

38. Platform-only friendships and privacy-limited order sharing are included
  in the first version as a Bhook USP. Per-order sharing is explicit and
  OFF by default, and revocable.

39. Future group ordering uses independent participant orders and payments
  inside an OrderGroup/SharedDeliveryBatch; compatible nearby orders may
  share vendor preparation and delivery, but failures remain isolated.

40. V1 uses named hostel blocks/buildings/pickup points and configured
  instructions. Map engine, routing, and polygon geofencing are future
  enhancements.
```

---

# 186. Final Reference Architecture

```text
                         ┌──────────────────────────┐
                         │       FLUTTER APPS       │
                         │                          │
                         │ Customer                 │
                         │ Vendor                  │
                         │ Delivery Partner        │
                         └────────────┬─────────────┘
                                      │
                           HTTPS / WebSocket
                                      │
                         ┌────────────▼─────────────┐
                         │       API GATEWAY        │
                         │                          │
                         │ Auth / Routing / Rate    │
                         │ Limiting / Correlation   │
                         └────────────┬─────────────┘
                                      │
              ┌───────────────────────┼──────────────────────┐
              │                       │                      │
              ▼                       ▼                      ▼
        Identity                  Customer                 Campus
        Service                   Service                  Service
              │                       │                      │
              │                       │                      │
              ├──────────────┬────────┴──────────────┐       │
              │              │                       │       │
              ▼              ▼                       ▼       ▼
          Vendor         Catalog                  Order    Delivery
          Service        Service                  Service  Service
                                                      │        │
                                                      │        ▼
                                                      │     Dispatch
                                                      │     Service
                                                      │        │
                                                      ▼        ▼
                                                  Payment   Tracking
                                                  Service   Service
                                                      │        │
                                                      ▼        ▼
                                                  Financial Redis
                                                  Service
                                                      │
                                                      │
                    ┌─────────────────────────────────┘
                    │
                    ▼
             TRANSACTIONAL OUTBOX
                    │
                    ▼
               ┌───────────┐
               │   KAFKA   │
               │           │
               │ Events    │
               └─────┬─────┘
                     │
        ┌────────────┼─────────────┬─────────────┐
        │            │             │             │
        ▼            ▼             ▼             ▼
 Notification   Analytics      Realtime       Audit
 Service        Service        Gateway        Service
        │            │             │
        ▼            ▼             ▼
      FCM/APNs   Analytics DB   WebSocket
                                  │
                                  ▼
                              Flutter Apps


              ┌──────────────────────────────────────┐
              │          PLATFORM CONTROL PLANE      │
              │                                      │
              │ Operations / Support / Finance /     │
              │ Marketing / Super Admin              │
              └──────────────────┬───────────────────┘
                                 │
                                 ▼
                              APIs +
                         Read Models +
                           Realtime
```

---

# 187. The Most Important Architectural Mental Model

If you remember only one diagram from this SRS, make it this:

```text
                 ┌───────────────────┐
                 │   DOMAIN STATE    │
                 │                   │
                 │   PostgreSQL      │
                 │                   │
                 │  "WHAT IS TRUE"   │
                 └─────────┬─────────┘
                           │
                    Transactional
                       Outbox
                           │
                           ▼
                 ┌───────────────────┐
                 │      KAFKA        │
                 │                   │
                 │ "WHAT HAPPENED"   │
                 └─────────┬─────────┘
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
          ▼                ▼                 ▼
     Notifications     Analytics       Realtime
          │                │                 │
          ▼                ▼                 ▼
       Devices        Read Models       WebSocket
```

And alongside it:

```text
Redis
=
"What needs to be extremely fast right now?"
```

That distinction will prevent a **huge number of architectural mistakes** later.

---

# 188. Final Architectural Verdict

After revisiting the assumptions, I would **not** change the fundamental direction we arrived at.

I would, however, make these four corrections to our earlier discussion:

### Correction 1

**Kafka is not the source of truth.**

It is the event backbone.

### Correction 2

**The college does not need to be an application actor.**

Campus is a domain/configuration boundary; platform operations own it.

### Correction 3

**Don't shard initially.**

Design for sharding, implement logical isolation first.

### Correction 4

**Don't expose Kafka to Flutter.**

Apps use APIs for authoritative state and an authorized realtime gateway for live events.

With those corrections, I think we have a **very solid architectural foundation**.

The next engineering artifact should *not* be more high-level discussion. It should be the **implementation-level system blueprint**: exact service repositories, exact database schemas/tables and relationships, indexes, enums/state machines, REST endpoints, request/response contracts, Kafka topic/event schemas, Redis key strategy, authorization matrix, payment state machine, order saga, delivery dispatch algorithm, WebSocket protocol, Flutter folder architecture, Docker/Kubernetes structure, CI/CD, and the exact implementation sequence.

That can become the **SRS v2 / Technical Design Specification** from which we can actually start building.

[1]: https://docs.spring.io/spring-kafka/docs/3.1.10/reference/kafka/exactly-once.html?utm_source=chatgpt.com "Exactly Once Semantics :: Spring Kafka"
[2]: https://www.postgresql.org/docs/17/ddl-rowsecurity.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 17: 5.9. Row Security Policies"
[3]: https://kubernetes.io/docs/reference/kubernetes-api/autoscaling/?utm_source=chatgpt.com "Autoscaling | Kubernetes"
