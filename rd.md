# 📋 Reference Document (RD) — Monitoring & Publishing Tools

> **Dokumen ini ditujukan untuk AI Agent (Claude/lainnya) yang akan melanjutkan development project ini.**
> Baca seluruh dokumen ini sebelum melakukan perubahan apapun.

---

## 1. KONTEKS PROJECT

### Apa project ini?
Sebuah platform **Social Media Management** berbasis **Laravel 11** yang berjalan di **Docker** dan di-deploy ke **AWS**. Project ini memiliki **2 sistem utama**:

1. **CRM (Customer Relationship Management)** — Manajemen leads, accounts, deals, aktivitas pelanggan
2. **Publish & Schedule Post** — Publikasi konten ke LinkedIn, Facebook, Instagram (direct + scheduled)

### Framework & Runtime
- **PHP 8.3** + **Laravel 11** (`^11.44.1`)
- **MySQL** (database)
- **Vite 7.x** + **TailwindCSS 3.4** + **DaisyUI 4.x** (frontend)
- **Docker** + **Supervisord** (deployment)
- **Traefik** (reverse proxy + auto SSL)
- **GitLab CI/CD** (pipeline)

---

## 2. STRUKTUR CODEBASE — FILE-BY-FILE DETAIL

### 2.1 Services Layer (INTI LOGIC API)

#### `app/Services/Facebook/FaceBookService.php`
- **API Version**: `private const VERSION_API = 'v21.0';` ← PERLU DICEK SETIAP **6 BULAN**
- **Base URL**: `https://graph.facebook.com/{VERSION_API}/`
- **Video URL**: `https://graph-video.facebook.com/{VERSION_API}/`
- **Fungsi utama**:
  - `getAuthUrl()` — Generate OAuth URL (menggunakan `config_id`)
  - `getAccessToken($code)` — Exchange code → access token
  - `getUserInfo($token)` — Get Facebook Page info (menggunakan `/me/accounts`)
  - `getFollowers($token, $facebookUserId)` — Get followers count
  - `getStatistic($token, $facebookUserId)` — Get page engagement, impressions, calculate rates
  - `getTotalPosts($token, $facebookUserId, $startDate, $endDate)` — Count posts with date filter
  - `getAnalyzeFacebook($token, $idpost, $startDate, $endDate)` — Async/concurrent insights fetch (8 metrics)
  - `postText($token, $facebookUserId, $caption)` — Publish text post ke `/feed`
  - `postImage($token, $facebookUserId, $message, $urlImage, $imageContainerId)` — Single image ke `/photos`, multi-image ke `/feed` dengan `attached_media`
  - `postVideo($token, $facebookUserId, $message, $urlVideo)` — Video post ke `/videos`
  - `updatePost($token, $postId, $message)` — Update post caption
  - `deletePost($token, $postId)` — Delete post (menggunakan HTTP DELETE)
- **HTTP Client**: `GuzzleHttp\Client` via private method `curl()`
- **Concurrent requests**: Menggunakan `GuzzleHttp\Promise\Utils::settle()` di `getAnalyzeFacebook()`

#### `app/Services/Facebook/PrepareFacebookService.php`
- **API Version**: `private const VERSION_API = 'v21.0';` ← HARUS SINKRON dengan `FaceBookService.php`
- **Fungsi**:
  - `preparePostImage($accessToken, $provider_id, $urlImage)` — Upload foto ke Facebook sebagai unpublished (`published=false`) untuk dipakai di multi-image post

#### `app/Services/Instagram/InstagramService.php`
- **API Version**: `private const VERSION_API = 'v21.0';` ← PERLU DICEK SETIAP **6 BULAN**
- **Base URL**: `https://graph.facebook.com/{VERSION_API}/` (Instagram menggunakan Facebook Graph API)
- **Catatan Penting**: Instagram Business Account diakses melalui Facebook Page → `instagram_business_account`
- **Fungsi utama**:
  - `getAuthUrl()` — Generate OAuth URL (sama seperti Facebook, menggunakan `config_id`)
  - `getAccessToken($code)` — Exchange code → access token
  - `getUserInfo($token)` — Flow: `/me/accounts` → Get FB Page ID → Get `instagram_business_account` ID → Get IG profile
  - `getFollowers($token, $instagramUserId)` — Get followers count
  - `getStatistic($token, $instagramUserId)` — Get reach & impressions (28 days)
  - `getInsightPost($token, $idMedia)` — Get post-level insights (likes)
  - `getTotalPosts($token, $instagramUserId, $startDate, $endDate)` — Count media
  - `getAnalyzeInstagram($token, $idpost, $startDate, $endDate)` — Async/concurrent insights (5-7 metrics)
  - `postImage($token, $instagramUserId, $idImage, $caption)` — **2-step**: Create container → Publish. Supports single image & CAROUSEL
  - `postVideo($token, $instagramUserId, $caption, $isUrl)` — **3-step**: Initialize resumable upload → Upload video via URL → Publish
  - `updatePost($token, $postId, $caption)` — Update caption
  - `deletePost($token, $postId)` — Delete media
- **Upload Video**: Menggunakan resumable upload (`upload_type=resumable`, `media_type=REELS`)

#### `app/Services/Instagram/PrepareInstagramService.php`
- **API Version**: `private const VERSION_API = 'v21.0';` ← HARUS SINKRON
- **Fungsi**:
  - `preparePostImage($token, $instagramUserId, $imageUrl)` — Create carousel item container (`is_carousel_item=true`)

#### `app/Services/LinkedIn/LinkedInService.php`
- **API Version**: `private const VERSION_API_LINKEDIN = '202509';` ← PERLU DICEK SETIAP **12 BULAN** (terakhir update September 2025)
- **Base URLs**:
  - Auth: `https://www.linkedin.com/oauth/v2/`
  - API v2: `https://api.linkedin.com/v2/`
  - REST API: `https://api.linkedin.com/rest/`
- **Header penting**: `Linkedin-Version`, `X-Restli-Protocol-Version: 2.0.0`
- **Fungsi utama**:
  - `getAuthUrl()` — Generate OAuth URL
  - `getAccessToken($code)` — Exchange code → access token
  - `getPerson($accessToken)` — Get personal profile (`/v2/me`)
  - `getCompanyID($accessToken)` — Get organization ACLs (`/rest/organizationAcls`)
  - `getFollowersOrganization($accessToken, $orgId)` — Get organization followers (`/v2/networkSizes`)
  - `getStatisticsOrganization($accessToken, $orgId)` — Get share statistics (`/rest/organizationalEntityShareStatistics`)
  - `getTotalPosts($accessToken, $orgId)` — Get posts count (`/rest/posts`)
  - `getCompanyPages($accessToken, $orgId)` — Get organization details
  - `getLogoCompany($accessToken, $orgId)` — Get organization logo URL
  - `getAnalyzeLinkedIn($token, $orgId, $startDate, $endDate)` — Time-series analytics
  - `linkedInTextPostOrganization(...)` — Text post ke `/rest/posts`
  - `linkedInPhotoPostOrganization(...)` — Photo post (single + multiImage)
  - `linkedInVideoPostOrganization(...)` — Video post
  - `linkedInUpdateugcPost(...)` — Update UGC post (PARTIAL_UPDATE)
  - `linkedInUpdatesharePost(...)` — Update Share post
  - `linkedInDeletesharePost(...)` — Delete Share post
  - `linkedInDeleteugcPost(...)` — Delete UGC post
- **Response codes**: POST → `201`, UPDATE → `204`, DELETE → `204`
- **Post ID**: Disimpan dari header `x-restli-id`

#### `app/Services/LinkedIn/prepareLinkedInService.php`
- **⚠️ API Version**: `private const VERSION_API_LINKEDIN = '202405';` ← **BERBEDA** dari `LinkedInService.php` (`202509`)! **INI PERLU DISINKRONKAN**
- **Fungsi**:
  - `linkedInInitializePhoto(...)` — Initialize image upload (`/rest/images?action=initializeUpload`)
  - `linkedInUploadPhoto(...)` — PUT upload binary image
  - `linkedInGetPostImage(...)` — Get image download URL
  - `uploadVideo(...)` — **Orchestrator**: Handles chunked upload (4MB chunks) atau whole upload
  - `uploadWholeVideo(...)` — Upload video < 4MB langsung
  - `linkedInInitializeVideo(...)` — Initialize video upload (`/rest/videos?action=initializeUpload`)
  - `linkedinUploadVideo(...)` — Upload video binary
  - `linkedinUploadVideoChunk(...)` — Upload video chunk
  - `linkedInVideoPostOrganization(...)` — Finalize video upload (`/rest/videos?action=finalizeUpload`)
  - `linkedInGetPostVideo(...)` — Get video download URL
- **⚠️ BUGS**: Ada `dd()` statements di line 268, 275, 282 yang harus dihapus!

#### `app/Services/ScheduleService.php`
- **Orchestrator** untuk scheduled posting ke semua platform
- **Flow**:
  1. Terima data post (title, datetime, files, selectedProviders)
  2. Hitung delay dari `now()` ke `scheduleDateTime`
  3. Upload files ke `storage/app/public/uploads/`
  4. Generate kode schedule (format: `{PLATFORM_CODE}{YY}{0001}`, contoh: `LK260001`)
  5. Insert ke `post_schedules` table
  6. Dispatch job dengan `->delay($delay)`
- **Cancel Job**: `cancelJob($scheduleId)` — Scan semua jobs di database, deserialize payload, match `id_schedule`, lalu delete
- **Platform codes**: `LK` (LinkedIn), `FB` (Facebook), `IG` (Instagram)

#### `app/Services/Database/ProfileSocialService.php`
- Service untuk menyimpan/update data profil sosial media ke database

---

### 2.2 Queue Jobs

#### `app/Jobs/PostToLinkedInJob.php`
- **ShouldQueue** — Dijalankan oleh queue worker
- **Flow**:
  1. Cek token expiry
  2. Jika tanpa file → text post (`linkedInTextPostOrganization`)
  3. Jika ada file → prepare upload via `prepareLinkedInService` → image/video post
  4. Success → simpan ke `DataSocial` (kode: `PSLK0001`)
  5. Failed → hapus schedule + insert ke `failed_jobs`
- **⚠️ BUG**: Line 69 & 72 menggunakan `=` (assignment) bukan `==` (comparison): `if ($requestPrepare['media'] = 'Image')`

#### `app/Jobs/PostToFacebookJob.php`
- **Flow**:
  1. Cek token expiry
  2. Tanpa file → text post
  3. Ada file → upload ke LinkedIn CDN dulu (untuk mendapatkan public URL) → post ke Facebook
  4. Multi-image → prepare via `PrepareFacebookService` (unpublished photos) → post ke `/feed` dengan `attached_media`
  5. Success → simpan ke `DataSocial` (kode: `PSFB0001`)
- **Catatan**: Facebook & Instagram Jobs bergantung pada LinkedIn service untuk mengupload media dan mendapatkan public URL

#### `app/Jobs/PostToInstagramJob.php`
- **Flow**:
  1. Cek token expiry
  2. Upload file ke LinkedIn CDN → get public URL
  3. Multi-image → prepare carousel items via `PrepareInstagramService`
  4. Single/Carousel → post via `InstagramService`
  5. Video → post video via `InstagramService`
  6. Success → simpan ke `DataSocial` (kode: `PSIG0001`)
- **⚠️ CATATAN**: `sleep(50)` blocking call untuk menunggu video processing

---

### 2.3 Models & Database

#### Database Tables (dari migrations):

| Table                     | Model             | Deskripsi                           |
| ------------------------- | ----------------- | ----------------------------------- |
| `users`                   | `User`            | Users dengan roles (admin, manager, sales, marketing) |
| `social_media_providers`  | `Providers`       | OAuth provider data (token, provider_id, dll)        |
| `user_social_posts`       | `DataSocial`      | Published post records                               |
| `user_social_profiles`    | `ProfileSocial`   | Social media profile statistics                      |
| `post_schedules`          | `SchedulePosts`   | Scheduled post data                                  |
| `jobs`                    | `Jobs`            | Laravel queue jobs                                   |
| `failed_jobs`             | `FailedJobs`      | Failed queue jobs                                    |
| `activity_log`            | —                 | Spatie Activity Log                                  |
| `sessions`                | —                 | Database sessions                                    |
| `cache`                   | —                 | Database cache                                       |
| CRM tables                | crm/*             | Leads, Accounts, Deals, Contacts, Activities, dll    |

#### Model Relationships
- `User` → hasMany `Providers`, `DataSocial`, `ProfileSocial`, `SchedulePosts`
- `Providers` → belongsTo `User` (via `user_id` → `id_user`)
- ID Format Conventions:
  - `id_social`: `LK001`, `FB001`, `IG001` (platform + sequential)
  - `id_posts`: `PSLK0001`, `PSFB0001`, `PSIG0001` (PS + platform + sequential)
  - `id_schedule`: `LK260001`, `FB260001`, `IG260001` (platform + year + sequential)
  - `id_profile`: `LK001`, `FB001`, `IG001`

---

### 2.4 Controllers

#### Social Media Controllers (`app/Http/Controllers/sistem/SocialMedia/`)
- `LinkedInController` — OAuth callback + posting
- `FaceBookController` — OAuth callback + posting
- `InstagramController` — OAuth callback + posting
- `SocialMediaController` — Index (connection page) + delete provider

#### Other Controllers
- `OverviewController` — Main overview/dashboard
- `SocialController` — Social media dashboard with stats
- `ScheduleController` — CRUD schedule posts
- `PostController` — Post management index
- `AnalyzeController` — Analytics per platform + export Excel
- `JobController` — View jobs & failed jobs
- `DataFacebookController`, `DataInstagramController`, `DataLinkedInController` — Data tables CRUD
- `AccountController` (sistem) — User management
- `ProfileController` — User profile
- `LeadController` (crm) — Lead CRUD + convert + bulk actions
- `AccountController` (crm) — Account CRUD + merge + bulk actions

---

### 2.5 Routes (`routes/web.php`)

Semua route di-protect oleh middleware: `auth`, `role:admin-manager-sales-marketing`, `throttle:60,1`

```
/ ................................. welcome page
/overview ........................ Dashboard overview
/sosial-media .................... Social media connections
/sosial-media/dashboard .......... Social dashboard stats
/sosial-media/{platform}/callback  OAuth callbacks (linkedin, instagram, facebook)
/posts ........................... Post management
/posts/{platform}/post ........... Create post (LinkedIn, Instagram, Facebook)
/schedule ........................ Schedule CRUD (index, store, edit, update)
/job-schedule .................... Job schedule view
/job-schedule-failed ............. Failed jobs (index, destroy)
/profile ......................... User profile
/users ........................... User CRUD (admin only)
/{LinkedIn|Facebook|Instagram} ... Data table per platform
/analyze{FB|IG|LK} .............. Analytics per platform
/analyze{FB|IG|LK}Filter ........ Analytics with date filter
/export-{platform} .............. Export Excel per platform
/leads ........................... CRM Leads CRUD + convert + bulk
/accounts ........................ CRM Accounts CRUD + dashboard + merge + bulk
```

Auth routes: Laravel default (`Auth::routes(['register' => false])`) + Google Socialite.

---

### 2.6 Config Files

```php
// config/facebook.php
'app_id' => env('FACEBOOK_CLIENT_ID'),
'app_secret' => env('FACEBOOK_CLIENT_SECRET'),
'app_callback' => env('FACEBOOK_REDIRECT_URI'),
'app_scopes' => env('FACEBOOK_SCOPE'),
'ssl' => env('FACEBOOK_SSL', true),
'id_configuration' => env('FACEBOOK_IDKONFIGURATION', true),

// config/instagram.php — Sama struktur dengan facebook.php

// config/linkedin.php
'app_id' => env('LINKEDIN_CLIENT_ID'),
'app_secret' => env('LINKEDIN_CLIENT_SECRET'),
'app_callback' => env('LINKEDIN_REDIRECT_URI'),
'app_scopes' => env('LINKEDIN_SCOPE'),
'ssl' => env('LINKEDIN_SSL', true),
```

---

## 3. INFRASTRUKTUR & DEPLOYMENT

### Docker (`Dockerfile`)
```
FROM php:8.3
├── apt-get: zip, unzip, git, cron, nodejs, npm, supervisor, libpq-dev, ...
├── composer 2.4.4
├── PHP ext: pdo, pdo_mysql, mysqli, bcmath, gd, zip
├── user/group: www (UID 1000)
├── composer install --optimize-autoloader --no-dev
├── npm install && npm run build
├── php artisan config:cache && storage:link
├── supervisord.conf → /etc/supervisor/conf.d/
├── EXPOSE 9000
└── CMD ["/usr/bin/supervisord"]
```

### Docker Compose (`docker-compose.yml`)
```yaml
services:
  application:
    build: . (Dockerfile)
    image: ${IMAGE_NAME}
    container_name: ${IMAGE_NAME}-${APP_ENV}-application
    restart: unless-stopped
    networks: database-network, proxy
    labels: Traefik routing (HTTP→HTTPS redirect, TLS, port 9000)

networks:
  database-network: external
  proxy: external
```

### Supervisord (`supervisord.conf`)
3 proses yang dijalankan:
1. **laravel** — `php artisan serve --host=0.0.0.0 --port=9000`
2. **npm** — `npm run dev`
3. **laravel-queue-worker** — `php artisan queue:work --sleep=3 --tries=3`

### GitLab CI/CD (`.gitlab-ci.yml`)
- Runner tag: `build-gcp` (build) / `production-gcp` (deploy)
- Trigger: Tag releases only (bukan branch)
- Pipeline: build → test → publish (registry) → release (deploy) → database (migrate) → optimize

---

## 4. ⚠️ HAL KRITIS YANG HARUS DIPERHATIKAN

### 4.1 API Version Management

**Facebook & Instagram (Meta Graph API)**:
- Siklus update: **Setiap 6 bulan**
- Versi saat ini: `v21.0`
- File yang perlu diupdate saat mengganti versi:
  1. `app/Services/Facebook/FaceBookService.php` → `VERSION_API`
  2. `app/Services/Facebook/PrepareFacebookService.php` → `VERSION_API`
  3. `app/Services/Instagram/InstagramService.php` → `VERSION_API`
  4. `app/Services/Instagram/PrepareInstagramService.php` → `VERSION_API`
- **Dokumentasi WAJIB**: https://developers.facebook.com/documentation/development
- **Dokumentasi LAMA** (jangan dipakai): https://developers.facebook.com/docs/graph-api

**LinkedIn**:
- Siklus update: **Setiap 12 bulan**
- Versi saat ini: `202509` (September 2025)
- File yang perlu diupdate:
  1. `app/Services/LinkedIn/LinkedInService.php` → `VERSION_API_LINKEDIN`
  2. `app/Services/LinkedIn/prepareLinkedInService.php` → `VERSION_API_LINKEDIN`
- **⚠️ SAAT INI TIDAK SINKRON!** `LinkedInService.php` = `202509`, `prepareLinkedInService.php` = `202405`
- **Dokumentasi**: https://learn.microsoft.com/en-us/linkedin/

### 4.2 Known Bugs & Issues

| # | File | Line | Issue | Severity |
|---|------|------|-------|----------|
| 1 | `PostToLinkedInJob.php` | 69, 72 | `if ($requestPrepare['media'] = 'Image')` — menggunakan `=` (assignment) bukan `==` (comparison) | 🔴 HIGH |
| 2 | `prepareLinkedInService.php` | 268, 275, 282 | `dd()` statements — akan crash di production | 🔴 HIGH |
| 3 | `prepareLinkedInService.php` | 16 | API version `202405` tidak sinkron dengan `LinkedInService.php` (`202509`) | 🟡 MEDIUM |
| 4 | `PostToFacebookJob.php` | 197 | `sleep(50)` — blocking 50 detik untuk video processing | 🟡 MEDIUM |
| 5 | `PostToInstagramJob.php` | 193 | `sleep(50)` — blocking 50 detik untuk video processing | 🟡 MEDIUM |

### 4.3 Dependencies yang Perlu Dicek Berkala

Jalankan secara berkala:
```bash
composer outdated    # Cek outdated PHP packages
npm outdated         # Cek outdated NPM packages
```

**Packages kritis yang perlu dimonitor**:
- `laravel/framework` — Major update bisa breaking
- `guzzlehttp/guzzle` — HTTP client untuk semua API calls
- `laravel/socialite` — OAuth provider updates
- `maatwebsite/excel` — Export functionality
- `tailwindcss` + `daisyui` — Frontend framework
- `vite` + `laravel-vite-plugin` — Build tool

### 4.4 Monitoring System

Project ini punya **2 sistem yang harus selalu up**:
1. **CRM System** — Lead & Account management
2. **Publish & Schedule Post System** — Social media posting

**Yang perlu dimonitor**:
- Docker container health status
- Supervisord process status (3 proses: Laravel, NPM, Queue Worker)
- Queue worker aktif (jika mati → scheduled posts gagal)
- Database connectivity
- Token expiry untuk setiap social media provider
- API rate limits dari setiap platform

### 4.5 Docker & Deployment Notes

- Image dibangun dari `php:8.3` — pastikan tetap kompatibel saat update
- Composer version pinned ke `2.4.4` — mungkin perlu diupdate
- Networks `database-network` dan `proxy` harus sudah ada di host sebelum deploy
- Traefik harus sudah running di network `proxy` untuk routing
- SSL/TLS di-handle otomatis oleh Traefik (certresolver: http)

---

## 5. PANDUAN UNTUK NEXT DEVELOPMENT

### 5.1 Sebelum Mulai Coding

1. **Baca seluruh dokumen ini**
2. **Cek versi API terkini** di dokumentasi resmi masing-masing platform
3. **Jalankan `composer outdated` dan `npm outdated`** untuk cek dependencies
4. **Cek bugs di Section 4.2** — Fix dulu sebelum menambah fitur baru
5. **Pastikan environment `.env` sudah terisi** dengan benar

### 5.2 Konvensi Koding

- **ID Generation**: Sequential format `{PREFIX}{YY}{NNNN}` (contoh: `LK260001`)
- **Service Layer**: Semua API call ada di `app/Services/{Platform}/`
- **Prepare Services**: Upload/preparation logic terpisah dari posting logic
- **Job Pattern**: Setiap platform punya job sendiri (`PostTo{Platform}Job`)
- **Config Pattern**: Semua API credentials di `config/{platform}.php` → `.env`
- **Response Format**: Selalu return array `['status' => 'Success'/'Failed', ...]`

### 5.3 Menambah Platform Baru

Jika perlu menambah platform social media baru:
1. Buat `config/{platform}.php`
2. Tambah env variables di `.env.example`
3. Buat `app/Services/{Platform}/{Platform}Service.php`
4. (Opsional) Buat `app/Services/{Platform}/Prepare{Platform}Service.php`
5. Buat `app/Jobs/PostTo{Platform}Job.php`
6. Buat controller di `app/Http/Controllers/sistem/SocialMedia/`
7. Tambah routes di `routes/web.php`
8. Update `ScheduleService.php` untuk support platform baru
9. Update views

### 5.4 Prioritas Perbaikan (Recommended)

1. **[CRITICAL]** Fix bugs assignment vs comparison di `PostToLinkedInJob.php` (line 69, 72)
2. **[CRITICAL]** Hapus `dd()` di `prepareLinkedInService.php`
3. **[HIGH]** Sinkronkan API version di `prepareLinkedInService.php` dari `202405` → `202509`
4. **[HIGH]** Tambahkan health check endpoint untuk monitoring
5. **[MEDIUM]** Replace `sleep(50)` dengan proper polling/webhook mechanism
6. **[MEDIUM]** Pertimbangkan Redis sebagai queue driver (lebih performan)
7. **[LOW]** Tambahkan comprehensive error handling dan logging
8. **[LOW]** Tambahkan unit tests dan integration tests
9. **[LOW]** Refactor duplicated `curl()` methods ke base service class
10. **[LOW]** Refactor duplicated `getContentTypeFromExtension()` ke trait/helper

### 5.5 Pola Upload Media (Cross-Platform)

Alur upload media saat ini:
```
File Upload (User)
       │
       ▼
Storage (app/public/uploads/)
       │
       ▼
LinkedIn CDN (via prepareLinkedInService)
       │
       ├──► Get Public URL
       │
       ├──► Facebook menggunakan URL ini untuk posting
       │
       └──► Instagram menggunakan URL ini untuk posting
```

**Penting**: Facebook dan Instagram Jobs menggunakan LinkedIn CDN untuk mendapatkan public URL dari media. Ini berarti **LinkedIn provider harus selalu terkoneksi** jika ingin posting media ke FB/IG.

---

## 6. ENVIRONMENT VARIABLES LENGKAP

```env
# === App ===
APP_NAME=
APP_ICON=
APP_ENV=local
APP_KEY=                              # php artisan key:generate
APP_DEBUG=true
APP_TIMEZONE=Asia/Jakarta
APP_URL=http://localhost

# === Database ===
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=db_SocialSymphony
DB_USERNAME=root
DB_PASSWORD=

# === Queue (WAJIB database) ===
QUEUE_CONNECTION=database

# === Session ===
SESSION_DRIVER=database

# === Cache ===
CACHE_STORE=database

# === LinkedIn API ===
LINKEDIN_CLIENT_ID=
LINKEDIN_CLIENT_SECRET=
LINKEDIN_REDIRECT_URI=https://yourdomain.com/sosial-media/linkedin/callback
LINKEDIN_SCOPE='r_ads_reporting r_organization_social rw_organization_admin w_member_social r_ads w_organization_social rw_ads r_basicprofile r_organization_admin r_1st_connections_size'
LINKEDIN_SSL=false

# === Instagram API (via Meta/Facebook) ===
INSTAGRAM_CLIENT_ID=
INSTAGRAM_CLIENT_SECRET=
INSTAGRAM_REDIRECT_URI=https://yourdomain.com/sosial-media/instagram/callback
INSTAGRAM_SCOPE='some_string'
INSTAGRAM_SSL=false
INSTAGRAM_IDKONFIGURATION=            # Facebook Login Configuration ID

# === Facebook API ===
FACEBOOK_CLIENT_ID=
FACEBOOK_CLIENT_SECRET=
FACEBOOK_REDIRECT_URI=https://yourdomain.com/sosial-media/facebook/callback
FACEBOOK_SCOPE='instagram_basic,pages_show_list,business_management'
FACEBOOK_SSL=false
FACEBOOK_IDKONFIGURATION=            # Facebook Login Configuration ID

# === Cloudflare Turnstile ===
TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=

# === Google OAuth (Login) ===
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT="https://yourdomain.com/auth/google/callback"

# === Docker Deployment ===
IMAGE_NAME=                           # Docker image name
APP_HOST=                             # Domain for Traefik routing
```

---

## 7. REFERENSI API DOKUMENTASI

| Platform | URL Dokumentasi | Catatan |
|----------|----------------|---------|
| **LinkedIn** | https://learn.microsoft.com/en-us/linkedin/ | Update 1 tahun sekali |
| **Meta (FB + IG)** | https://developers.facebook.com/documentation/development | **WAJIB** pakai docs ini (baru) |
| **Meta (lama)** | https://developers.facebook.com/docs/graph-api | **JANGAN PAKAI** — sudah deprecated |

---

## 8. QUICK REFERENCE — PERINTAH PENTING

```bash
# Development
php artisan serve                    # Start dev server
npm run dev                          # Start Vite dev server
php artisan queue:work --sleep=3 --tries=3  # Start queue worker

# Database
php artisan migrate                  # Run migrations
php artisan migrate:fresh --seed     # Reset & seed database

# Cache
php artisan config:cache             # Cache config
php artisan config:clear             # Clear config cache
php artisan optimize                 # Optimize app

# Docker
docker compose up -d --build         # Build & start
docker compose ps                    # Check status
docker compose logs -f application   # View logs
docker compose exec application bash # Shell into container

# Maintenance
composer outdated                    # Check outdated PHP packages
npm outdated                         # Check outdated NPM packages
composer update                      # Update PHP packages
npm update                           # Update NPM packages
```

---

> **Terakhir diupdate**: Agustus 2026
> **Dibuat oleh**: AI Agent untuk handoff ke AI Agent berikutnya
