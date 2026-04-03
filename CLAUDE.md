# Gasthaus Dashboard — Claude Code Instructions

## Project Overview
This is the Next.js staff dashboard for Gasthaus, an AI-powered restaurant 
management system. It connects to a NestJS backend on localhost:3001 and 
a FastAPI AI service on localhost:8000.

## Tech Stack
- Next.js 16 with App Router
- TypeScript
- React 19
- Tailwind CSS v4 (CSS-based config via @theme in globals.css — no tailwind.config.js)
- shadcn/ui components
- Socket.io client for real-time updates
- Axios for API calls

## Backend API
Base URL: http://localhost:3001/api
Auth: JWT Bearer token stored in localStorage as 'gasthaus_token'

### Key Endpoints
- POST /auth/login → { user, token }
- POST /auth/register
- GET /auth/me
- GET /menu/categories → public, returns categories with items
- GET /menu/items
- POST /menu/items → MANAGER only, multipart/form-data
- PATCH /menu/items/:id → MANAGER only
- DELETE /menu/items/:id → MANAGER only
- PATCH /menu/items/:id/toggle → MANAGER only
- POST /menu/categories → MANAGER only
- DELETE /menu/categories/:id → MANAGER only
- GET /orders → staff only (WAITER, KITCHEN, MANAGER)
- POST /orders → CUSTOMER only
- GET /orders/my → CUSTOMER only
- GET /orders/:id
- PATCH /orders/:id/status → staff only
  Body: { status: "CONFIRMED"|"PREPARING"|"READY"|"SERVED"|"COMPLETED"|"CANCELLED" }
- POST /reviews → CUSTOMER only
- GET /reviews/item/:menuItemId → public
- GET /reviews/order/:orderId → CUSTOMER only
- GET /reviews → MANAGER only
- POST /ai/recommend → CUSTOMER only
- POST /ai/insights → MANAGER only
- POST /ai/review-summary
- DELETE /ai/session → CUSTOMER only
- GET /tables → MANAGER/WAITER only
- POST /tables → MANAGER only { tableNumber: number }
- GET /tables/stats → MANAGER/WAITER only
- GET /tables/number/:num → public
- PATCH /tables/:id/toggle → MANAGER/WAITER only
- DELETE /tables/:id → MANAGER only

## WebSocket
URL: ws://localhost:3001
Library: socket.io-client
Events from server:
- order:new → new order placed, staff dashboard listens
- order:status → order status changed, all listen
- order:ready → order ready, customer listens

## User Roles
CUSTOMER, WAITER, KITCHEN, MANAGER

## Design System
See designs/design.md for full design system.
Key values:
- Primary font: Inter
- Dark sidebar: #1C1C1E
- Amber accent: #D97706
- Active nav: left border 2px #D97706 + background #2C2C2C
- Content background: #F9F9F7
- Card background: #FFFFFF
- Border color: #E5E7EB
- No shadows, no gradients, max border-radius 8px

## Pages
1. /login — public, login form
2. /dashboard — overview stats, live orders, table map
3. /orders — Kanban board with WebSocket updates
4. /kitchen — kitchen display, full screen dark theme
5. /menu — menu management with edit drawer
6. /tables — floor plan with table details panel
7. /reviews — review list with rating overview
8. /insights — AI insights with charts

## Stitch HTML Designs
All 8 page designs are in stitch-designs/ as HTML files.
Reference them when building each page — extract the 
component structure, colors, and layout from them.

## Auth Flow
- Unauthenticated users redirect to /login
- After login, store JWT in localStorage as 'gasthaus_token'
- Store user object in localStorage as 'gasthaus_user'
- Role-based routing: KITCHEN role goes to /kitchen directly
- MANAGER and WAITER go to /dashboard

## Shared Components Needed
- Sidebar (dark, with nav items, active state, admin avatar)
- Header (56px, white, page title + date + bell + avatar)
- These two wrap every page except /login and /kitchen

## Important Notes
- Kitchen display (/kitchen) has NO sidebar/header — full screen only
- All chart components use recharts library
- Real-time order updates use Socket.io
- Menu item images upload to Cloudinary via the backend
- The sidebar active state issue across pages gets fixed here 
  by using ONE shared Sidebar component

## Design System Notes
The stitch-designs/design.md describes Stitch's internal 
design philosophy. Where it conflicts with values in this 
CLAUDE.md, always prefer this CLAUDE.md. Key overrides:
- Primary amber is #D97706 not #8d4b00
- 1px solid #E5E7EB borders ARE used on cards
- Branding is "GASTHAUS" not "The Modern Archivist"
- 3-column grids are acceptable (menu page uses them)


---

## Spring Boot Backend (gasthaus-backend-java/)

This is a Java/Spring Boot reimplementation of the NestJS 
backend for learning and interview preparation. It is 
functionally identical to gasthaus-backend/ but uses 
Java enterprise patterns.

### Tech Stack
- Java 21
- Spring Boot 3.x
- Spring Data JPA + Hibernate (replaces Prisma)
- Spring Security + JWT (replaces NestJS Guards)
- Maven (dependency management)
- Spring WebSocket + STOMP (replaces Socket.io)
- Bean Validation (replaces class-validator DTOs)
- Same PostgreSQL database (port 5432, different schema prefix)
- Same Docker containers from gasthaus-backend/docker-compose.yml

### Port
Runs on port 8080 (NestJS runs on 3001, no conflict)

### Learning Goal
Understand every line — not just make it work.
Claude should explain each Spring/Java concept as it 
writes it, comparing it to the NestJS equivalent 
where relevant.

### NestJS → Spring Boot Mapping
- @Module → @Configuration / @SpringBootApplication
- @Injectable → @Service
- @Controller → @RestController
- PrismaService → JpaRepository<Entity, UUID>
- @UseGuards(JwtAuthGuard) → Spring Security filter chain
- @Roles() decorator → @PreAuthorize("hasRole('MANAGER')")
- ValidationPipe + class-validator → @Valid + Bean Validation
- Socket.io gateway → @MessageMapping + SimpMessagingTemplate
- NestJS pipes → Spring @ControllerAdvice + @ExceptionHandler

### Build Order (Phases)
Phase 1: Project setup + JPA entities (models)
Phase 2: Repository layer + Database config
Phase 3: JWT Security config + Auth endpoints
Phase 4: Menu endpoints
Phase 5: Orders + WebSocket
Phase 6: Reviews + Tables
Phase 7: AI proxy (calls FastAPI same as NestJS version)

---

## Bug Fixes Log

All bugs fixed in this project are documented in `bug_fixes.md` at the repo root.

**Policy:** whenever a bug is fixed, add an entry to `bug_fixes.md` with:
- A short ID (BF-001, BF-002, …)
- The file(s) changed
- **What** the bug was (symptom)
- **Why** it happened (root cause)
- **Fix** summary (what changed and why it works)

This log is append-only — never remove or edit existing entries.

---

## Code Comments Policy (Flutter App)

The user is studying Flutter and Dart through this project.
**Always add inline comments to all Flutter/Dart code** explaining:
- What the code does
- Why this approach was chosen (e.g. why `ChangeNotifier` vs alternatives)
- Flutter/Dart-specific concepts that may be unfamiliar (e.g. `BuildContext`, `initState`, `didChangeDependencies`)
- Comparisons to equivalent patterns in other languages/frameworks where helpful

Comments should be educational, not just descriptive. Assume the reader knows
programming but is new to Flutter. This applies to every file in `gasthaus_app/`.