# Rencana Teknis Tahap 5: Penyempurnaan Pengalaman Pelanggan Web Self-Ordering Meja

Dokumen ini merinci rancangan teknis untuk menyempurnakan aplikasi pemesanan mandiri tamu meja (*Web Self-Ordering* di browser HP), mencakup fitur pesanan tambahan (*Round 2 Order*) yang otomatis digabung ke tagihan kasir, estimasi waktu penyiapan dapur, badge menu favorit/pedas, serta pencarian menu cerdas.

---

## 1. Latar Belakang & Kebutuhan Tamu di Meja

1. **Kendala Operasional Saat Ini:**
   - **Pesanan Tambahan (Round 2 / Add-on Items):** Tamu yang sudah memesan sering kali ingin menambah minuman, nasi putih, atau camilan 15 menit kemudian. Di sistem saat ini, pesanan baru akan membuat tab terpisah di kasir sehingga membingungkan staf saat mencetak tagihan akhir.
   - **Ketiadaan Estimasi Waktu (Cooking Wait Time):** Tamu tidak mengetahui berapa lama hidangannya disiapkan oleh koki, sehingga sering memanggil pelayan hanya untuk bertanya "makanannya sudah jadi atau belum?".
   - **Katalog Menu Statis:** Belum ada fitur pencarian cepat (*Search Bar*), belum ada penanda tingkat kepedasan (🌶️), dan belum ada badge menu rekomendasi koki (*Chef's Pick*).
   - **Opsi Catatan Masih Bebas:** Tamu harus mengetik catatan secara manual di keyboard HP. Banyak tamu malas mengetik sehingga sering salah paham saat makanan disajikan.

2. **Hasil yang Ingin Dicapai:**
   - Fitur **"Pesan Tambahan (Round 2)"**: Tamu yang mejanya sudah memiliki tagihan terbuka dapat langsung menambah menu baru tanpa perlu konfirmasi ulang data diri, dan pesanan otomatis di-append ke nota meja yang sama di POS kasir.
   - Indikator **Estimasi Waktu Dapur Dinamis**: Menampilkan hitung mundur waktu penyajian (misal: *⏱️ Estimasi Siap: 12-15 menit*).
   - Penambahan **Chips Catatan Cepat (Quick Notes)**: Tombol sekali klik seperti `[Pedas Sedang]`, `[Tidak Pedas]`, `[Es Sedikit]`, `[Kurang Manis]`, `[Bungkus Terpisah]`.
   - Visual Menu Menarik: Badge `⭐ Terlaris`, `🌶️ Pedas`, `👑 Rekomendasi Koki`, serta kotak pencarian menu instan.

---

## 2. Arsitektur Komponen & Aliran Data

```mermaid
graph TD
    subgraph "Web Pelanggan di HP (web_order)"
        GUEST["Tamu di Meja Scan QR"] --> MENU["Katalog Menu (Search & Badges)"]
        MENU --> ITEM["Detail Item + Quick Notes Chips"]
        ITEM --> CART["Keranjang Belanja Meja"]
        CART --> CHK["Checkout Pesanan Awal (Round 1)"]
        CHK --> TRK["Modal Pelacak Pesanan (Estimasi Waktu Dapur)"]
        TRK -->|Tamu Ingin Nambah Menu| ADD["Tombol: + Tambah Pesanan (Round 2)"]
        ADD --> CART2["Keranjang Pesanan Tambahan"]
        CART2 --> CHK2["Checkout Tambahan (Terkait ke Order ID Induk)"]
    end

    subgraph "Sistem Kasir Flutter"
        CHK -->|Firestore: table_orders (New)| POS["Open Tabs Kasir (Tab Meja Dibuat)"]
        CHK2 -->|Firestore: table_orders (Append)| POS2["Open Tabs Kasir (Item Digabung ke Meja Sama)"]
        POS2 --> KOT["Cetak Tiket KOT Dapur Baru: [ORDER TAMBAHAN]"]
    end
```

---

## 3. Rincian Berkas yang Dibuat / Diperbarui

### 1. [`web_order/index.html`](file:///c:/Project/mini-resto-pos/web_order/index.html) **[MODIFIKASI]**
- **Bilah Pencarian Menu (*Search Bar*):**
  - Input pencarian di bawah kategori menu dengan ikon kaca pembesar dan tombol reset instan.
- **Tombol Pesan Tambahan di Pelacak Pesanan:**
  - Menambahkan tombol sekunder: `"+ Pesan Menu Tambahan (Round 2)"` pada modal pelacak pesanan yang aktif.
- **Komponen Estimasi Waktu Dapur:**
  - Baris informasi estimasi waktu dengan animasi jam pasir dan progress bar dinamis.

### 2. [`web_order/app.js`](file:///c:/Project/mini-resto-pos/web_order/app.js) **[MODIFIKASI]**
- **Logika Pesanan Tambahan (*Round 2 Ordering*):**
  - Menyimpan `activeOrderId` dan `tableNumber` di `localStorage` HP tamu.
  - Saat tamu mengklik "+ Pesan Menu Tambahan", keranjang belanja dibuka kembali dalam mode *"Add-on Order"*.
  - Saat checkout dikonfirmasi, kirim muatan data dengan flag:
    ```javascript
    const payload = {
      parentOrderId: existingOrderId,
      isAdditionalOrder: true,
      roundNumber: 2,
      tableNumber: currentTable,
      customerName: currentCustomerName,
      items: newItems,
      totalAmount: additionalAmount,
      status: 'pending',
      timestamp: Date.now()
    };
    ```
- **Filter Pencarian Menu Real-time:**
  - Menyaring daftar kartu menu secara instan berdasarkan kecocokan nama dan deskripsi saat tamu mengetik di kolom pencarian.
- **Render Badge Kustom pada Kartu Menu:**
  - Deteksi properti `isSpicy`, `isBestSeller`, `isRecommended` dan tampilkan badge visual di sudut foto menu.
- **Modal Pemilihan Item dengan Quick Notes:**
  - Menampilkan pilihan chips catatan cepat siap klik sebelum menambahkan item ke keranjang belanja.

### 3. [`web_order/style.css`](file:///c:/Project/mini-resto-pos/web_order/style.css) **[MODIFIKASI]**
- Styling badge modern dengan efek kaca (*glassmorphism*):
  - Badge Pedas: Aksen merah oranye dengan ikon cabe.
  - Badge Best Seller: Aksen emas bercahaya (*gold glow*).
  - Badge Rekomendasi: Aksen ungu violet elegan.
- Animasi timer estimasi dapur (pulsing badge & timeline step bergelombang).
- Desain chips catatan cepat (*quick notes chips*) yang nyaman ditekan dengan jempol di layar ponsel.

### 4. [`lib/providers/online_order_provider.dart`](file:///c:/Project/mini-resto-pos/lib/providers/online_order_provider.dart) & [`lib/views/screens/open_tabs_screen.dart`](file:///c:/Project/mini-resto-pos/lib/views/screens/open_tabs_screen.dart) **[MODIFIKASI]**
- Deteksi `isAdditionalOrder == true`:
  - Kasir menerima notifikasi khusus: *"Pesanan Tambahan dari Meja 03!"*.
  - Saat kasir menekan tombol "Terima", item tambahan otomatis disisipkan ke dalam pesanan meja yang sedang berjalan, bukan membuka meja baru.
  - Tiket dapur (KOT) yang dicetak mencantumkan header: `*** PESANAN TAMBAHAN (ROUND 2) ***`.

---

## 4. Desain Tampilan UI Web Pelanggan

### A. Tampilan Kartu Menu dengan Badge & Quick Chips
```text
+---------------------------------------------------+
|  [FOTO MENU]                [⭐ BEST SELLER]       |
|                             [🌶️ PEDAS]            |
|  Nasi Goreng Spesial Resto                        |
|  Nasi goreng gurih dengan telur, sosis & ayam...  |
|  Rp 28.000                                        |
|                                                   |
|  Catatan Cepat:                                   |
|  [ Pedas Sedang ]  [ Telur 1/2 Matang ]  [ No Bwg]|
|                                                   |
|                          [ + Tambah ke Pesanan ]  |
+---------------------------------------------------+
```

### B. Tampilan Pelacak Pesanan dengan Estimasi & Round 2
```text
+---------------------------------------------------+
|               STATUS PESANAN MEJA 03              |
+---------------------------------------------------+
|  Status: [ SEDANG DIMASAK DI DAPUR ]              |
|  ⏱️ Estimasi Siap: 12 - 15 Menit                 |
|  [==========================>          ] 65%      |
|                                                   |
|  Rincian Pesanan (Round 1):                       |
|  - 1x Nasi Goreng Spesial Resto                   |
|  - 1x Es Teh Manis Jumbo                          |
|                                                   |
|  Ada yang kurang? Mau nambah camilan / minum?     |
|  +---------------------------------------------+  |
|  |    + PESAN MENU TAMBAHAN (ROUND 2)          |  |
|  +---------------------------------------------+  |
+---------------------------------------------------+
```

---

## 5. Rencana Pengujian & Verifikasi (Verification Plan)

### A. Pengujian Alur Pesanan Tambahan:
1. **Pemesanan Awal (Round 1):**
   - Buka `http://localhost:8080/?table=03` di browser.
   - Pesan "1x Nasi Goreng", masukkan nama "Budi", lalu checkout.
   - Verifikasi status meja 03 di kasir terisi dan tiket KOT pertama keluar.
2. **Pemesanan Tambahan (Round 2):**
   - Di layar HP tamu, klik tombol "+ Pesan Menu Tambahan (Round 2)".
   - Pilih "1x Es Teh Manis Jumbo", lalu checkout.
   - Di aplikasi kasir, pastikan pop-up menampilkan: *"Pesanan Tambahan Meja 03 (Es Teh Manis Jumbo)"*.
   - Saat diterima kasir, pastikan total bill Meja 03 berubah menjadi akumulasi kedua pesanan (Nasi Goreng + Es Teh) tanpa membuat tab baru.
   - Tiket KOT dapur kedua hanya mencetak item tambahan (Es Teh Manis).

### B. Pengujian Pencarian & Quick Chips:
1. **Pencarian Menu:**
   - Ketik "ayam" di search bar -> Menu selain olahan ayam harus tersembunyi seketika.
   - Hapus teks pencarian -> Semua menu kembali muncul.
2. **Quick Notes Chips:**
   - Klik chip `[Pedas Sedang]` -> Input catatan item otomatis terisi teks "Pedas Sedang".
   - Klik chip lain `[Tanpa Bawang]` -> Catatan menjadi "Pedas Sedang, Tanpa Bawang".
