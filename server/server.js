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
    };
  }
  try {
    const raw = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(raw);
  } catch (error) {
    console.error(`Gagal membaca data resto [${restoId}]:`, error);
    return { restoId, catalog: { categories: [], products: [] }, orders: [], waiterCalls: [] };
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
