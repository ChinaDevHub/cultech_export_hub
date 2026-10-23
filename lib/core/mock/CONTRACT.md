# Mock backend — API contract

The app runs **fully offline**: `MockAdapter` (lib/core/mock/mock_core.dart) answers every `/api/*`
call from `MockDb` (in memory). Handlers are registered per area in `lib/core/mock/routes/`. The
Flutter client (models in `lib/core/models/`, `lib/features/*/data/`) is the consumer — **always read
the client model/repository that calls an endpoint and return JSON it parses fully**.

Base path `/api`, JSON in/out, `Authorization: Bearer mock-<userId>`. Errors: throw `MockError`
(`{error}` + 4xx). All prices are **AZN numbers**. Uploads are multipart (`req.files`, `req.body`).

## Public / buyer
- `GET /config` → `MockRef.config()` (done in core).
- `GET /stats`.
- `GET /products?q&craft&region&cert=verified|pending&mode=all|ready|custom&sort=popular|newest|priceAsc|priceDesc&min&max`
  → `{items:[{type:'product'|'variant', id, productId, title, image, priceAZN, craft, artisan, cert, ready, wants, leadDays, concept?}], total}`
  (variants only when approved + visible; `mode=ready` products only, `custom` variants only).
- `GET /products/:id?lang=xx` → `MockViews.productDetail` (variants[], moreFromArtisan, translatedTo).
- `GET /variants/:id` → `{variant, product}`; `GET /artisans`; `GET /artisans/:id` (story, skills, products[], variants[], soldCount).
- `POST /wants {itemType,itemId,email}` → `{wants:n}` (increments the product/variant counter, records in `db.wants`).
- `POST /checkout/quote {itemType:'product'|'variant'|'custom', itemId, country, qty}` → `{artisanAZN, serviceFeeAZN, shippingAZN, totalAZN, qty}`. `custom`: itemId is a request id (R-…), unit price = its accepted/offered price.
- `POST /orders {itemType,itemId,qty,name,email,country,address,deposit?}` → `{order, checkoutUrl:null}` (payment is simulated; made-to-order variants default to a 30 % deposit when `deposit` is true → `paidAZN` = 30 %).
- `POST /orders/:id/pay-balance {email}` → pays the remaining balance (`paidAZN = total`) → `{order, checkoutUrl:null}`.
- `GET /orders/track?id=&email=` → `{order: MockOrders.view(o), artisan}`; 404 `Order not found…` when id/email do not match. IDs starting `GR-` are group orders → `GET /groups/track?id=&email=`.
- `GET /certificates/:number` → `{certificate, product, artisan}` (+ `history`).
- **Custom orders**: `POST /custom-requests` (multipart: productId,name,email,country,size,colorId,pattern,notes,quantity,sample?) → `{request}`; `GET /custom-requests/:id?email=`; `POST /custom-requests/:id/message {email,text}`; `POST /custom-requests/:id/accept {email,address,deposit}` → `{order, checkoutUrl}`.
- **Gifts**: `GET /gifts` → `{boxes[{id,name,tagline,description,items[],cover[],priceAZN,boxFeeAZN,logoFeeAZN,makers}], tiers}`; `POST /gifts/quote {boxId,boxes,country,logo}`; `POST /gifts/order` (multipart incl. `logo`) → `{group}`; `GET /groups/:id/story`.
- **Experiences**: `GET /experiences?type=visit|masterclass&region=`; `POST /experiences/:id/book {name,email,phone,date,people}`.
- **Academy**: `GET /academy`; `POST /courses/:id/apply {name,phone,age,message}`.
- **B2B** (role `b2b`): `POST /auth/register-b2b`; `GET /b2b/catalog`; `POST /b2b/price {lines[{itemType,itemId,qty}],country}`; `POST /b2b/orders {lines,country,address,note}` → `{group}`; `GET /b2b/orders`; `POST /b2b/orders/:id/reorder`; `POST/GET /b2b/quotes`; `POST /b2b/quotes/:id/accept {address}`.
- **WhatsApp**: `POST /whatsapp/simulate` (multipart `phone,text,images[]`) → `{replies[]}`; `GET /whatsapp/outbox?phone=&after=ISO`.

## Auth
`POST /auth/login {login,password}` (phone for artisans/coordinators, email otherwise) → `{token,user{id,role,name,company?}}`;
roles `artisan|coordinator|b2b|admin|expert|ministry`. `POST /auth/register-artisan` (multipart), `POST /auth/register-b2b`, `GET /auth/me`.

## Artisan (`/artisan/*`, role artisan — or coordinator with header `x-act-as: <artisanId>`; use `req.requireArtisan()`)
- `GET /dashboard` → `artisan, skills, earnings{earned,pending,paidOut,payable}, stats{products,wants,openOrders,needHandover,requests,bookings}, products[] (summaryAz[], en{…}, priceAZN, priceSource, range, warning, breakdown, cert, variantConsent, stock, video, variants[{status,concept,hint,wants,priceAZN,leadDays,reasonAz,nameAz}]), notifications[], unread, actingAs`.
- Product flow: `POST /products` (multipart `images[]`≤4, `transcript`, `price?`) → `{product}` (draft, AI content; ~2.5 s latency) · `GET /products/:id` · `POST /products/:id/revise {note}` · `/confirm {price}` → publishes · `/price {price}` · `/variants {consent}` (**variants are generated ONLY when consent is true**) · `POST /variants/:id/decide {can,price,leadDays}` · `POST /pricing/preview {price,craftId,days,country}` → `{range, warning, breakdown}` · `POST /products/:id/video` (multipart `video`, `transcript`).
- Orders: `GET /orders` (az views) · `POST /orders/:id/accept` · `POST /orders/:id/photo` (multipart `photo`) · `POST /orders/:id/handover {method:'post'|'pickup'}`.
- `GET /earnings`; Requests: `GET /requests`, `POST /requests/:id/quote {price,leadDays,note}`, `/decline`, `/message {text}`; Experiences: `GET /experiences`, `POST /experiences {type,titleAz,descriptionAz,priceAZN,durationH,maxPeople,dates[]}`, `DELETE /experiences/:id`; Training: `GET /training`, `POST /courses {title,description,weeks,seats,free}`.
- `POST /notifications/read`, `PUT /profile` (multipart), `PUT /skills {skills[]}`.

## Coordinator
`GET /coordinator/dashboard` (artisans with sales/earnings, weekly collection `route[]`, recent orders), `POST /coordinator/artisans` (multipart; returns a generated password), `POST /coordinator/orders/:id/collected`. Only the coordinator's own artisans (`artisan.coordinatorId == user.id`).

## Admin / expert / ministry
- `/admin/overview`, `/admin/certs` (experts only see requests **routed to them by craft**; admins can `POST /admin/certs/:kind/:id/assign {expertId}`), `POST /admin/certs/:kind/:id/decide {action:'approve'|'reject',category,note}`, `/admin/products`, `PUT /admin/products/:id`, `POST /admin/products/:id/hide`, `POST /admin/variants/:id/hide`, `/admin/orders` (+ `POST …/status`, `POST …/tracking {carrierId}`, `GET …/customs`, `POST …/pay-balance`), `/admin/artisans`, `/admin/quotes` + `POST …/offer {priceAZN,note}`, `/admin/groups`, `/admin/payouts` + `POST /admin/payouts/:artisanId`, `GET /admin/export/etsy|shopify|amazon|json` (files → `MockBytes`).
- Ministry: `GET /ministry/overview?days=14|30|90` (KPIs incl. women share, series, breakdowns), `GET /ministry/export.csv`.

## Business rules the mock must keep
1. The artisan always sets the final price; AI only recommends (`range`), warnings are soft strings.
2. Variants exist only after consent; only **approved + visible** variants appear to buyers; "can't" is remembered (never re-suggested).
3. AI never confirms authenticity: new products are `cert.status = pending` until an expert approves (assigns number `AZ-CULT-00NN`, history entry with expert name + specialty).
4. Order flows come from `MockOrders` (ready vs made-to-order). Never hard-code steps in handlers.
5. Artisans are paid out **after delivery** (`payable` = delivered orders without `payoutRef`); they receive their full price (the 15 % fee is paid by the buyer); domestic collection is paid by the platform.
6. Notifications for artisans are Azerbaijani (`db.notify(artisanId, textAz, type:)`), e.g. sold / new order / cert approved.
7. Made-to-order: 30 % deposit starts the work; balance paid before shipping; buyer sees the artisan's real photo (`realPhoto`) before it ships.
8. Coordinators act for their own artisans only.

## Demo accounts (already seeded)
artisan `+994501110001..05` / `demo123`; coordinator `+994501110009` / `demo123`; admin `admin@cultech.az` / `admin123`;
experts `expert@cultech.az`, `expert2@`, `expert3@` / `expert123`; ministry `ministry@culture.gov.az` / `ministry123`;
B2B `b2b@hotel-berlin.example` / `b2b123`.
