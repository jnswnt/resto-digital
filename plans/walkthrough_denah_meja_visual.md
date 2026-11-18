# Walkthrough: Implementasi Denah Meja Visual (Konsep 1) Multi-Resolusi

Dokumen ini mendokumentasikan implementasi pembaharuan flow UI pada **Halaman Tab Meja Kasir** (`open_tabs_screen.dart`), mengubah format tab terpisah menjadi **Denah Meja Visual Terpadu (*Visual Floor Grid*)** yang dioptimalkan secara khusus untuk **HP Android Portrait** sekaligus **responsif terhadap berbagai resolusi layar** (Tablet & Desktop).

---

## 1. Perubahan Desain & Alur Kerja Kasir

```
                       DENAH MEJA VISUAL (RESPONSIF)
+-------------------------------------------------------------------------+
| [Judul & Okupansi]          [Atur Meja]   [Cetak QR]   [Sync Cloud]     |
+-------------------------------------------------------------------------+
| Filter: [ Semua (12) ]  [ 🟢 Kosong (7) ]  [ 🔴 Terisi (3) ]  [ 🟡 Baru (2) ]  |
+-------------------------------------------------------------------------+
|                                                                         |
| HP Portrait (< 500px): Grid 2-Kolom | Tablet/Desktop: Grid 3 - 6 Kolom  |
|                                                                         |
|   +-------------------+                     +-------------------+       |
|   | MEJA 01    🟢      |                     | MEJA 02    🟡      |       |
|   | Meja Kosong       |                     | Order Web Masuk   |       |
|   | Kapasitas: 4 org  |                     | Sdr Rian • 3 Item |       |
|   | [+ Buka Meja]     |                     | [⚡ Terima Order] |       |
|   +-------------------+                     +-------------------+       |
|                                                                         |
|   +-------------------+                     +-------------------+       |
|   | MEJA 03    🔴      |                     | MEJA 04    🔔      |       |
|   | Bpk Budi (⏱️ 25m)  |                     | Panggil Pelayan:  |       |
|   | Rp 120.000        |                     | "Minta Sendok"    |       |
|   | [Detail/Bayar ➜]  |                     | [Lihat Panggilan] |       |
|   +-------------------+                     +-------------------+       |
+-------------------------------------------------------------------------+
```

### Mengapa Flow Baru Ini Jauh Lebih Unggul:
1. **Single View (Semua Meja Terlihat Seketika)**:
   - Kasir tidak lagi mengalami kebingungan bolak-balik antara Tab Kasir vs Tab Online.
   - Sekali pandang kasir langsung tahu: berapa meja kosong untuk tamu baru, meja mana yang baru pesan via web, dan meja mana yang minta bantuan pelayan.
2. **Optimal untuk HP Android Portrait**:
   - Denah tersusun dalam **Grid 2-Kolom** yang proporsional dan nyaman dioperasikan satu tangan dengan jempol.
   - Mengetuk kartu meja akan membuka **Modal Bottom Sheet** yang muncul dari bawah layar dengan kontrol yang ramah sentuhan.
3. **Dukungan Multi-Resolusi Adaptif**:
   - `width < 500px` (HP Android Portrait): Grid 2 kolom, Action Sheet berupa Modal Bottom Sheet di bawah.
   - `width 500 - 768px` (HP Landscape / Tablet Kecil): Grid 3 kolom.
   - `width 768 - 1100px` (Tablet Landscape): Grid 4 kolom, Action Sheet berupa Centered Dialog dengan batas lebar maksimal 480px.
   - `width >= 1100px` (Desktop): Grid 5 - 6 kolom.
4. **Alur Cepat Satu Sentuhan (*One-Touch Action*)**:
   - **Meja Kosong**: Ketuk $\rightarrow$ langsung buka transaksi kasir dengan nomor meja terpasang.
   - **Meja Terisi**: Ketuk $\rightarrow$ rincian tagihan, tombol cepat Cetak KOT dapur, tombol Pelunasan di kasir, dan opsi Pindah Meja.
   - **Order Web Masuk**: Ketuk $\rightarrow$ rincian menu tamu, tombol Terima & Cetak Dapur, Tolak, dan Verifikasi QRIS.
   - **Panggilan Pelayan**: Muncul ikon lonceng berkedip di kartu meja $\rightarrow$ satu ketukan untuk menyelesaikan panggilan.
5. **Dukungan Meja Bawa Pulang (Takeaway)**:
   - Pesanan bungkus tanpa nomor meja otomatis dialihkan ke chip filter `🥡 Takeaway` agar tidak mengotori denah meja fisik.

---

## 2. Berkas yang Dibuat dan Diperbarui

| Berkas | Peran & Perubahan Utama |
|---|---|
| [`lib/models/restaurant_table.dart`](file:///c:/Project/mini-resto-pos/lib/models/restaurant_table.dart) | **[BARU]** Model data `RestaurantTable`, enum `TableStatus`, helper normalisasi alfanumerik `isMatch()`, serta generator meja bawaan `getDefaultTables()`. |
| [`lib/views/widgets/table_floor_card.dart`](file:///c:/Project/mini-resto-pos/lib/views/widgets/table_floor_card.dart) | **[BARU]** Widget kartu meja visual dengan palet warna status cerdas (🟢 Kosong, 🔴 Terisi, 🟡 Order Baru, 🔔 Panggil Pelayan). |
| [`lib/views/widgets/table_action_sheet.dart`](file:///c:/Project/mini-resto-pos/lib/views/widgets/table_action_sheet.dart) | **[BARU]** Modal aksi meja adaptif (Modal Bottom Sheet di HP Portrait, Centered Dialog di Tablet/Desktop) untuk eksekusi transaksi cepat. |
| [`lib/views/screens/open_tabs_screen.dart`](file:///c:/Project/mini-resto-pos/lib/views/screens/open_tabs_screen.dart) | **[DIMODIFIKASI]** Merombak total tampilan menjadi Denah Meja Visual dengan `LayoutBuilder` multi-resolusi, chip filter status, banner panggilan pelayan, dan dialog pengaturan jumlah meja. |
| [`lib/providers/pos_provider.dart`](file:///c:/Project/mini-resto-pos/lib/providers/pos_provider.dart) | **[DIMODIFIKASI]** Menambahkan fungsi `moveTable(currentTable, newTable)` untuk mendukung perpindahan meja tamu aktif. |

---

## 3. Hasil Pengujian & Verifikasi

- **Pemeriksaan Sintaks & Analisis Statis (`flutter analyze`)**:
  - Dijalankan pada seluruh proyek `mini-resto-pos`.
  - Hasil: Seluruh kode produksi di direktori `lib/` **100% bebas dari error maupun warning**.
- **Pengujian Responsivitas Multi-Resolusi**:
  - Diuji dengan simulasi lebar layar HP Portrait (< 500dp), Tablet (600 - 800dp), dan Desktop (> 1000dp).
  - Rasio kartu meja dan ukuran teks berskala rapi tanpa ada komponen yang terpotong (*no overflow*).
