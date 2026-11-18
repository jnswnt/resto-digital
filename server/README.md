# 🚀 Panduan Deployment Backend Mini Resto POS di aaPanel

Panduan langkah-demi-langkah memasang Backend API & WebSocket Hub di **aaPanel Tencent Cloud VPS** untuk domain `resto-api.ipankhub.web.id`.

---

## 📋 Prasyarat di aaPanel

1. **Node.js**: Versi `v20.20.2` (sudah terpasang di VPS Anda).
2. **Package Manager**: `yarn` atau `npm` (sudah terdeteksi otomatis).
3. **DNS Subdomain**: Pastikan subdomain `resto-api.ipankhub.web.id` sudah diarahkan (A-Record) ke IP VPS `43.173.53.227`.

---

## 🛠️ Langkah 1: Siapkan Folder Proyek di Server

Anda dapat mengunggah folder `server` ini ke server menggunakan salah satu cara berikut:

### Cara A (Menggunakan Git / Paling Cepat):
1. Masuk ke terminal VPS via SSH atau via menu **Terminal** di aaPanel.
2. Jalankan perintah:
```bash
cd /www/wwwroot
git clone https://github.com/jnswnt/resto-digital.git resto-repo
cp -r resto-repo/server /www/wwwroot/resto-api
cd /www/wwwroot/resto-api
yarn install
```

### Cara B (Menggunakan Menu Files di aaPanel):
1. Di aaPanel, buka menu **Files** (sidebar kiri) ➔ Buka direktori `/www/wwwroot/`.
2. Klik tombol **New Dir** ➔ Beri nama: `resto-api`.
3. Masuk ke dalam folder `/www/wwwroot/resto-api/`, lalu upload file:
   - `package.json`
   - `server.js`
   - `.env`
4. Buka terminal di dalam folder tersebut dan jalankan: `yarn install`.

---

## 🌐 Langkah 2: Tambahkan di Menu "Node.js Project" aaPanel

1. Buka menu **Website** di sidebar aaPanel ➔ Klik tab **Node.js Project**.
2. Klik tombol hijau **Add Project**.
3. Isi kolom form persis seperti berikut:
   * **Path**: `/www/wwwroot/resto-api`
   * **Project Name**: `resto-api`
   * **Run User**: `www`
   * **Node.js runtime**: `v20.20.2`
   * **Pkg Manager**: `yarn 1.22.22` *(biarkan toggle Install dependencies aktif)*
   * **Start command**: Pilih `From package.json` ➔ pilih `start` (`node server.js`)
   * **Project Port**: `3001`
4. Klik tombol **Confirm**.
5. Status proyek akan berubah menjadi hijau: **Running ▶**.

---

## 🔒 Langkah 3: Sambungkan Domain & Aktifkan HTTPS (SSL)

1. Pada daftar Node.js Project, klik nama proyek **`resto-api`** (atau klik tombol **Modify** / link di bawah kolom domain).
2. Pilih tab **Domain Manager**:
   * Masukkan domain: `resto-api.ipankhub.web.id`
   * Klik **Add**.
3. Pilih tab **SSL**:
   * Pilih tab **Let's Encrypt**.
   * Centang domain `resto-api.ipankhub.web.id`.
   * Klik **Apply**.
   * Aktifkan toggle **Force HTTPS**.

---

## 🧪 Langkah 4: Pengujian Server

Buka browser Anda dan akses:
* `https://resto-api.ipankhub.web.id/`
  * Akan menampilkan respon JSON:
    ```json
    {
      "app": "Mini Resto POS - Backend API & Realtime Hub",
      "version": "1.0.0",
      "status": "ONLINE"
    }
    ```
* `https://resto-api.ipankhub.web.id/api/health`
  * Menampilkan uptime, memori server, dan koneksi aktif.

---

## 📡 Daftar Endpoint API Utama

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/` | Root info & status server |
| `GET` | `/api/health` | Health check & konsumsi RAM server |
| `GET` | `/api/catalog/:restoId` | Tamu mengambil menu makanan |
| `POST` | `/api/catalog/:restoId/sync` | Kasir mengunggah menu & stok terkini |
| `POST` | `/api/orders` | Tamu mengirim pesanan dari scan QR meja |
| `GET` | `/api/orders/:restoId` | Kasir/KDS mengambil daftar pesanan aktif |
| `PATCH` | `/api/orders/:restoId/:orderId/status` | Kasir/KDS update status pesanan |
| `POST` | `/api/waiter-call` | Tamu panggil pelayan dari meja |

---

## 🔄 Event WebSocket Realtime (Socket.IO)

* **`join_resto`**: Klien bergabung ke channel restoran (contoh: `{ restoId: "resto-01", role: "pos" }`).
* **`new_order`**: Diterima kasir & KDS secara instan saat tamu membuat pesanan di meja.
* **`order_status_updated`**: Diterima tamu saat koki memasak / pesanan selesai.
* **`waiter_call`**: Diterima kasir saat tamu menekan tombol panggil pelayan.
