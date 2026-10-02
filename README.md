# 📡 Monitoring & Publishing Tools

> **Social Media Management Platform** — Sistem manajemen sosial media yang terintegrasi untuk mempublikasikan konten ke LinkedIn, Facebook, dan Instagram, dilengkapi dengan CRM (Customer Relationship Management), analytics dashboard, dan scheduled posting.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Arsitektur Sistem](#arsitektur-sistem)
- [Fitur Utama](#fitur-utama)
- [Struktur Project](#struktur-project)
- [Konfigurasi Environment](#konfigurasi-environment)
- [Setup & Instalasi](#setup--instalasi)
- [Docker & Deployment](#docker--deployment)
- [API Versioning & Maintenance](#api-versioning--maintenance)
- [Dependencies](#dependencies)
- [Catatan Penting](#catatan-penting)

---

## Overview

Project ini adalah platform manajemen sosial media berbasis **Laravel 11** yang memungkinkan pengguna untuk:

1. **Publish Post** langsung ke LinkedIn, Facebook, dan Instagram (text, image, multi-image, video)
2. **Schedule Post** dengan sistem antrian (queue) untuk posting terjadwal
3. **Monitor & Analisis** performa konten di setiap platform (engagement rate, impressions, reach, dll)
4. **CRM System** untuk mengelola leads, accounts, deals, dan aktivitas pelanggan
5. **Export Data** analytics ke format Excel

Platform ini di-deploy menggunakan **Docker** ke **AWS** dengan **Traefik** sebagai reverse proxy dan **GitLab CI/CD** untuk continuous deployment.

---

## Tech Stack

| Komponen         | Teknologi                                |
| ---------------- | ---------------------------------------- |
| **Framework**    | Laravel 11 (PHP 8.3)                     |
| **Frontend**     | Blade Templates + TailwindCSS + DaisyUI  |
| **Build Tool**   | Vite 7.x                                 |
| **HTTP Client**  | GuzzleHTTP 7.8                           |
| **Queue**        | Laravel Queue (Database Driver)          |
| **Database**     | MySQL                                    |
| **Auth**         | Laravel UI + Laravel Socialite (Google)  |
| **Container**    | Docker + Supervisor                      |
| **Reverse Proxy**| Traefik                                  |
| **CI/CD**        | GitLab CI/CD                             |
| **Deployment**   | AWS (via Docker Compose)                 |

---

## Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS / Docker Host                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Docker Container (PHP 8.3)               │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Supervisord (PID 1)                │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │  │  │
│  │  │  │ Laravel  │ │   NPM    │ │  Queue Worker    │ │  │  │
│  │  │  │ Serve    │ │ Dev/Build│ │  (php artisan    │ │  │  │
│  │  │  │ :9000    │ │          │ │   queue:work)    │ │  │  │
│  │  │  └──────────┘ └──────────┘ └──────────────────┘ │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌──────────────┐   ┌──────┴───────┐   ┌──────────────────┐ │
│  │   Traefik    │◄──│   Network    │──►│    MySQL DB      │ │
│  │ (HTTPS/TLS)  │   │   (proxy)    │   │  (external)      │ │
│  └──────────────┘   └──────────────┘   └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │
    HTTPS Traffic
         │
    ┌────┴────┐
    │  Users  │
    └─────────┘
```

### Alur Posting Social Media

```
User Submit Post
       │
       ├──► Direct Post ──► Service Layer ──► Platform API ──► Published
       │
       └──► Schedule Post ──► ScheduleService ──► Laravel Queue (delay)
                                                       │
                                                       ▼
                                                 Job Dispatched
                                                       │
                                    ┌──────────────────┼──────────────────┐
                                    ▼                  ▼                  ▼
                            PostToLinkedInJob   PostToFacebookJob  PostToInstagramJob
                                    │                  │                  │
                                    ▼                  ▼                  ▼
                            LinkedIn REST API   Graph API (FB)    Graph API (IG)
```

---

## Fitur Utama

### 1. Social Media Publishing
- **LinkedIn**: Text post, image (single/multi), video ke Organization Page
- **Facebook**: Text post, image (single/multi), video ke Facebook Page
- **Instagram**: Image (single/carousel), video (Reels) ke Business Account
- **CRUD Post**: Create, Edit (update caption), Delete post di semua platform

### 2. Scheduled Posting
- Penjadwalan post dengan delay berbasis Laravel Queue
- Support multi-platform scheduling (LinkedIn + Facebook + Instagram sekaligus)
- Manajemen job schedule (view, cancel)
- Failed job tracking

### 3. Analytics & Monitoring
- **Dashboard**: Engagement rate, impressions rate, followers count per platform
- **Analyze**: Detail analytics per platform dengan filter tanggal
- **Export Excel**: Export data performa ke Excel (LinkedIn, Facebook, Instagram)

### 4. CRM System
- **Leads Management**: CRUD, convert, bulk actions
- **Accounts Management**: CRUD, dashboard, merge, bulk actions

### 5. User Management
- Multi-role: admin, manager, sales, marketing
- Google OAuth login via Socialite
- Rate limiting (60 requests/minute)
- Activity logging (Spatie Activity Log)

---

## Struktur Project

```
├── app/
│   ├── Exports/                          # Excel export classes
│   │   ├── analyzeExportFacebook.php
│   │   ├── analyzeExportInstagram.php
│   │   └── analyzeExportLinkedin.php
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Auth/                     # Authentication controllers
│   │   │   ├── crm/                      # CRM controllers (Lead, Account)
│   │   │   └── sistem/                   # Core system controllers
│   │   │       ├── SocialMedia/          # OAuth callback & posting (FB, IG, LK)
│   │   │       ├── PostSocial/           # Post management
│   │   │       ├── scheduleSocial/       # Schedule management
│   │   │       ├── analyze/              # Analytics controllers
│   │   │       ├── dashboard/            # Dashboard controller
│   │   │       ├── data/                 # Data table controllers
│   │   │       ├── job/                  # Job schedule controller
│   │   │       ├── account/              # User account management
│   │   │       └── profile/              # Profile controller
│   │   ├── Middleware/
│   │   └── Requests/
│   ├── Jobs/                             # Queue jobs
│   │   ├── PostToFacebookJob.php
│   │   ├── PostToInstagramJob.php
│   │   └── PostToLinkedInJob.php
│   ├── Models/
│   │   ├── User.php
│   │   ├── Providers.php                 # Social media OAuth providers
│   │   ├── DataSocial.php                # Published post data
│   │   ├── ProfileSocial.php             # Social media profile stats
│   │   ├── SchedulePosts.php             # Scheduled posts
│   │   ├── Jobs.php / FailedJobs.php
│   │   └── crm/                          # CRM models (10 models)
│   ├── Providers/
│   └── Services/
│       ├── Facebook/
│       │   ├── FaceBookService.php       # Facebook Graph API service
│       │   └── PrepareFacebookService.php # Image upload preparation
│       ├── Instagram/
│       │   ├── InstagramService.php      # Instagram Graph API service
│       │   └── PrepareInstagramService.php # Carousel preparation
│       ├── LinkedIn/
│       │   ├── LinkedInService.php       # LinkedIn REST API service
│       │   └── prepareLinkedInService.php # Media upload (photo/video/chunk)
│       ├── Database/
│       │   └── ProfileSocialService.php  # Profile data service
│       └── ScheduleService.php           # Schedule post orchestrator
├── config/
│   ├── facebook.php                      # Facebook API config
│   ├── instagram.php                     # Instagram API config
│   ├── linkedin.php                      # LinkedIn API config
│   └── ...
├── database/migrations/                  # 12 migration files
├── resources/views/
│   ├── sistem/                           # System views
│   ├── crm/                              # CRM views
│   ├── overview.blade.php                # Overview page
│   └── welcome.blade.php                 # Landing page
├── routes/
│   ├── web.php                           # All web routes
│   └── console.php
├── Dockerfile                            # PHP 8.3 container
├── docker-compose.yml                    # Docker Compose with Traefik
├── supervisord.conf                      # Supervisor config (Laravel + Queue + NPM)
├── .gitlab-ci.yml                        # CI/CD pipeline
└── .env.example                          # Environment template
```

---

## Konfigurasi Environment

Salin `.env.example` ke `.env` dan isi semua variable berikut:

### Social Media API Credentials

```env
# LinkedIn
LINKEDIN_CLIENT_ID=
LINKEDIN_CLIENT_SECRET=
LINKEDIN_REDIRECT_URI=https://yourdomain.com/sosial-media/linkedin/callback
LINKEDIN_SCOPE='r_ads_reporting r_organization_social rw_organization_admin w_member_social r_ads w_organization_social rw_ads r_basicprofile r_organization_admin r_1st_connections_size'
LINKEDIN_SSL=false

# Instagram (menggunakan Meta/Facebook App)
INSTAGRAM_CLIENT_ID=
INSTAGRAM_CLIENT_SECRET=
INSTAGRAM_REDIRECT_URI=https://yourdomain.com/sosial-media/instagram/callback
INSTAGRAM_SCOPE='some_string'
INSTAGRAM_SSL=false
INSTAGRAM_IDKONFIGURATION=

# Facebook
FACEBOOK_CLIENT_ID=
FACEBOOK_CLIENT_SECRET=
FACEBOOK_REDIRECT_URI=https://yourdomain.com/sosial-media/facebook/callback
FACEBOOK_SCOPE='instagram_basic,pages_show_list,business_management'
FACEBOOK_SSL=false
FACEBOOK_IDKONFIGURATION=
```

### Lainnya

```env
# Google OAuth (Login)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT="https://yourdomain.com/auth/google/callback"

# Cloudflare Turnstile
TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=

# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=db_SocialSymphony
DB_USERNAME=root
DB_PASSWORD=

# Queue (wajib database)
QUEUE_CONNECTION=database
```

---

## Setup & Instalasi

### Local Development

```bash
# 1. Clone repository
git clone <repository-url>
cd Monitoring-and-Publising-Tools

# 2. Copy environment
cp .env.example .env

# 3. Install PHP dependencies
composer install

# 4. Install NPM dependencies
npm install

# 5. Generate application key
php artisan key:generate

# 6. Jalankan migration
php artisan migrate

# 7. Buat storage link
php artisan storage:link

# 8. Cache config
php artisan config:cache

# 9. Jalankan development server
php artisan serve

# 10. Jalankan Vite (terminal terpisah)
npm run dev

# 11. Jalankan Queue Worker (terminal terpisah)
php artisan queue:work --sleep=3 --tries=3
```

### Menggunakan Docker

```bash
# Build dan jalankan
docker compose up -d --build

# Cek status container
docker compose ps
```

---

## Docker & Deployment

### Dockerfile
- Base image: `php:8.3`
- Termasuk: Composer 2.4.4, Node.js, NPM, Supervisor
- PHP Extensions: `pdo_mysql`, `mysqli`, `bcmath`, `gd`, `zip`
- Expose port: `9000`

### Supervisord (3 proses)
1. **Laravel Server** — `php artisan serve --host=0.0.0.0 --port=9000`
2. **NPM Dev** — `npm run dev`
3. **Queue Worker** — `php artisan queue:work --sleep=3 --tries=3`

### Docker Compose
- Menggunakan **Traefik** sebagai reverse proxy dengan auto SSL/TLS
- Networks: `database-network` (external), `proxy` (external)
- Image name dikonfigurasi via `IMAGE_NAME` env variable

### GitLab CI/CD Pipeline

| Stage       | Job                       | Keterangan                                    |
| ----------- | ------------------------- | --------------------------------------------- |
| `build`     | `build`                   | Build Docker image                            |
| `test`      | `automation-test`         | Placeholder untuk automation test             |
| `test`      | `vulnerabilities-test`    | Placeholder untuk vulnerability scan          |
| `publish`   | `publish`                 | Push image ke GitLab Container Registry       |
| `release`   | `production`              | Deploy ke production (docker compose up)      |
| `database`  | `production-migration`    | Jalankan database migration                   |
| `database`  | `production-seeding`      | Fresh seed (manual trigger)                   |
| `optimize`  | `production-optimize`     | Cache optimization                            |

> **Trigger**: Pipeline berjalan hanya pada tag release (bukan branch).

---

## ⚠️ API Versioning & Maintenance

### Ringkasan Versi API

| Platform     | Versi Saat Ini | Lokasi Constant                                               | Siklus Update  |
| ----------   | -------------- | --------------------------------------------------            | -------------- |
| **Facebook** | `v21.0`        | `app/Services/Facebook/FaceBookService.php` (line 18)         | **6 bulan**    |
| **Facebook** | `v21.0`        | `app/Services/Facebook/PrepareFacebookService.php` (line 9)   | **6 bulan**    |
| **Instagram**| `v21.0`        | `app/Services/Instagram/InstagramService.php` (line 19)       | **6 bulan**    |
| **Instagram**| `v21.0`        | `app/Services/Instagram/PrepareInstagramService.php` (line 9) | **6 bulan**    |
| **LinkedIn** | `202509`       | `app/Services/LinkedIn/LinkedInService.php` (line 16)         | **12 bulan**   |
| **LinkedIn** | `202405`       | `app/Services/LinkedIn/prepareLinkedInService.php` (line 16)  | **12 bulan**   |

> ⚠️ **PERHATIAN**: `prepareLinkedInService.php` masih menggunakan versi `202405`, sementara `LinkedInService.php` sudah `202509`. Pastikan kedua file menggunakan versi yang sama!

### Dokumentasi API Resmi

| Platform       | Dokumentasi URL                                                    | Catatan                                              |
| -------------- | ------------------------------------------------------------------ | ---------------------------------------------------- |
| **LinkedIn**   | https://learn.microsoft.com/en-us/linkedin/                        | Update 1 tahun sekali                                |
| **Meta (FB+IG)**| https://developers.facebook.com/documentation/development          | **WAJIB** gunakan docs baru ini                     |
| **Meta (lama)**| https://developers.facebook.com/docs/graph-api                     | Docs lama, sudah **TIDAK DIPAKAI** untuk referensi  |

### Jadwal Pengecekan Rutin

- **Setiap 6 bulan**: Cek update versi API Facebook & Instagram (Meta Graph API)
- **Setiap 12 bulan**: Cek update versi API LinkedIn
- **Setiap 6 bulan**: Baca changelog dan breaking changes dari dokumentasi API resmi
- **Setiap update**: Pastikan **semua** file service yang terkait diupdate versi API-nya secara konsisten

---

## Dependencies

### PHP (Composer)

| Package                        | Versi     | Fungsi                                    |
| ------------------------------ | --------- | ----------------------------------------- |
| `laravel/framework`           | `^11.44`  | Core framework                            |
| `guzzlehttp/guzzle`           | `^7.8`    | HTTP client untuk API calls               |
| `guzzlehttp/promises`         | `^2.0`    | Async/concurrent API calls                |
| `laravel/socialite`           | `^5.23`   | OAuth authentication (Google)             |
| `laravel/ui`                  | `^4.5`    | Auth scaffolding                          |
| `maatwebsite/excel`           | `^3.1`    | Export data ke Excel                      |
| `spatie/laravel-activitylog`  | `^4.8`    | Activity logging                          |
| `realrashid/sweet-alert`      | `^7.1`    | Sweet Alert notifications                 |
| `binarytorch/larecipe`        | `^2.8.1`  | Dokumentasi internal                      |
| `hashids/hashids`             | `^5.0`    | Hash IDs                                  |
| `laravel/tinker`              | `^2.9`    | Console REPL                              |

### NPM (Frontend)

| Package                | Versi       | Fungsi                     |
| ---------------------- | ----------- | -------------------------- |
| `tailwindcss`         | `^3.4.4`    | CSS framework              |
| `daisyui`             | `^4.12.6`   | TailwindCSS component lib  |
| `vite`                | `^7.1.7`    | Build tool                 |
| `laravel-vite-plugin` | `^2.0.1`    | Laravel Vite integration   |
| `autoprefixer`        | `^10.4.19`  | CSS autoprefixer           |
| `postcss`             | `^8.4.38`   | CSS processing             |
| `axios`               | `^1.6.4`    | HTTP client (frontend)     |

---

## Catatan Penting

### 🔴 Kritis
1. **API Version Sync**: Pastikan versi API di file `Service` dan `Prepare*Service` selalu sinkron
2. **Token Expiry**: Sistem sudah cek `expires_at` sebelum posting — pastikan token di-refresh sebelum kadaluarsa
3. **Queue Worker WAJIB Running**: Scheduled post bergantung pada queue worker. Jika worker mati, post terjadwal tidak akan terkirim
4. **Meta API Migration**: Facebook/Instagram sekarang **WAJIB** mengikuti docs baru di `developers.facebook.com/documentation/development`

### 🟡 Perhatian
1. **File `prepareLinkedInService.php`** menggunakan versi API `202405` (lebih lama dari `LinkedInService.php` yang `202509`)
2. **Job `PostToLinkedInJob.php` line 69 & 72**: Menggunakan assignment (`=`) bukan comparison (`==`) di kondisi if — ini adalah bug
3. **`sleep(50)`** di `PostToFacebookJob` dan `PostToInstagramJob` untuk menunggu video processing LinkedIn — ini blocking dan bisa ditingkatkan
4. **`dd()` statements** masih ada di `prepareLinkedInService.php` (line 268, 275, 282) — harus dihapus di production

### 🟢 Rekomendasi
1. Rutin cek update dependencies: `composer outdated` dan `npm outdated`
2. Monitoring Docker container health dan supervisor process status
3. Implementasi health check endpoint untuk monitoring
4. Tambahkan proper error handling dan retry mechanism di jobs
5. Pertimbangkan menggunakan Redis untuk queue (lebih performa dari database)

---

## License

Private — Internal Use Only.
