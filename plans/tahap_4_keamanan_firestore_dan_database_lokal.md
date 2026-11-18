# Rencana Teknis Tahap 4: Penguatan Keamanan Firestore & Database Lokal Terstruktur (SQLite)

Dokumen ini merinci spesifikasi teknis untuk mengamankan aturan akses Cloud Firestore (*Security Rules*) guna mencegah manipulasi katalog menu, harga, dan pesanan meja dari pihak luar, serta migrasi penyimpanan lokal kasir dari `SharedPreferences` (JSON tunggal) ke **SQLite (`sqflite`)** terstruktur dengan pembersihan otomatis data lama.

*(Catatan: Fitur Backup & Restore ditangguhkan sementara untuk memfokuskan stabilitas database lokal dan keamanan Firestore).*

---

## 1. Latar Belakang & Kebutuhan Arsitektur

1. **Masalah Keamanan Cloud Firestore Saat Ini:**
   - Aturan keamanan Firestore saat ini berstatus terbuka penuh (`allow read, write: if true;`).
   - Resiko: Pengguna web jahat di meja dapat menghapus koleksi pesanan kasir, mengubah harga menu sesuka hati, atau memanipulasi status pembayaran.
   - Kebutuhan: Aturan keamanan ketat yang memvalidasi skema pesanan tamu (`tableNo`, status `pending`, `totalAmount > 0`), membatasi mutasi menu dan status pesanan hanya untuk kasir terautentikasi (menggunakan Firebase REST ID Token).

2. **Kendala Database Lokal Saat Ini:**
   - Seluruh menu, transaksi historis, pesanan, shift, dan kasbon disimpan menggunakan `SharedPreferences` dalam bentuk string JSON raksasa tunggal.
   - Resiko Operasional:
     - Semakin lama restoran beroperasi, ribuan data transaksi akan membebani memori RAM setiap kali aplikasi dibuka.
     - Query pencarian atau filter tanggal lambat karena harus mem-parse seluruh array JSON di memori.
     - Rentan korupsi data (*data corruption*) jika aplikasi kasir tertutup mendadak saat proses penulisan string JSON panjang.

3. **Hasil yang Ingin Dicapai:**
   - Aturan Firestore Security Rules yang ketat dan aman dengan validasi schema dokumen (`tableNo`, `totalAmount`, dsb).
   - Database lokal terstruktur menggunakan SQLite (`sqflite`) dengan indexing cepat pada timestamp, invoice/id, dan status.
   - Mekanisme *Auto-Migration* transparan (memindahkan data SharedPreferences lama ke tabel SQLite secara transaksional).
   - **Pembersihan Bersih (Clean Up):** Menghapus data JSON lama dari `SharedPreferences` seketika setelah migrasi ke SQLite berhasil guna membebaskan ruang penyimpanan dan memori perangkat kasir.

---

## 2. Arsitektur Keamanan & Database

```mermaid
graph TD
    subgraph "Perlindungan Cloud Firestore"
        GUEST["Web Order Meja (Tamu)"] -->|Hanya boleh Read Menu & Create Order Baru (tableNo, pending)| SEC["Firestore Security Rules"]
        CASHIER["Aplikasi Kasir Flutter (Admin)"] -->|Auth REST ID Token: Full CRUD, Ubah Status, Edit Menu| SEC
        SEC --> DB[("Cloud Firestore")]
    end

    subgraph "Migrasi Database Lokal Kasir"
        SP["SharedPreferences Lama (JSON String)"] -->|One-time Transactional Auto Migration| MIG["DatabaseMigrationService"]
        MIG --> SQL[("SQLite Database: mini_resto.db")]
        MIG -->|Setelah Berhasil: Hapus Kunci JSON Lama| CLEAN["Pembersihan Memori SharedPreferences"]
        SQL --> T_PROD["Tabel: products & categories"]
        SQL --> T_ORD["Tabel: orders & order_items"]
        SQL --> T_TRX["Tabel: transactions"]
        SQL --> T_SHIFT["Tabel: shifts & cash_movements"]
        SQL --> T_CUST["Tabel: customers"]
    end
```

---

## 3. Rincian Penguatan Firestore Security Rules

Berkas target: [`firestore.rules`](file:///c:/Project/mini-resto-pos/firestore.rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 1. Koleksi Menu Restoran (resto_menu)
    match /resto_menu/{menuId} {
      // Tamu publik hanya boleh membaca katalog menu
      allow read: if true;
      // Penulisan menu hanya oleh aplikasi kasir terautentikasi
      allow write: if request.auth != null;
    }

    // 2. Koleksi Konfigurasi Resto (resto_config dan resto_settings)
    match /resto_config/{configId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /resto_settings/{settingId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // 3. Koleksi Pesanan Meja (table_orders)
    match /table_orders/{orderId} {
      // Pelanggan dan kasir boleh membaca pesanan
      allow read: if true;

      // Tamu web meja hanya boleh membuat pesanan baru (create) dengan validasi ketat:
      allow create: if request.resource.data.status == 'pending'
                    && request.resource.data.tableNo is string
                    && request.resource.data.customerName is string
                    && request.resource.data.totalAmount > 0
                    && request.resource.data.items is list;

      // Perubahan status pesanan dan penghapusan hanya boleh dilakukan oleh Kasir
      allow update, delete: if request.auth != null;
    }

    // 4. Koleksi Panggilan Pelayan (table_calls)
    match /table_calls/{callId} {
      allow read: if true;
      allow create: if request.resource.data.status == 'pending'
                    && request.resource.data.tableNo is string;
      allow update, delete: if request.auth != null;
    }
  }
}
```

---

## 4. Skema Database SQLite Lokal (`mini_resto.db`)

Berkas target: [`lib/services/database_helper.dart`](file:///c:/Project/mini-resto-pos/lib/services/database_helper.dart) **[BARU]**

### Struktur Tabel Selaras Model Kode:

1. **`products`**:
   - `id` TEXT PRIMARY KEY
   - `name` TEXT NOT NULL
   - `category_id` TEXT NOT NULL
   - `buy_price` INTEGER NOT NULL
   - `sell_price` INTEGER NOT NULL
   - `stock` INTEGER NOT NULL
   - `unit` TEXT NOT NULL
   - `track_stock` INTEGER NOT NULL DEFAULT 1
   - `image_url` TEXT
   - `description` TEXT
   - `created_at` INTEGER NOT NULL

2. **`categories`**:
   - `id` TEXT PRIMARY KEY
   - `name` TEXT NOT NULL
   - `sort_order` INTEGER NOT NULL
   - `icon_name` TEXT

3. **`orders` & `order_items`**:
   - `orders`: `id` TEXT PRIMARY KEY, `shift_id` TEXT NOT NULL, `table_no` TEXT, `customer_name` TEXT NOT NULL, `status` TEXT NOT NULL, `created_at` INTEGER NOT NULL, `completed_at` INTEGER
   - `order_items`: `id` TEXT PRIMARY KEY, `order_id` TEXT NOT NULL, `product_id` TEXT NOT NULL, `name` TEXT NOT NULL, `price` INTEGER NOT NULL, `qty` INTEGER NOT NULL, `notes` TEXT

4. **`transactions`**:
   - `id` TEXT PRIMARY KEY
   - `order_id` TEXT NOT NULL
   - `shift_id` TEXT NOT NULL
   - `cashier_id` TEXT NOT NULL
   - `cashier_name` TEXT NOT NULL
   - `payment_method` TEXT NOT NULL
   - `total_amount` INTEGER NOT NULL
   - `amount_paid` INTEGER NOT NULL
   - `change` INTEGER NOT NULL
   - `customer_id` TEXT
   - `customer_name` TEXT
   - `timestamp` INTEGER NOT NULL

5. **`shifts` & `cash_movements`**:
   - `shifts`: `id` TEXT PRIMARY KEY, `cashier_id` TEXT, `cashier_name` TEXT, `start_time` INTEGER, `end_time` INTEGER, `starting_cash` INTEGER, `total_cash_sales` INTEGER, `total_qris_sales` INTEGER, `total_debt_sales` INTEGER, `total_debt_repaid_cash` INTEGER, `total_cash_in` INTEGER, `total_cash_out` INTEGER, `expected_cash_end` INTEGER, `actual_cash_end` INTEGER, `cash_difference` INTEGER, `status` TEXT, `notes` TEXT
   - `cash_movements`: `id` TEXT PRIMARY KEY, `shift_id` TEXT, `type` TEXT, `amount` INTEGER, `reason` TEXT, `timestamp` INTEGER

6. **`customers`**:
   - `id` TEXT PRIMARY KEY
   - `name` TEXT NOT NULL
   - `phone_wa` TEXT NOT NULL
   - `total_debt` INTEGER NOT NULL DEFAULT 0
   - `debt_limit` INTEGER NOT NULL DEFAULT 100000
   - `created_at` INTEGER NOT NULL

---

## 5. Rincian Berkas yang Dibuat / Diperbarui

1. [`pubspec.yaml`](file:///c:/Project/mini-resto-pos/pubspec.yaml) **[MODIFIKASI]**:
   - Menambahkan: `sqflite`, `path`, `path_provider`, dan `sqflite_common_ffi` (dev-dep).
2. [`firestore.rules`](file:///c:/Project/mini-resto-pos/firestore.rules) **[MODIFIKASI]**:
   - Menetapkan aturan Firestore sesuai spesifikasi Bagian 3.
3. [`lib/services/cloud_sync_service.dart`](file:///c:/Project/mini-resto-pos/lib/services/cloud_sync_service.dart) **[MODIFIKASI]**:
   - Menambahkan autentikasi Firebase REST API anonymous token sehingga panggilan kasir menyertakan header `Authorization: Bearer <idToken>`.
4. [`lib/services/database_helper.dart`](file:///c:/Project/mini-resto-pos/lib/services/database_helper.dart) **[BARU]**:
   - Singleton koneksi SQLite, skema tabel, indexing, dan helper query.
5. [`lib/services/database_migration_service.dart`](file:///c:/Project/mini-resto-pos/lib/services/database_migration_service.dart) **[BARU]**:
   - Memigrasikan data SharedPreferences lama ke SQLite secara atomik, lalu membersihkan/menghapus kunci-kunci JSON lama dari SharedPreferences.
6. [`lib/services/storage_service.dart`](file:///c:/Project/mini-resto-pos/lib/services/storage_service.dart) **[MODIFIKASI]**:
   - Mengalihkan penyimpanan data transaksional ke SQLite dengan mempertahankan kontrak interface bagi provider.
7. [`test/database_test.dart`](file:///c:/Project/mini-resto-pos/test/database_test.dart) **[BARU]**:
   - Unit test integritas SQLite dan pengujian pembersihan data migrasi.

---

## 6. Rencana Pengujian & Verifikasi

1. **Uji Aturan Keamanan Firestore:**
   - Web tamu mencoba membuat pesanan valid (`tableNo`, `pending`) -> Sukses diterima.
   - Tamu mencoba memanipulasi status menjadi `completed` atau mengubah harga -> Firestore menolak dengan error `PERMISSION_DENIED`.
2. **Uji Migrasi & Pembersihan SharedPreferences:**
   - Eksekusi migrasi -> Seluruh transaksi, pesanan, dan menu berpindah utuh ke SQLite.
   - Kunci JSON lama di SharedPreferences terhapus bersih dan ruang memori bebas.
3. **Uji Kecepatan Query SQLite:**
   - Pengambilan riwayat transaksi dan filter analitik berjalan cepat tanpa overhead parsing JSON string raksasa.
