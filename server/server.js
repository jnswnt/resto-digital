/**
 * ============================================================================
 * Mini Resto POS - Backend API & Realtime WebSocket Hub (Multi-Tenant SaaS)
 * ============================================================================
 * 
 * Deskripsi:
 * Backend proxy terpusat untuk menghubungkan Web Pemesanan Meja Tamu (Self-Ordering QR),
 * Tablet Kasir POS, dan Kitchen Display System (KDS) Dapur secara real-time.
 * 
 * Fitur Utama:
 * 1. Multi-Tenant Room Isolation: Data dan event socket terisolasi per `restoId`.
 * 2. REST API Katalog Menu: Sinkronisasi produk & stok dari kasir ke web tamu.
 * 3. REST API Pemesanan QR: Validasi dan penyimpanan pesanan meja tamu.
 * 4. Realtime Broadcast: Notifikasi pesanan instan & pemanggilan pelayan ke kasir/dapur.
 * 5. Standalone Data Storage: Penyimpanan JSON terisolasi per restoran tanpa dependensi DB eksternal rumit.
 */

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Inisialisasi Aplikasi Express & Server HTTP
const app = express();
const server = http.createServer(app);

// Konfigurasi Environment
const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'production';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

// Inisialisasi Socket.IO dengan konfigurasi CORS
const io = new Server(server, {
  cors: {
    origin: CORS_ORIGIN,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
    credentials: true,
  },
  pingTimeout: 30000,
  pingInterval: 10000,
});

// Middleware Global
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging sederhana untuk monitoring request
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (req.path !== '/api/health') {
      console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${res.statusCode} - ${duration}ms`);
    }
  });
  next();
});

// ============================================================================
// SISTEM PENYIMPANAN DATA MULTI-TENANT (File-Based JSON Storage)
// ============================================================================
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

/**
 * Mendapatkan path file data untuk restoran tertentu.
 * Setiap restoran memiliki file database JSON terisolasi.
 * 
 * @param {string} restoId - ID unik restoran
 * @returns {string} Path absolut file JSON restoran
 */
function getRestoFilePath(restoId) {
  const sanitizedId = String(restoId || 'default').replace(/[^a-zA-Z0-9_-]/g, '_');
  return path.join(DATA_DIR, `resto_${sanitizedId}.json`);
}

/**
 * Membaca data restoran dari file JSON.
 * Jika belum ada, mengembalikan struktur data default.
 * 
 * @param {string} restoId - ID unik restoran
 * @returns {object} Data restoran (catalog, orders, settings)
 */
function readRestoData(restoId) {
  const filePath = getRestoFilePath(restoId);
  if (!fs.existsSync(filePath)) {
    return {
      restoId: restoId,
      name: 'Restoran ' + restoId,
      updatedAt: new Date().toISOString(),
      catalog: { categories: [], products: [] },
      orders: [],
      waiterCalls: [],
      staff: [],
    };
  }
  try {
    const raw = fs.readFileSync(filePath, 'utf-8');
    const data = JSON.parse(raw);
    if (!data.staff) data.staff = [];
    return data;
  } catch (error) {
    console.error(`Gagal membaca data resto [${restoId}]:`, error);
    return { restoId, catalog: { categories: [], products: [] }, orders: [], waiterCalls: [], staff: [] };
  }
}

/**
 * Menyimpan data restoran ke file JSON secara atomik.
 * 
 * @param {string} restoId - ID unik restoran
 * @param {object} data - Data lengkap restoran
 */
function saveRestoData(restoId, data) {
  const filePath = getRestoFilePath(restoId);
  data.updatedAt = new Date().toISOString();
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
}

// ============================================================================
// REALTIME WEBSOCKET (SOCKET.IO) MULTI-TENANT ROOMS
// ============================================================================
io.on('connection', (socket) => {
  console.log(`[Socket] Klien terhubung: ${socket.id}`);

  /**
   * Event: join_resto
   * Kasir, KDS Dapur, atau Tamu bergabung ke room restoran tertentu.
   */
  socket.on('join_resto', (data) => {
    const restoId = data?.restoId || 'default';
    const role = data?.role || 'guest'; // 'pos', 'kds', 'guest'
    const roomName = `resto:${restoId}`;

    socket.join(roomName);
    socket.restoId = restoId;
    socket.role = role;

    console.log(`[Socket] ${socket.id} (${role}) bergabung ke room: ${roomName}`);
    socket.emit('joined_resto', {
      success: true,
      room: roomName,
      restoId: restoId,
      message: `Berhasil terhubung ke channel restoran ${restoId}`,
    });
  });

  /**
   * Event: leave_resto
   * Meninggalkan room restoran.
   */
  socket.on('leave_resto', (data) => {
    const restoId = data?.restoId || socket.restoId;
    if (restoId) {
      socket.leave(`resto:${restoId}`);
      console.log(`[Socket] ${socket.id} meninggalkan room resto:${restoId}`);
    }
  });

  socket.on('disconnect', () => {
    console.log(`[Socket] Klien terputus: ${socket.id}`);
  });
});

// ============================================================================
// ENDPOINT REST API
// ============================================================================

/**
 * GET /
 * Informasi root dan identitas server.
 */
app.get('/', (req, res) => {
  res.json({
    app: 'Mini Resto POS - Backend API & Realtime Hub',
    version: '1.0.0',
    status: 'ONLINE',
    author: 'Mini Resto SaaS Team',
    documentation: '/api/health',
  });
});

/**
 * GET /api/health
 * Pengecekan kondisi server, memori, dan statistik aktif.
 */
app.get('/api/health', (req, res) => {
  const memoryUsage = process.memoryUsage();
  res.json({
    status: 'OK',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    environment: NODE_ENV,
    activeRooms: io.sockets.adapter.rooms.size,
    memory: {
      rss: `${Math.round(memoryUsage.rss / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(memoryUsage.heapUsed / 1024 / 1024)} MB`,
    },
  });
});

/**
 * POST /api/catalog/:restoId/sync
 * Sinkronisasi katalog menu dan stok dari Tablet Kasir POS ke server.
 */
app.post('/api/catalog/:restoId/sync', (req, res) => {
  const { restoId } = req.params;
  const { categories, products, restoName } = req.body;

  if (!categories || !products) {
    return res.status(400).json({ error: 'Data categories dan products wajib disertakan.' });
  }

  const restoData = readRestoData(restoId);
  if (restoName) restoData.name = restoName;
  restoData.catalog = {
    categories: categories,
    products: products,
    syncedAt: new Date().toISOString(),
  };

  saveRestoData(restoId, restoData);

  // Broadcast pembaruan katalog ke tamu yang sedang melihat menu
  io.to(`resto:${restoId}`).emit('catalog_updated', {
    restoId: restoId,
    timestamp: new Date().toISOString(),
  });

  console.log(`[Catalog] Katalog menu berhasil disinkronkan untuk resto: ${restoId} (${products.length} produk)`);
  return res.json({
    success: true,
    message: 'Katalog berhasil disinkronkan.',
    productsCount: products.length,
    categoriesCount: categories.length,
    syncedAt: restoData.catalog.syncedAt,
  });
});

/**
 * GET /api/catalog/:restoId
 * Tamu mengambil katalog menu untuk tampilan Web QR Meja.
 */
app.get('/api/catalog/:restoId', (req, res) => {
  const { restoId } = req.params;
  const restoData = readRestoData(restoId);

  return res.json({
    restoId: restoData.restoId,
    restoName: restoData.name,
    categories: restoData.catalog.categories || [],
    products: restoData.catalog.products || [],
    updatedAt: restoData.updatedAt,
  });
});

/**
 * POST /api/orders
 * Tamu mengirimkan pesanan dari Web Self-Ordering QR Meja.
 */
app.post('/api/orders', (req, res) => {
  const {
    restoId,
    tableNo,
    customerName,
    items,
    notes,
    subtotal,
    taxAmount,
    serviceChargeAmount,
    discountAmount,
    totalPrice,
    paymentMethod,
  } = req.body;

  if (!restoId || !tableNo || !items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({
      error: 'Data pesanan tidak lengkap. restoId, tableNo, dan items wajib diisi.',
    });
  }

  const orderId = `ORD-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;
  const newOrder = {
    id: orderId,
    restoId: restoId,
    tableNo: String(tableNo),
    customerName: customerName || `Tamu Meja ${tableNo}`,
    items: items.map((item) => ({
      productId: item.productId || item.id,
      productName: item.productName || item.name,
      price: Number(item.price || 0),
      quantity: Number(item.quantity || 1),
      notes: item.notes || '',
    })),
    subtotal: Number(subtotal || 0),
    taxAmount: Number(taxAmount || 0),
    serviceChargeAmount: Number(serviceChargeAmount || 0),
    discountAmount: Number(discountAmount || 0),
    totalPrice: Number(totalPrice || 0),
    notes: notes || '',
    paymentMethod: paymentMethod || 'cashier', // 'cashier', 'qris_online'
    paymentStatus: paymentMethod === 'qris_online' ? 'PAID' : 'UNPAID',
    status: 'pending', // 'pending', 'cooking', 'ready', 'served', 'completed', 'cancelled'
    kitchenStatus: 'pending',
    createdAt: new Date().toISOString(),
  };

  // Simpan ke database JSON restoran
  const restoData = readRestoData(restoId);
  restoData.orders.unshift(newOrder);
  // Simpan maksimal 500 riwayat pesanan per resto agar file tetap ringan
  if (restoData.orders.length > 500) {
    restoData.orders = restoData.orders.slice(0, 500);
  }
  saveRestoData(restoId, restoData);

  // Broadcast realtime ke Tablet Kasir & KDS Dapur di room restoran tersebut
  io.to(`resto:${restoId}`).emit('new_order', newOrder);

  console.log(`[Order] Pesanan baru diterima: ${orderId} | Meja ${tableNo} | Resto: ${restoId} | Total: Rp ${newOrder.totalPrice}`);

  return res.status(201).json({
    success: true,
    message: 'Pesanan berhasil dibuat dan diteruskan ke kasir/dapur.',
    order: newOrder,
  });
});

/**
 * GET /api/orders/:restoId
 * Kasir atau KDS mengambil daftar pesanan aktif restoran.
 */
app.get('/api/orders/:restoId', (req, res) => {
  const { restoId } = req.params;
  const statusFilter = req.query.status; // misal: 'pending', 'cooking', 'active'
  const limit = Math.min(Number(req.query.limit) || 50, 100);

  const restoData = readRestoData(restoId);
  let orders = restoData.orders || [];

  if (statusFilter === 'active') {
    orders = orders.filter((o) => o.status !== 'completed' && o.status !== 'cancelled');
  } else if (statusFilter) {
    orders = orders.filter((o) => o.status === statusFilter);
  }

  return res.json({
    restoId: restoId,
    totalOrders: orders.length,
    orders: orders.slice(0, limit),
  });
});

/**
 * GET /api/orders/:restoId/:orderId
 * Tamu melacak status pesanan spesifik mereka secara berkala.
 */
app.get('/api/orders/:restoId/:orderId', (req, res) => {
  const { restoId, orderId } = req.params;
  const restoData = readRestoData(restoId);
  const order = (restoData.orders || []).find((o) => o.id === orderId);

  if (!order) {
    return res.status(404).json({ error: 'Pesanan tidak ditemukan.' });
  }

  return res.json({ success: true, order: order });
});

/**
 * PATCH /api/orders/:restoId/:orderId/status
 * Kasir atau KDS mengupdate status pesanan (misal: 'cooking', 'ready', 'served').
 */
app.patch('/api/orders/:restoId/:orderId/status', (req, res) => {
  const { restoId, orderId } = req.params;
  const { status, kitchenStatus } = req.body;

  const restoData = readRestoData(restoId);
  const orderIndex = (restoData.orders || []).findIndex((o) => o.id === orderId);

  if (orderIndex === -1) {
    return res.status(404).json({ error: 'Pesanan tidak ditemukan.' });
  }

  if (status) restoData.orders[orderIndex].status = status;
  if (kitchenStatus) restoData.orders[orderIndex].kitchenStatus = kitchenStatus;
  restoData.orders[orderIndex].updatedAt = new Date().toISOString();

  saveRestoData(restoId, restoData);

  const updatedOrder = restoData.orders[orderIndex];

  // Broadcast pembaruan status ke semua perangkat di resto (termasuk layar HP tamu)
  io.to(`resto:${restoId}`).emit('order_status_updated', {
    orderId: orderId,
    status: updatedOrder.status,
    kitchenStatus: updatedOrder.kitchenStatus,
    updatedAt: updatedOrder.updatedAt,
  });

  return res.json({
    success: true,
    message: 'Status pesanan berhasil diperbarui.',
    order: updatedOrder,
  });
});

/**
 * POST /api/waiter-call
 * Tamu menekan tombol "Panggil Pelayan" di meja.
 */
app.post('/api/waiter-call', (req, res) => {
  const { restoId, tableNo, reason } = req.body;

  if (!restoId || !tableNo) {
    return res.status(400).json({ error: 'restoId dan tableNo wajib diisi.' });
  }

  const callData = {
    id: `CALL-${Date.now()}`,
    restoId: restoId,
    tableNo: String(tableNo),
    reason: reason || 'Bantuan Umum',
    timestamp: new Date().toISOString(),
  };

  // Simpan log panggilan pelayan
  const restoData = readRestoData(restoId);
  if (!restoData.waiterCalls) restoData.waiterCalls = [];
  restoData.waiterCalls.unshift(callData);
  if (restoData.waiterCalls.length > 50) {
    restoData.waiterCalls = restoData.waiterCalls.slice(0, 50);
  }
  saveRestoData(restoId, restoData);

  // Broadcast realtime ke Tablet Kasir
  io.to(`resto:${restoId}`).emit('waiter_call', callData);

  console.log(`[Waiter Call] Meja ${tableNo} memanggil pelayan di resto ${restoId} (${callData.reason})`);

  return res.json({
    success: true,
    message: 'Panggilan pelayan telah diteruskan ke kasir.',
    call: callData,
  });
});

// ============================================================================
// MANAJEMEN REGISTRASI TENANT & LISENSI SAAS (TRIAL 14 HARI)
// ============================================================================
const TENANTS_FILE = path.join(DATA_DIR, 'tenants.json');

/**
 * Membaca seluruh daftar tenant terdaftar dari file JSON.
 * @returns {Array<object>}
 */
function readTenants() {
  if (!fs.existsSync(TENANTS_FILE)) {
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(TENANTS_FILE, 'utf-8'));
  } catch (err) {
    console.error('Gagal membaca data tenants:', err);
    return [];
  }
}

/**
 * Menyimpan data tenant ke file JSON secara atomik.
 * @param {Array<object>} tenants
 */
function saveTenants(tenants) {
  fs.writeFileSync(TENANTS_FILE, JSON.stringify(tenants, null, 2), 'utf-8');
}

/**
 * POST /api/tenants/register
 * Pendaftaran akun tenant kafe/resto baru saat onboarding aplikasi dibuka.
 * Mengaktifkan masa trial 14 hari secara instan.
 */
app.post('/api/tenants/register', (req, res) => {
  const { restoId, businessName, businessType, ownerName, ownerEmail, phone, address, trialDays } = req.body;

  if (!restoId || !businessName) {
    return res.status(400).json({ error: 'restoId dan businessName wajib diisi.' });
  }

  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const tenants = readTenants();
  const existingIndex = tenants.findIndex((t) => t.restoId === sanitizedId);

  const durationDays = Number(trialDays) || 14;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

  const tenantData = {
    restoId: sanitizedId,
    businessName: String(businessName).trim(),
    businessType: businessType || 'cafe',
    ownerName: ownerName || 'Pemilik Toko',
    ownerEmail: ownerEmail ? String(ownerEmail).trim().toLowerCase() : '',
    phone: phone || '',
    address: address || '',
    subscriptionStatus: 'trial',
    trialDays: durationDays,
    createdAt: now.toISOString(),
    trialStartedAt: now.toISOString(),
    trialExpiresAt: expiresAt.toISOString(),
    updatedAt: now.toISOString(),
  };

  if (existingIndex >= 0) {
    tenants[existingIndex] = { ...tenants[existingIndex], ...tenantData };
  } else {
    tenants.push(tenantData);
  }
  saveTenants(tenants);

  // Inisialisasi profil resto di file database resto terisolasi
  const restoData = readRestoData(sanitizedId);
  restoData.name = tenantData.businessName;
  restoData.ownerName = tenantData.ownerName;
  restoData.phone = tenantData.phone;
  restoData.address = tenantData.address;
  saveRestoData(sanitizedId, restoData);

  console.log(`[Tenant] Pendaftaran baru: ${sanitizedId} (${tenantData.businessName}) | Trial: ${durationDays} hari | Owner: ${tenantData.ownerEmail || '-'}`);

  return res.status(201).json({
    success: true,
    message: `Pendaftaran tenant berhasil. Masa aktif trial ${durationDays} hari telah aktif.`,
    tenant: {
      ...tenantData,
      daysLeft: durationDays,
      isExpired: false,
      webOrderUrl: `https://order.ipankhub.web.id/?resto=${sanitizedId}`,
    },
  });
});

/**
 * GET /api/tenants/:restoId/license
 * Mengecek sisa hari trial dan status lisensi tenant.
 */
app.get('/api/tenants/:restoId/license', (req, res) => {
  const { restoId } = req.params;
  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const tenants = readTenants();
  const tenant = tenants.find((t) => t.restoId === sanitizedId);

  if (!tenant) {
    return res.status(404).json({
      error: 'Tenant belum terdaftar di sistem SaaS.',
      restoId: sanitizedId,
      subscriptionStatus: 'unregistered',
      isExpired: true,
    });
  }

  const now = new Date();
  const expiry = new Date(tenant.trialExpiresAt || now);
  const diffMs = expiry.getTime() - now.getTime();
  const daysLeft = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
  const isExpired = diffMs <= 0 && tenant.subscriptionStatus !== 'active_paid';

  return res.json({
    success: true,
    restoId: sanitizedId,
    businessName: tenant.businessName,
    subscriptionStatus: isExpired ? 'expired' : tenant.subscriptionStatus,
    trialExpiresAt: tenant.trialExpiresAt,
    daysLeft: daysLeft,
    isExpired: isExpired,
  });
});

/**
 * GET /api/tenants
 * Mendapatkan daftar seluruh tenant terdaftar (untuk pemilik SaaS).
 */
app.get('/api/tenants', (req, res) => {
  const tenants = readTenants();
  return res.json({
    success: true,
    totalTenants: tenants.length,
    tenants: tenants,
  });
});

/**
 * POST /api/auth/google
 * Otentikasi Akun Google untuk Pemilik Resto (Owner Onboarding & Device Linking).
 * Memeriksa apakah akun Google sudah memiliki tenant terdaftar di cloud SaaS.
 * - Jika ada: Mengembalikan daftar outlet yang dimiliki (bisa pilih & tautkan instan).
 * - Jika baru: Mengembalikan status isNewUser = true untuk melanjutkan wizard setup kafe.
 */
app.post('/api/auth/google', (req, res) => {
  const { email, name, picture, idToken } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email Google wajib disertakan.' });
  }

  const cleanEmail = String(email).trim().toLowerCase();
  const tenants = readTenants();

  // Filter seluruh tenant yang terdaftar atas email owner Google ini
  const userTenants = tenants.filter((t) => (t.ownerEmail || '').toLowerCase() === cleanEmail);

  console.log(`[Google Auth] Login Google: ${cleanEmail} (${name}) | Terhubung dengan ${userTenants.length} outlet`);

  return res.json({
    success: true,
    isNewUser: userTenants.length === 0,
    user: {
      email: cleanEmail,
      name: name || 'Pemilik Toko',
      picture: picture || '',
    },
    tenants: userTenants.map((t) => {
      const now = new Date();
      const expiry = new Date(t.trialExpiresAt || now);
      const diffMs = expiry.getTime() - now.getTime();
      const daysLeft = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
      const isExpired = diffMs <= 0 && t.subscriptionStatus !== 'active_paid';
      return {
        restoId: t.restoId,
        businessName: t.businessName,
        businessType: t.businessType || 'cafe',
        subscriptionStatus: isExpired ? 'expired' : t.subscriptionStatus,
        trialExpiresAt: t.trialExpiresAt,
        daysLeft: daysLeft,
        isExpired: isExpired,
        phone: t.phone || '',
        address: t.address || '',
      };
    }),
  });
});

/**
 * GET /api/tenants/:restoId/details
 * Mengambil detail lengkap konfigurasi tenant (info usaha, katalog, dan staf)
 * untuk sinkronisasi otomatis saat tablet kasir/owner ditautkan via Akun Google.
 */
app.get('/api/tenants/:restoId/details', (req, res) => {
  const { restoId } = req.params;
  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const tenants = readTenants();
  const tenant = tenants.find((t) => t.restoId === sanitizedId);

  if (!tenant) {
    return res.status(404).json({ error: 'Tenant tidak ditemukan.' });
  }

  const restoData = readRestoData(sanitizedId);

  return res.json({
    success: true,
    tenant: tenant,
    catalog: {
      categories: restoData.catalog ? restoData.catalog.categories || [] : [],
      products: restoData.catalog ? restoData.catalog.products || [] : [],
    },
    staff: restoData.staff || [],
  });
});

// ============================================================================
// MANAJEMEN PENAUTAN PERANGKAT KARYAWAN (DEVICE PAIRING & VERIFIKASI PIN)
// ============================================================================

/**
 * POST /api/tenants/:restoId/staff/sync
 * Tablet kasir utama (Owner) menyinkronkan daftar staf karyawan ke cloud SaaS.
 */
app.post('/api/tenants/:restoId/staff/sync', (req, res) => {
  const { restoId } = req.params;
  const { staff } = req.body;

  if (!staff || !Array.isArray(staff)) {
    return res.status(400).json({ error: 'Data staff (array) wajib disertakan.' });
  }

  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const restoData = readRestoData(sanitizedId);

  restoData.staff = staff.map((s) => ({
    id: s.id,
    name: s.name,
    username: s.username || s.name.toLowerCase().replace(/[^a-z0-9]/g, ''),
    role: s.role || 'cashier',
    pinHash: s.pinHash,
    salt: s.salt,
    isActive: s.isActive !== undefined ? s.isActive : true,
    updatedAt: new Date().toISOString(),
  }));

  saveRestoData(sanitizedId, restoData);
  console.log(`[Staff] Sinkronisasi ${restoData.staff.length} staf untuk resto ${sanitizedId}`);

  return res.json({
    success: true,
    message: 'Data staf berhasil disinkronkan ke server.',
    staffCount: restoData.staff.length,
  });
});

/**
 * POST /api/tenants/:restoId/staff/verify
 * HP Karyawan (misal Lukman) memeriksa apakah Resto ID & Username valid sebelum memasukkan PIN.
 */
app.post('/api/tenants/:restoId/staff/verify', (req, res) => {
  const { restoId } = req.params;
  const { username } = req.body;

  if (!username) {
    return res.status(400).json({ error: 'Username wajib disertakan.' });
  }

  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const restoData = readRestoData(sanitizedId);

  const cleanUser = String(username).trim().toLowerCase().replace(/[^a-z0-9]/g, '');
  const staffList = restoData.staff || [];

  const user = staffList.find((s) => {
    const sUsername = (s.username || s.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    const sName = s.name.toLowerCase().replace(/[^a-z0-9]/g, '');
    return sUsername === cleanUser || sName.includes(cleanUser) || cleanUser.includes(sUsername);
  });

  if (!user || user.isActive === false) {
    return res.status(404).json({
      error: `Karyawan '${username}' tidak ditemukan di outlet '${restoData.name}' atau statusnya nonaktif.`,
      restoId: sanitizedId,
      restoName: restoData.name,
    });
  }

  console.log(`[Staff] Verifikasi awal staf berhasil: ${user.name} (${user.role}) di resto ${sanitizedId}`);

  return res.json({
    success: true,
    restoId: sanitizedId,
    restoName: restoData.name,
    staff: {
      id: user.id,
      name: user.name,
      username: user.username || cleanUser,
      role: user.role,
      salt: user.salt,
    },
  });
});

/**
 * POST /api/tenants/:restoId/staff/pair
 * HP Karyawan mengirimkan verifikasi PIN keamanan untuk resmi mengunci & menautkan perangkat ke outlet.
 */
app.post('/api/tenants/:restoId/staff/pair', (req, res) => {
  const { restoId } = req.params;
  const { username, pinHash } = req.body;

  if (!username || !pinHash) {
    return res.status(400).json({ error: 'Username dan pinHash wajib disertakan.' });
  }

  const sanitizedId = String(restoId).trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-');
  const restoData = readRestoData(sanitizedId);

  const cleanUser = String(username).trim().toLowerCase().replace(/[^a-z0-9]/g, '');
  const staffList = restoData.staff || [];

  const user = staffList.find((s) => {
    const sUsername = (s.username || s.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    const sName = s.name.toLowerCase().replace(/[^a-z0-9]/g, '');
    return sUsername === cleanUser || sName.includes(cleanUser);
  });

  if (!user || user.isActive === false) {
    return res.status(404).json({ error: 'Karyawan tidak ditemukan.' });
  }

  if (user.pinHash !== pinHash) {
    return res.status(401).json({ error: 'PIN keamanan salah. Silakan periksa kembali PIN Anda.' });
  }

  console.log(`[Pairing] HP Karyawan resmi tertaut: ${user.name} (${user.role}) di resto ${sanitizedId}`);

  return res.json({
    success: true,
    message: `Perangkat berhasil ditautkan ke ${restoData.name}`,
    restoId: sanitizedId,
    restoName: restoData.name,
    staff: {
      id: user.id,
      name: user.name,
      username: user.username || cleanUser,
      role: user.role,
      pinHash: user.pinHash,
      salt: user.salt,
    },
    catalog: {
      categories: restoData.catalog ? restoData.catalog.categories || [] : [],
      products: restoData.catalog ? restoData.catalog.products || [] : [],
    },
  });
});

// ============================================================================
// MENJALANKAN SERVER
// ============================================================================
server.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`  Mini Resto POS - Backend SaaS Server Running`);
  console.log(`  Port        : ${PORT}`);
  console.log(`  Environment : ${NODE_ENV}`);
  console.log(`  Local URL   : http://localhost:${PORT}`);
  console.log(`====================================================`);
});
