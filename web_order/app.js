/**
 * ============================================================================
 * Resto Digital - Web Self-Ordering Meja Resto
 * 
 * Logika Utama & Fitur Unggulan:
 * 1. Inisialisasi Firebase Firestore SDK (Project: restodigital-pos)
 * 2. Deteksi Nomor Meja dari URL (?table=03) & LocalStorage
 * 3. Sinkronisasi Menu Realtime dari Firestore (Dukungan Sold Out / Menu Habis)
 * 4. Keranjang Belanja & Kustomisasi Rasa/Catatan Khusus (Modifiers)
 * 5. Panggil Bantuan Pelayan (Call Waiter) -> Firestore `table_calls`
 * 6. Pembayaran Mandiri QRIS Dinamis (Auto-Nominal CRC16 EMVCo di Web)
 * 7. Audio Alert Chime (Web Audio API) untuk notifikasi makanan siap
 * 8. Pelacak Status Realtime:
 *    [Menunggu Konfirmasi] -> [Diproses] -> [Disajikan / Selesai]
 * ============================================================================
 */

// 1. KONFIGURASI FIREBASE PROJECT
const firebaseConfig = {
  apiKey: "AIzaSyBL9UgLYEtq32Upsp38Xa_C_Vt2Fgzwy6w",
  authDomain: "restodigital-pos.firebaseapp.com",
  projectId: "restodigital-pos",
  storageBucket: "restodigital-pos.firebasestorage.app",
  messagingSenderId: "59601017378",
  appId: "1:59601017378:web:d90e0e8fd82d957016087b"
};

// Inisialisasi Firebase & Firestore
let db = null;
try {
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    db = firebase.firestore();
  }
} catch (err) {
  console.warn("Firestore inisialisasi tertunda / mode fallback:", err);
}

// 1.1 DETEKSI RESTO ID (MULTI-TENANT ISOLATION)
// Membaca ID Resto dari query URL (?resto=...) atau LocalStorage agar data menu dan pesanan
// terpisah antar restoran meskipun menggunakan domain/proyek web order yang sama.
const urlParamsGlobal = new URLSearchParams(window.location.search);
let currentRestoId = (urlParamsGlobal.get("resto") || urlParamsGlobal.get("r") || localStorage.getItem("pos_resto_id") || "default").trim();
if (urlParamsGlobal.get("resto") || urlParamsGlobal.get("r")) {
  localStorage.setItem("pos_resto_id", currentRestoId);
}

/**
 * Mengembalikan objek Firestore CollectionReference sesuai tenant resto aktif.
 * Jika currentRestoId bukan 'default', data diarahkan ke subkoleksi /restos/{restoId}/{collectionName}
 */
function getRestoCollection(collectionName) {
  if (db) {
    if (currentRestoId && currentRestoId !== "default") {
      return db.collection("restos").doc(currentRestoId).collection(collectionName);
    }
    return db.collection(collectionName);
  }
  return null;
}

// 2. STARTER MENU FALLBACK DENGAN FIELD KETERSEDIAAN (isAvailable)
const STARTER_MENU = [
  {
    id: "m1",
    name: "Nasi Goreng Spesial Resto",
    price: 28000,
    category: "Makanan Utama",
    description: "Nasi goreng bumbu rempah khas resto, suwiran ayam, telur mata sapi, dan kerupuk renyah.",
    icon: "🍛",
    imageUrl: "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isBestSeller: true,
    isRecommended: true
  },
  {
    id: "m2",
    name: "Ayam Bakar Madu Pedas",
    price: 32000,
    category: "Makanan Utama",
    description: "Paha/dada ayam pejantan dengan balutan madu gurih manis pedas, lalapan, dan sambal terasi.",
    icon: "🍗",
    imageUrl: "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isSpicy: true,
    isBestSeller: true
  },
  {
    id: "m3",
    name: "Mie Goreng Seafood",
    price: 30000,
    category: "Makanan Utama",
    description: "Mie kenyal ditumis dengan udang, cumi segar, baso ikan, dan sayuran segar beraroma smokey.",
    icon: "🍜",
    imageUrl: "https://images.unsplash.com/photo-1612927601601-6638404737ce?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isRecommended: true
  },
  {
    id: "m4",
    name: "Soto Ayam Lamongan",
    price: 25000,
    category: "Makanan Utama",
    description: "Kuah kuning gurih berlimpah koya istimewa, suwiran ayam, bihun, dan telur rebus.",
    icon: "🥣",
    imageUrl: "https://images.unsplash.com/photo-1547928576-a4a33237cbc3?w=500&auto=format&fit=crop&q=80",
    isAvailable: true
  },
  {
    id: "m5",
    name: "Es Teh Manis Segar",
    price: 6000,
    category: "Minuman Segar",
    description: "Racikan daun teh pilihan wangi melati dengan es batu segar.",
    icon: "🥤",
    imageUrl: "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isBestSeller: true
  },
  {
    id: "m6",
    name: "Es Jeruk Peras Murni",
    price: 12000,
    category: "Minuman Segar",
    description: "Jeruk peras manis alami segar tanpa perisa buatan.",
    icon: "🍊",
    imageUrl: "https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&auto=format&fit=crop&q=80",
    isAvailable: true
  },
  {
    id: "m7",
    name: "Kopi Susu Gula Aren",
    price: 18000,
    category: "Minuman Segar",
    description: "Espresso house-blend berpadu susu segar gurih dan legit manis gula aren asli.",
    icon: "☕",
    imageUrl: "https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isRecommended: true
  },
  {
    id: "m8",
    name: "Kentang Goreng Crispy",
    price: 16000,
    category: "Camilan & Appetizer",
    description: "Shoestring potato goreng garing keemasan dengan taburan bumbu barbeque & saus cocolan.",
    icon: "🍟",
    imageUrl: "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500&auto=format&fit=crop&q=80",
    isAvailable: true
  },
  {
    id: "m9",
    name: "Pisang Goreng Keju Cokelat",
    price: 18000,
    category: "Camilan & Appetizer",
    description: "Pisang raja manis renyah dengan lelehan cokelat kental dan parutan keju gurih melimpah.",
    icon: "🍌",
    imageUrl: "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isBestSeller: true
  },
  {
    id: "m10",
    name: "Tahu Walik Gurih Crispy",
    price: 15000,
    category: "Camilan & Appetizer",
    description: "Tahu goreng dibalik dengan isian adonan ayam gurih, disajikan hangat bersama sambal kecap cabai rawit.",
    icon: "🥟",
    imageUrl: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=500&auto=format&fit=crop&q=80",
    isAvailable: true,
    isSpicy: true
  }
];

// 3. STATE APLIKASI
let tableNumber = "01";
let menuCatalog = [...STARTER_MENU];
let activeCategory = "all";
let searchQuery = "";
let cart = []; // Array of { id, name, price, qty, note }
let editingCartIndex = -1;
let activeOrderId = null;
let lastKnownOrderStatus = "pending";
let orderTrackerUnsubscribe = null;
let selectedPaymentMethod = "cashier"; // 'cashier' atau 'qris'
let currentStoreQrisPayload = "";

// State Mode Pesanan Tambahan (Round 2)
let isAdditionalOrderMode = false;
let currentOrderRound = 1;
let parentOrderId = null;

// 4. AUDIO CHIME (WEB AUDIO API)
// Suara jernih dua nada (ding-dong) tanpa perlu download file eksternal
function playAudioChime(type = "chime") {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    const ctx = new AudioContext();

    if (type === "orderReady") {
      // Dua nada naik merdu: Mi -> Sol -> Do (Makanan Siap!)
      const notes = [659.25, 783.99, 1046.50];
      notes.forEach((freq, i) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(freq, ctx.currentTime + i * 0.16);

        gain.gain.setValueAtTime(0, ctx.currentTime + i * 0.16);
        gain.gain.linearRampToValueAtTime(0.25, ctx.currentTime + i * 0.16 + 0.04);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + i * 0.16 + 0.4);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(ctx.currentTime + i * 0.16);
        osc.stop(ctx.currentTime + i * 0.16 + 0.45);
      });
    } else {
      // Bell tunggal manis (Panggilan terkirim)
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.setValueAtTime(880, ctx.currentTime);
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.6);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.65);
    }
  } catch (e) {
    console.log("Audio notifikasi:", e);
  }
}

// 5. ELEMEN DOM
const storeNameEl = document.getElementById("storeName");
const tableTextEl = document.getElementById("tableText");
const tableBadgeEl = document.getElementById("tableBadge");
const searchInputEl = document.getElementById("searchInput");
const clearSearchBtn = document.getElementById("clearSearchBtn");
const categoriesNavEl = document.getElementById("categoriesNav");
const menuGridEl = document.getElementById("menuGrid");

const callWaiterFabEl = document.getElementById("callWaiterFab");
const callWaiterModalEl = document.getElementById("callWaiterModal");
const closeCallWaiterModalBtnEl = document.getElementById("closeCallWaiterModalBtn");
const callWaiterTableTextEl = document.getElementById("callWaiterTableText");
const waiterRequestOptionsEl = document.getElementById("waiterRequestOptions");
const callWaiterCustomNoteEl = document.getElementById("callWaiterCustomNote");
const sendCallWaiterBtnEl = document.getElementById("sendCallWaiterBtn");

const floatingCartBarEl = document.getElementById("floatingCartBar");
const cartBadgeCountEl = document.getElementById("cartBadgeCount");
const cartTotalAmountEl = document.getElementById("cartTotalAmount");
const viewCartBtnEl = document.getElementById("viewCartBtn");

const checkoutModalEl = document.getElementById("checkoutModal");
const closeCheckoutModalBtnEl = document.getElementById("closeCheckoutModalBtn");
const checkoutTableNoEl = document.getElementById("checkoutTableNo");
const changeTableBtnEl = document.getElementById("changeTableBtn");
const customerNameInputEl = document.getElementById("customerNameInput");
const orderItemsListEl = document.getElementById("orderItemsList");
const summarySubtotalEl = document.getElementById("summarySubtotal");
const summaryTotalEl = document.getElementById("summaryTotal");
const paymentNoticeEl = document.getElementById("paymentNotice");
const submitOrderBtnEl = document.getElementById("submitOrderBtn");
const roundNoticeBannerEl = document.getElementById("roundNoticeBanner");
const roundBadgePillEl = document.getElementById("roundBadgePill");

const notesModalEl = document.getElementById("notesModal");
const notesModalTitleEl = document.getElementById("notesModalTitle");
const closeNotesModalBtnEl = document.getElementById("closeNotesModalBtn");
const quickTagsWrapEl = document.getElementById("quickTagsWrap");
const itemNotesInputEl = document.getElementById("itemNotesInput");
const saveNotesBtnEl = document.getElementById("saveNotesBtn");

const qrisPaymentModalEl = document.getElementById("qrisPaymentModal");
const closeQrisModalBtnEl = document.getElementById("closeQrisModalBtn");
const qrisDynamicImageEl = document.getElementById("qrisDynamicImage");
const qrisLoadingEl = document.getElementById("qrisLoading");
const qrisAmountDisplayEl = document.getElementById("qrisAmountDisplay");
const qrisOrderRefEl = document.getElementById("qrisOrderRef");
const qrisCanvasWrapEl = document.getElementById("qrisCanvasWrap");
const qrisDirectCanvasEl = document.getElementById("qrisDirectCanvas");
const confirmPaidBtnEl = document.getElementById("confirmPaidBtn");

const trackerModalEl = document.getElementById("trackerModal");
const trackerOrderIdEl = document.getElementById("trackerOrderId");
const trackerTablePillEl = document.getElementById("trackerTablePill");
const stepPendingEl = document.getElementById("stepPending");
const stepProcessingEl = document.getElementById("stepProcessing");
const stepCompletedEl = document.getElementById("stepCompleted");
const trackerItemsSummaryEl = document.getElementById("trackerItemsSummary");
const closeTrackerBtnEl = document.getElementById("closeTrackerBtn");
const closeTrackerXBtnEl = document.getElementById("closeTrackerXBtn");
const newOrderBtnEl = document.getElementById("newOrderBtn");
const finishAndClearTableBtnEl = document.getElementById("finishAndClearTableBtn");

// Komponen Estimasi Waktu Dapur (Cooking Timer)
const cookingTimerCardEl = document.getElementById("cookingTimerCard");
const timerIconEl = document.getElementById("timerIcon");
const timerHeadingEl = document.getElementById("timerHeading");
const timerDurationBadgeEl = document.getElementById("timerDurationBadge");
const timerProgressBarEl = document.getElementById("timerProgressBar");
const timerStatusHintEl = document.getElementById("timerStatusHint");

// Elemen Tombol Pemantauan Pesanan Aktif (Header & Floating Bar)
const headerTrackOrderBtnEl = document.getElementById("headerTrackOrderBtn");
const activeOrderFloatingBarEl = document.getElementById("activeOrderFloatingBar");
const aofbIconEl = document.getElementById("aofbIcon");
const aofbStatusTitleEl = document.getElementById("aofbStatusTitle");
const aofbRoundBadgeEl = document.getElementById("aofbRoundBadge");
const aofbTotalAmountEl = document.getElementById("aofbTotalAmount");
const openTrackerFromFloatingBtnEl = document.getElementById("openTrackerFromFloatingBtn");

// Elemen Modal Struk Pembayaran Sukses (Lunas)
const paymentSuccessModalEl = document.getElementById("paymentSuccessModal");
const paidStoreNameEl = document.getElementById("paidStoreName");
const paidTablePillEl = document.getElementById("paidTablePill");
const paidOrderIdEl = document.getElementById("paidOrderId");
const paidMethodBadgeEl = document.getElementById("paidMethodBadge");
const paidTotalAmountEl = document.getElementById("paidTotalAmount");
const paidItemsListWrapEl = document.getElementById("paidItemsListWrap");
const finishSessionAfterPaidBtnEl = document.getElementById("finishSessionAfterPaidBtn");
const closePaidReceiptBtnEl = document.getElementById("closePaidReceiptBtn");

// ============================================================================
// PENGELOLA PUTARAN PESANAN MEJA (MULTI-ROUND TABLE MANAGEMENT)
// ============================================================================

function getTableRounds() {
  try {
    const saved = localStorage.getItem(`resto_table_rounds_${tableNumber}`);
    if (saved) {
      const parsed = JSON.parse(saved);
      if (Array.isArray(parsed) && parsed.length > 0) {
        const filtered = parsed.filter(r => (r.tableNo || "").toString().padStart(2, "0") === tableNumber);
        if (filtered.length > 0) return filtered;
      }
    }
  } catch (e) {}

  try {
    const last = localStorage.getItem(`resto_last_order_data_${tableNumber}`);
    if (last) {
      const parsed = JSON.parse(last);
      if ((parsed.tableNo || "").toString().padStart(2, "0") === tableNumber) {
        return [parsed];
      }
    }
  } catch (e) {}

  return [];
}

function saveTableRound(orderData) {
  const targetTable = (orderData.tableNo || tableNumber).toString().padStart(2, "0");
  let rounds = [];
  try {
    const saved = localStorage.getItem(`resto_table_rounds_${targetTable}`);
    if (saved) rounds = JSON.parse(saved) || [];
  } catch (e) {}

  if (orderData.isAdditionalOrder) {
    const idx = rounds.findIndex(r => r.orderId === orderData.orderId);
    if (idx >= 0) {
      rounds[idx] = orderData;
    } else {
      rounds.push(orderData);
    }
  } else {
    // Pesanan baru (Round 1)
    rounds = [orderData];
  }
  localStorage.setItem(`resto_table_rounds_${targetTable}`, JSON.stringify(rounds));
  localStorage.setItem(`resto_last_order_data_${targetTable}`, JSON.stringify(orderData));
  return rounds;
}

function getTableGrandTotal() {
  const rounds = getTableRounds();
  return rounds.reduce((sum, r) => sum + (Number(r.totalAmount) || 0), 0);
}

// Memperbarui tombol & floating widget pemantau pesanan aktif
function updateActiveOrderTrackerUI() {
  const rounds = getTableRounds();
  const hasActiveOrder = Boolean(
    activeOrderId &&
    rounds.length > 0 &&
    lastKnownOrderStatus !== "cancelled" &&
    lastKnownOrderStatus !== "rejected"
  );

  if (!hasActiveOrder) {
    if (headerTrackOrderBtnEl) headerTrackOrderBtnEl.style.display = "none";
    if (activeOrderFloatingBarEl) activeOrderFloatingBarEl.style.display = "none";
    return;
  }

  const grandTotal = getTableGrandTotal();
  const roundCount = rounds.length;

  // 1. Tampilkan tombol di Header
  if (headerTrackOrderBtnEl) {
    headerTrackOrderBtnEl.style.display = "inline-flex";
  }

  // 2. Tampilkan Floating Bar di bawah (jika modal tracker sedang tertutup)
  if (activeOrderFloatingBarEl) {
    if (trackerModalEl && trackerModalEl.style.display === "flex") {
      activeOrderFloatingBarEl.style.display = "none";
    } else {
      activeOrderFloatingBarEl.style.display = "flex";

      // Jika floating cart bar sedang aktif (ada item keranjang), posisikan di atasnya
      const isCartActive = cart.length > 0;
      if (isCartActive) {
        activeOrderFloatingBarEl.classList.add("cart-visible");
      } else {
        activeOrderFloatingBarEl.classList.remove("cart-visible");
      }

      if (aofbTotalAmountEl) aofbTotalAmountEl.textContent = formatRupiah(grandTotal);
      if (aofbRoundBadgeEl) aofbRoundBadgeEl.textContent = roundCount > 1 ? "Ada Tambahan" : "Pesanan Aktif";

      if (lastKnownOrderStatus === "pending") {
        if (aofbIconEl) aofbIconEl.textContent = "⏳";
        if (aofbStatusTitleEl) aofbStatusTitleEl.textContent = "Menunggu Konfirmasi Kasir";
      } else if (lastKnownOrderStatus === "processing" || lastKnownOrderStatus === "confirmed") {
        if (aofbIconEl) aofbIconEl.textContent = "🍳";
        if (aofbStatusTitleEl) aofbStatusTitleEl.textContent = "Pesanan Sedang Dimasak";
      } else if (lastKnownOrderStatus === "completed" || lastKnownOrderStatus === "served") {
        if (aofbIconEl) aofbIconEl.textContent = "✨";
        if (aofbStatusTitleEl) aofbStatusTitleEl.textContent = "Hidangan Telah Disajikan";
      }
    }
  }
}

// 6. INISIALISASI SAAT HALAMAN DIMUAT
document.addEventListener("DOMContentLoaded", () => {
  setupTableNumber();
  setupEventListeners();
  loadMenuAndConfigFromFirestore();
  checkExistingActiveOrder();
});

// Helper: Format Rupiah
function formatRupiah(amount) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
  }).format(amount);
}

/**
 * Kamus Pemetaan ID Kategori Teknis Database (cat_makanan, cat_camilan, dll)
 * ke Nama Label Tampilan yang Ramah, Elegan, dan Mudah Dipahami Tamu Meja Resto.
 */
const CATEGORY_DISPLAY_MAP = {
  "cat_makanan": "Makanan Utama",
  "cat_minuman": "Minuman Segar",
  "cat_camilan": "Camilan & Appetizer",
  "cat_paket": "Paket Hemat",
  "cat_rokok": "Rokok & Lainnya",
  "makanan": "Makanan Utama",
  "minuman": "Minuman Segar",
  "camilan": "Camilan & Appetizer",
  "snack": "Camilan & Appetizer",
  "paket": "Paket Hemat"
};

/**
 * Format nama kategori agar bersih, rapi, dan ramah dibaca tamu resto.
 * Mencegah ID teknis mentah seperti 'cat_makanan' atau 'cat_camilan' tampil di antarmuka web.
 *
 * @param {string} cat - Nama atau ID kategori mentah dari Firestore/database
 * @returns {string} Nama kategori manusiawi dalam format Title Case yang bersih
 */
function formatCategoryName(cat) {
  if (!cat) return "Menu";
  const str = String(cat).trim();
  const lower = str.toLowerCase();

  // 1. Cek langsung dari kamus pemetaan resmi resto
  if (CATEGORY_DISPLAY_MAP[lower]) {
    return CATEGORY_DISPLAY_MAP[lower];
  }

  // 2. Bersihkan awalan teknis seperti 'cat_' atau 'category_'
  let cleaned = str.replace(/^(cat|category)[_-]/i, "");
  const cleanedLower = cleaned.toLowerCase();
  if (CATEGORY_DISPLAY_MAP[cleanedLower]) {
    return CATEGORY_DISPLAY_MAP[cleanedLower];
  }

  // 3. Ganti pemisah underscore (_) atau strip (-) dengan spasi tunggal
  cleaned = cleaned.replace(/[_-]+/g, " ").trim();
  if (!cleaned) return "Menu";

  // 4. Ubah menjadi format Title Case yang rapi (contoh: 'kue_basah' -> 'Kue Basah')
  return cleaned
    .split(" ")
    .map(w => w ? w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() : "")
    .join(" ");
}

// 7. SETUP NOMOR MEJA
function setupTableNumber() {
  const urlParams = new URLSearchParams(window.location.search);
  const tableParam = urlParams.get("table") || urlParams.get("t");
  
  if (tableParam) {
    tableNumber = tableParam.trim().padStart(2, "0");
    localStorage.setItem("resto_table_number", tableNumber);
  } else {
    const saved = localStorage.getItem("resto_table_number");
    if (saved) {
      tableNumber = saved;
    }
  }

  loadTableState();
  updateTableDisplay();
}

function loadTableState() {
  // Migrasi data legacy un-suffixed jika ada (agar pesanan meja sebelumnya tersimpan rapi sesuai mejanya)
  const legacyLast = localStorage.getItem("resto_last_order_data");
  if (legacyLast) {
    try {
      const parsed = JSON.parse(legacyLast);
      const legTable = (parsed.tableNo || "01").toString().padStart(2, "0");
      localStorage.setItem(`resto_last_order_data_${legTable}`, legacyLast);
      const legActiveId = localStorage.getItem("resto_active_order_id");
      if (legActiveId) {
        localStorage.setItem(`resto_active_order_id_${legTable}`, legActiveId);
      }
      const legRounds = localStorage.getItem("resto_table_rounds");
      if (legRounds) {
        localStorage.setItem(`resto_table_rounds_${legTable}`, legRounds);
      }
    } catch (e) {}
    // Bersihkan kunci legacy global agar tidak bocor antar-meja
    localStorage.removeItem("resto_active_order_id");
    localStorage.removeItem("resto_last_order_data");
    localStorage.removeItem("resto_table_rounds");
    localStorage.removeItem("resto_customer_name");
    localStorage.removeItem("resto_order_round");
    localStorage.removeItem("resto_parent_order_id");
  }

  // Validasi apakah meja ini memiliki pesanan sah
  const validRounds = getTableRounds();
  let isStale = false;
  if (validRounds.length > 0) {
    const lastOrder = validRounds[validRounds.length - 1];
    if (lastOrder && lastOrder.createdAt) {
      const orderTime = new Date(lastOrder.createdAt).getTime();
      // Bila pesanan lebih lama dari 4 jam yang lalu, bersihkan sesi secara otomatis
      if (!isNaN(orderTime) && (Date.now() - orderTime > 4 * 60 * 60 * 1000)) {
        isStale = true;
      }
    }
  }

  if (validRounds.length === 0 || isStale) {
    activeOrderId = null;
    currentOrderRound = 1;
    parentOrderId = null;
    localStorage.removeItem(`resto_active_order_id_${tableNumber}`);
    localStorage.removeItem(`resto_last_order_data_${tableNumber}`);
    localStorage.removeItem(`resto_table_rounds_${tableNumber}`);
    localStorage.removeItem(`resto_order_round_${tableNumber}`);
    localStorage.removeItem(`resto_parent_order_id_${tableNumber}`);
    localStorage.removeItem(`resto_customer_name_${tableNumber}`);
  } else {
    activeOrderId = localStorage.getItem(`resto_active_order_id_${tableNumber}`) || validRounds[validRounds.length - 1].orderId;
    currentOrderRound = parseInt(localStorage.getItem(`resto_order_round_${tableNumber}`) || (validRounds.length + 1).toString(), 10);
    parentOrderId = localStorage.getItem(`resto_parent_order_id_${tableNumber}`) || validRounds[0].orderId;
  }

  // Hentikan listener realtime pesanan meja lain jika sedang berjalan
  if (orderTrackerUnsubscribe) {
    orderTrackerUnsubscribe();
    orderTrackerUnsubscribe = null;
  }

  // Jika meja ini belum punya pesanan aktif, sembunyikan modal dan banner pelacak
  if (!activeOrderId) {
    if (trackerModalEl) trackerModalEl.style.display = "none";
    if (activeOrderFloatingBarEl) activeOrderFloatingBarEl.style.display = "none";
    if (headerTrackOrderBtnEl) headerTrackOrderBtnEl.style.display = "none";
  }
}

// Mengosongkan sesi pesanan meja (misal saat pelanggan selesai makan / kasir checkout meja)
function clearTableSession(targetTable = tableNumber) {
  const tableKey = (targetTable || tableNumber).toString().padStart(2, "0");
  if (tableKey === tableNumber) {
    activeOrderId = null;
    currentOrderRound = 1;
    parentOrderId = null;
    isAdditionalOrderMode = false;
    lastKnownOrderStatus = "pending";
    cart = [];
    updateFloatingCartBar();

    if (orderTrackerUnsubscribe) {
      orderTrackerUnsubscribe();
      orderTrackerUnsubscribe = null;
    }
    if (trackerModalEl) trackerModalEl.style.display = "none";
    updateActiveOrderTrackerUI();
  }

  localStorage.removeItem(`resto_active_order_id_${tableKey}`);
  localStorage.removeItem(`resto_last_order_data_${tableKey}`);
  localStorage.removeItem(`resto_table_rounds_${tableKey}`);
  localStorage.removeItem(`resto_order_round_${tableKey}`);
  localStorage.removeItem(`resto_parent_order_id_${tableKey}`);
  localStorage.removeItem(`resto_customer_name_${tableKey}`);
}

function updateTableDisplay() {
  const label = `Meja ${tableNumber}`;
  tableTextEl.textContent = label;
  checkoutTableNoEl.textContent = label;
  callWaiterTableTextEl.textContent = label;
  trackerTablePillEl.textContent = label;
}

// 8. MEMUAT MENU & PENGATURAN TOKO DARI FIRESTORE
async function loadMenuAndConfigFromFirestore() {
  renderCategoryChips();
  renderMenu();

  if (!db) return;

  try {
    // Ambil menu resto realtime
    const menuCol = getRestoCollection("resto_menu");
    if (menuCol) {
      menuCol.onSnapshot(snapshot => {
        if (!snapshot.empty) {
          const items = [];
          snapshot.forEach(doc => {
            const d = doc.data();
            // Gunakan formatCategoryName agar ID teknis seperti cat_makanan otomatis menjadi nama ramah (Makanan Utama)
            const rawCat = d.categoryName || d.category || d.categoryId || "Makanan Utama";
            items.push({
              id: doc.id,
              name: d.name,
              price: d.price || d.sellPrice || 0,
              category: formatCategoryName(rawCat),
              description: d.description || "Menu lezat pilihan resto kami.",
              icon: d.icon || "🍽️",
              imageUrl: d.imageUrl,
              isAvailable: d.isAvailable !== undefined ? d.isAvailable : true,
              isSpicy: d.isSpicy || false,
              isBestSeller: d.isBestSeller || false,
              isRecommended: d.isRecommended || false
            });
          });
          menuCatalog = items;
          renderCategoryChips();
          renderMenu();
        }
      }, err => console.warn("Listener menu realtime:", err));
    }

    // Hubungkan konfigurasi QRIS toko & profil resto secara realtime dari Cloud Firestore
    const configCol = getRestoCollection("resto_config");
    if (configCol) {
      configCol.doc("settings").onSnapshot((doc) => {
      if (doc.exists) {
        const data = doc.data();
        if (data.qrisPayload && data.qrisPayload.trim().length > 10) {
          currentStoreQrisPayload = data.qrisPayload.trim();
          console.log("Konfigurasi QRIS toko terhubung realtime dari kasir:", currentStoreQrisPayload.slice(0, 30) + "...");
        }
        if (data.storeName) storeNameEl.textContent = data.storeName;
      }
    }, err => console.warn("Listener konfigurasi QRIS realtime:", err));
  } catch (err) {
    console.warn("Menggunakan katalog menu default:", err.message);
  }
}

// 9. RENDER KATEGORI CHIP
function renderCategoryChips() {
  const categories = ["all", ...new Set(menuCatalog.map(m => m.category).filter(Boolean))];
  
  categoriesNavEl.innerHTML = categories.map(cat => {
    const label = cat === "all" ? "Semua Menu" : formatCategoryName(cat);
    const activeClass = cat === activeCategory ? "active" : "";
    return `<button class="category-chip ${activeClass}" data-category="${cat}">${label}</button>`;
  }).join("");

  categoriesNavEl.querySelectorAll(".category-chip").forEach(btn => {
    btn.addEventListener("click", () => {
      activeCategory = btn.getAttribute("data-category");
      renderCategoryChips();
      renderMenu();
    });
  });
}

// 10. RENDER MENU KATALOG (MENDUKUNG BADGE HABIS / SOLD OUT & BADGES SPICY/BESTSELLER)
function renderMenu() {
  let filtered = menuCatalog;

  if (activeCategory !== "all") {
    filtered = filtered.filter(item => item.category === activeCategory);
  }

  if (searchQuery.trim() !== "") {
    const q = searchQuery.toLowerCase();
    filtered = filtered.filter(item => 
      item.name.toLowerCase().includes(q) || 
      (item.description && item.description.toLowerCase().includes(q))
    );
  }

  if (filtered.length === 0) {
    menuGridEl.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🔍</div>
        <h3>Menu Tidak Ditemukan</h3>
        <p>Coba gunakan kata kunci pencarian yang lain.</p>
      </div>
    `;
    return;
  }

  menuGridEl.innerHTML = filtered.map(item => {
    const inCartQty = getCartQty(item.id);
    const hasImage = item.imageUrl && item.imageUrl.startsWith("http");
    const isAvailable = item.isAvailable !== false; // default true jika tidak diset false

    // Kumpulkan badge visual menu
    const badges = [];
    if (item.isBestSeller) {
      badges.push(`<span class="menu-badge-tag badge-bestseller">⭐ Terlaris</span>`);
    }
    if (item.isSpicy) {
      badges.push(`<span class="menu-badge-tag badge-spicy">🌶️ Pedas</span>`);
    }
    if (item.isRecommended) {
      badges.push(`<span class="menu-badge-tag badge-chef">👑 Koki</span>`);
    }
    const badgesHtml = badges.length > 0 ? `<div class="menu-badges-group">${badges.join('')}</div>` : '';

    return `
      <div class="menu-card ${!isAvailable ? 'sold-out' : ''}" data-id="${item.id}">
        ${!isAvailable ? `<span class="sold-out-badge">HABIS</span>` : ''}
        <div class="menu-card-img-wrap">
          ${badgesHtml}
          ${hasImage 
            ? `<img class="menu-card-img" src="${item.imageUrl}" alt="${item.name}" loading="lazy" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';">
               <div class="menu-card-img-fallback" style="display: none;">${item.icon || "🍽️"}</div>` 
            : `<div class="menu-card-img-fallback">${item.icon || "🍽️"}</div>`
          }
          <span class="menu-category-tag">${formatCategoryName(item.category) || "Menu"}</span>
        </div>
        <div class="menu-card-body">
          <h3 class="menu-card-name">${item.name}</h3>
          <p class="menu-card-desc">${item.description || "Menu favorit lezat khas resto kami."}</p>
          <div class="menu-card-footer">
            <span class="menu-card-price">${formatRupiah(item.price)}</span>
            ${!isAvailable ? `
              <button class="add-btn disabled-btn" disabled>
                <span>Habis</span>
              </button>
            ` : inCartQty > 0 ? `
              <div class="qty-control">
                <button class="qty-btn" onclick="updateQty('${item.id}', -1)">-</button>
                <span class="qty-number">${inCartQty}</span>
                <button class="qty-btn" onclick="updateQty('${item.id}', 1)">+</button>
              </div>
            ` : `
              <button class="add-btn" onclick="addToCart('${item.id}')">
                <span>+ Tambah</span>
              </button>
            `}
          </div>
        </div>
      </div>
    `;
  }).join("");
}

// Helper: Ambil kuantitas total per item di keranjang
function getCartQty(menuId) {
  return cart
    .filter(i => i.id === menuId)
    .reduce((sum, i) => sum + i.qty, 0);
}

// 11. OPERASI KERANJANG BELANJA
window.addToCart = function(menuId) {
  const menuItem = menuCatalog.find(m => m.id === menuId);
  if (!menuItem || menuItem.isAvailable === false) return;

  const existing = cart.find(i => i.id === menuId && (!i.note || i.note === ""));
  if (existing) {
    existing.qty += 1;
  } else {
    cart.push({
      id: menuItem.id,
      name: menuItem.name,
      price: menuItem.price,
      qty: 1,
      note: ""
    });
  }

  updateCartUI();
  renderMenu();
};

window.updateQty = function(menuId, delta) {
  let targetIndex = -1;
  if (delta < 0) {
    // Prioritaskan pengurangan dari item yang tidak memiliki catatan khusus
    targetIndex = cart.findIndex(i => i.id === menuId && (!i.note || i.note.trim() === ""));
    // Jika semua varian memiliki catatan, kurangi dari varian terakhir
    if (targetIndex === -1) {
      for (let k = cart.length - 1; k >= 0; k--) {
        if (cart[k].id === menuId) {
          targetIndex = k;
          break;
        }
      }
    }
  } else {
    // Penambahan: utamakan item tanpa catatan
    targetIndex = cart.findIndex(i => i.id === menuId && (!i.note || i.note.trim() === ""));
    if (targetIndex === -1) {
      targetIndex = cart.findIndex(i => i.id === menuId);
    }
  }

  if (targetIndex === -1) return;

  cart[targetIndex].qty += delta;
  if (cart[targetIndex].qty <= 0) {
    cart.splice(targetIndex, 1);
  }

  updateCartUI();
  renderMenu();
  renderCartList();
};

function updateCartUI() {
  const totalQty = cart.reduce((sum, i) => sum + i.qty, 0);
  const totalPrice = cart.reduce((sum, i) => sum + (i.price * i.qty), 0);

  if (totalQty > 0) {
    floatingCartBarEl.style.display = "flex";
    cartBadgeCountEl.textContent = totalQty;
    cartTotalAmountEl.textContent = formatRupiah(totalPrice);
  } else {
    floatingCartBarEl.style.display = "none";
  }

  // Sinkronkan posisi floating tracker bar
  updateActiveOrderTrackerUI();
}

// 12. MODAL CHECKOUT & RINCIAN PESANAN
function renderCartList() {
  const totalPrice = cart.reduce((sum, i) => sum + (i.price * i.qty), 0);

  if (cart.length === 0) {
    orderItemsListEl.innerHTML = `<p style="text-align:center; color: var(--text-muted); padding: 20px;">Keranjang kosong.</p>`;
    summarySubtotalEl.textContent = "Rp 0";
    summaryTotalEl.textContent = "Rp 0";
    checkoutModalEl.style.display = "none";
    return;
  }

  orderItemsListEl.innerHTML = cart.map((item, idx) => {
    return `
      <div class="cart-item-row">
        <div class="cart-item-details">
          <div class="cart-item-name">${item.name}</div>
          <div class="cart-item-price">${item.qty} x ${formatRupiah(item.price)} = <strong>${formatRupiah(item.price * item.qty)}</strong></div>
          ${item.note ? `<div class="cart-item-note">📝 ${item.note}</div>` : ""}
          <div style="margin-top: 6px;">
            <button class="btn-item-note" onclick="openNotesModal(${idx})">
              ${item.note ? "✏️ Edit Catatan" : "+ Tambah Catatan Rasa"}
            </button>
          </div>
        </div>
        <div class="cart-item-action">
          <div class="qty-control">
            <button class="qty-btn" onclick="updateItemIndexQty(${idx}, -1)">-</button>
            <span class="qty-number">${item.qty}</span>
            <button class="qty-btn" onclick="updateItemIndexQty(${idx}, 1)">+</button>
          </div>
        </div>
      </div>
    `;
  }).join("");

  // Update banner mode pesanan tambahan & optimalisasi tampilan total harga
  if (isAdditionalOrderMode) {
    const rounds = getTableRounds();
    const previousRoundsTotal = rounds.reduce((sum, r) => sum + (Number(r.totalAmount) || 0), 0);
    const grandTotal = previousRoundsTotal + totalPrice;

    summarySubtotalEl.innerHTML = `<span>Subtotal Tambahan:</span> <strong>${formatRupiah(totalPrice)}</strong>`;
    summaryTotalEl.innerHTML = `
      <div style="display: flex; flex-direction: column; align-items: flex-end;">
        <span style="font-size: 0.74rem; font-weight: normal; color: var(--text-muted);">
          Sebelumnya (${formatRupiah(previousRoundsTotal)}) + Tambahan (${formatRupiah(totalPrice)})
        </span>
        <span style="color: var(--primary); font-size: 1.18rem; font-weight: 900; margin-top: 2px;">
          Total Meja: ${formatRupiah(grandTotal)}
        </span>
      </div>
    `;

    if (roundNoticeBannerEl) roundNoticeBannerEl.style.display = "flex";
    if (roundBadgePillEl) roundBadgePillEl.textContent = "Menu Tambahan";
    const savedName = localStorage.getItem("resto_customer_name");
    if (savedName && customerNameInputEl) {
      customerNameInputEl.value = savedName;
      customerNameInputEl.readOnly = true;
    }
    const submitBtnText = submitOrderBtnEl.querySelector("span");
    if (submitBtnText) {
      submitBtnText.textContent = "Kirim Pesanan Tambahan";
    }
  } else {
    summarySubtotalEl.textContent = formatRupiah(totalPrice);
    summaryTotalEl.textContent = formatRupiah(totalPrice);

    if (roundNoticeBannerEl) roundNoticeBannerEl.style.display = "none";
    if (customerNameInputEl) customerNameInputEl.readOnly = false;
    const submitBtnText = submitOrderBtnEl.querySelector("span");
    if (submitBtnText) {
      submitBtnText.textContent = "Kirim Pesanan ke Kasir";
    }
  }
}

window.updateItemIndexQty = function(index, delta) {
  if (!cart[index]) return;
  cart[index].qty += delta;
  if (cart[index].qty <= 0) {
    cart.splice(index, 1);
  }
  updateCartUI();
  renderMenu();
  renderCartList();
};

// 13. MODAL CATATAN / MODIFIERS
window.openNotesModal = function(cartIndex) {
  editingCartIndex = cartIndex;
  const item = cart[cartIndex];
  if (!item) return;

  notesModalTitleEl.textContent = `Catatan: ${item.name}`;
  itemNotesInputEl.value = item.note || "";

  quickTagsWrapEl.querySelectorAll(".quick-tag").forEach(tag => {
    const noteText = tag.getAttribute("data-note");
    if (item.note && item.note.includes(noteText)) {
      tag.classList.add("selected");
    } else {
      tag.classList.remove("selected");
    }
  });

  notesModalEl.style.display = "flex";
};

// 14. FITUR PANGGIL PELAYAN (CALL WAITER)
let selectedWaiterRequestType = "Sendok / Garpu / Piring";

function openCallWaiterModal() {
  callWaiterModalEl.style.display = "flex";
}

// Helper fungsi perlindungan batas waktu request jaringan agar UI tidak pernah stuck
function withTimeout(promise, ms = 4500, timeoutMsg = "Waktu koneksi cloud habis") {
  let timer;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(timeoutMsg)), ms);
  });
  return Promise.race([
    promise.then(res => { clearTimeout(timer); return res; }),
    timeoutPromise
  ]);
}

async function sendCallWaiter() {
  const customNote = callWaiterCustomNoteEl.value.trim();
  sendCallWaiterBtnEl.disabled = true;
  sendCallWaiterBtnEl.innerHTML = `<span>Memanggil pelayan...</span>`;

  const callId = "CALL-" + Date.now().toString().slice(-6);
  const callData = {
    callId: callId,
    tableNo: tableNumber,
    requestType: selectedWaiterRequestType,
    notes: customNote,
    status: "pending",
    createdAt: new Date().toISOString()
  };

  try {
    if (db) {
      const callsCol = getRestoCollection("table_calls");
      if (callsCol) {
        await withTimeout(
          callsCol.doc(callId).set(callData),
          4000,
          "Koneksi cloud lambat"
        );
      }
    }
  } catch (err) {
    console.warn("Koneksi cloud Firestore lambat/offline:", err);
  }

  playAudioChime("chime");
  alert(`Panggilan pelayan untuk Meja ${tableNumber} berhasil dikirim! Pelayan resto segera datang membawakan: ${selectedWaiterRequestType}`);
  callWaiterModalEl.style.display = "none";
  callWaiterCustomNoteEl.value = "";
  sendCallWaiterBtnEl.disabled = false;
  sendCallWaiterBtnEl.innerHTML = `<span>Kirim Panggilan ke Kasir</span> <span class="btn-icon">🔔</span>`;
}

// 15. ALGORITMA QRIS DINAMIS JAVASCRIPT (CRC16-CCITT EMVCo TAG 54)
function calculateCrc16(str) {
  let crc = 0xFFFF;
  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i);
    crc ^= (c << 8);
    for (let j = 0; j < 8; j++) {
      if ((crc & 0x8000) !== 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, "0");
}

function removeExistingTag54(payload) {
  let idx = 0;
  while (true) {
    idx = payload.indexOf("54", idx);
    if (idx === -1) break;
    if (idx + 4 <= payload.length) {
      const len = parseInt(payload.substring(idx + 2, idx + 4), 10);
      if (!isNaN(len) && len > 0 && idx + 4 + len <= payload.length) {
        const val = payload.substring(idx + 4, idx + 4 + len);
        if (/^\d+(\.\d+)?$/.test(val)) {
          return payload.substring(0, idx) + payload.substring(idx + 4 + len);
        }
      }
    }
    idx += 2;
  }
  return payload;
}

function generateDynamicQrisPayload(basePayload, amount) {
  if (!basePayload || basePayload.trim().length < 25) {
    return null;
  }

  let payload = basePayload.trim();

  // 1. Buang tag CRC 63 yang ada di akhir (format '6304xxxx')
  const crcIndex = payload.lastIndexOf("6304");
  if (crcIndex !== -1 && (payload.length - crcIndex) <= 10) {
    payload = payload.substring(0, crcIndex);
  }

  // 2. Ubah mode dari Static (010211) menjadi Dynamic (010212)
  if (payload.includes("010211")) {
    payload = payload.replace("010211", "010212");
  } else if (!payload.includes("010212") && payload.startsWith("000201")) {
    payload = "000201010212" + payload.substring(6);
  }

  // 3. Buang Tag 54 lama jika ada agar tidak terjadi duplikasi nominal
  payload = removeExistingTag54(payload);

  // 4. Siapkan Tag 54 baru dengan nominal pesanan pas
  const amtStr = Math.round(amount).toString();
  const amtLen = amtStr.length.toString().padStart(2, "0");
  const tag54 = `54${amtLen}${amtStr}`;

  // 5. Sisipkan Tag 54 sebelum Tag 58 (Country Code '5802ID' atau '5802')
  let tag58Index = payload.indexOf("5802ID");
  if (tag58Index === -1) {
    tag58Index = payload.indexOf("5802");
  }

  if (tag58Index !== -1) {
    payload = payload.substring(0, tag58Index) + tag54 + payload.substring(tag58Index);
  } else {
    payload = payload + tag54;
  }

  // 6. Hitung ulang CRC16 CCITT
  const stringToCrc = payload + "6304";
  const checksum = calculateCrc16(stringToCrc);
  return stringToCrc + checksum;
}

// 16. KIRIM PESANAN KE FIRESTORE (TABLE_ORDERS)
async function submitOrder() {
  const customerName = customerNameInputEl.value.trim();
  if (!customerName) {
    alert("Silakan masukkan Nama Pemesan terlebih dahulu agar kasir dapat mengenali pesanan Anda.");
    customerNameInputEl.focus();
    return;
  }

  if (cart.length === 0) {
    alert("Keranjang pesanan masih kosong.");
    return;
  }

  submitOrderBtnEl.disabled = true;
  submitOrderBtnEl.innerHTML = `<span>Mengirim pesanan...</span> <div class="spinner" style="width:16px;height:16px;border-width:2px;margin:0;"></div>`;

  const totalAmount = cart.reduce((sum, i) => sum + (i.price * i.qty), 0);
  const orderId = "ORD-" + Date.now().toString().slice(-6);

  const isAdditional = isAdditionalOrderMode;
  const currentRound = isAdditionalOrderMode ? currentOrderRound : 1;
  const parentId = isAdditionalOrderMode ? (parentOrderId || activeOrderId) : null;

  const orderData = {
    orderId: orderId,
    tableNo: tableNumber,
    customerName: customerName,
    items: cart.map(i => ({
      id: i.id,
      name: i.name,
      price: i.price,
      qty: i.qty,
      note: i.note || ""
    })),
    totalAmount: totalAmount,
    status: "pending",
    paymentMethod: selectedPaymentMethod, // 'cashier' atau 'qris'
    paymentStatus: selectedPaymentMethod === "qris" ? "waiting_verification" : "unpaid",
    isAdditionalOrder: isAdditional,
    parentOrderId: parentId,
    roundNumber: currentRound,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  // 1. Simpan seketika ke LocalStorage khusus nomor meja ini agar tidak bocor ke meja lain
  activeOrderId = orderId;
  localStorage.setItem(`resto_active_order_id_${tableNumber}`, orderId);
  localStorage.setItem(`resto_customer_name_${tableNumber}`, customerName);
  localStorage.setItem(`resto_last_order_data_${tableNumber}`, JSON.stringify(orderData));
  localStorage.setItem(`offline_order_${orderId}`, JSON.stringify(orderData));

  if (isAdditional) {
    localStorage.setItem(`resto_order_round_${tableNumber}`, (currentRound + 1).toString());
  } else {
    localStorage.setItem(`resto_order_round_${tableNumber}`, "2");
    localStorage.setItem(`resto_parent_order_id_${tableNumber}`, orderId);
  }
  isAdditionalOrderMode = false;

  // 2. Kirim ke Cloud Firestore dengan proteksi timeout 5 detik
  try {
    if (db) {
      const ordersCol = getRestoCollection("table_orders");
      if (ordersCol) {
        await withTimeout(
          ordersCol.doc(orderId).set(orderData),
          5000,
          "Waktu koneksi cloud habis, pesanan dialihkan ke antrean lokal."
        );
      }
    }
  } catch (err) {
    console.warn("Koneksi cloud Firestore lambat atau gagal, pesanan tetap diproses via data lokal:", err);
  }

  // 3. Selesaikan checkout & buka pelacak status pesanan
  cart = [];
  updateCartUI();
  renderMenu();
  checkoutModalEl.style.display = "none";

  submitOrderBtnEl.disabled = false;
  submitOrderBtnEl.innerHTML = `<span>Kirim Pesanan ke Kasir</span> <span class="btn-icon">🚀</span>`;

  // Jika memilih bayar langsung via QRIS
  if (selectedPaymentMethod === "qris") {
    showQrisPaymentModal(orderId, totalAmount, orderData);
  } else {
    startOrderTracking(orderId, orderData);
  }
}

// 17. TAMPILKAN POPUP QRIS PEMBAYARAN MANDIRI
function showQrisPaymentModal(orderId, amount, orderData) {
  qrisAmountDisplayEl.textContent = formatRupiah(amount);
  qrisOrderRefEl.textContent = `ID: #${orderId} - Meja ${tableNumber}`;
  qrisPaymentModalEl.style.display = "flex";

  const dynamicPayload = generateDynamicQrisPayload(currentStoreQrisPayload, amount);

  let unconfiguredNotice = document.getElementById("qrisUnconfiguredNotice");
  if (!unconfiguredNotice) {
    unconfiguredNotice = document.createElement("div");
    unconfiguredNotice.id = "qrisUnconfiguredNotice";
    qrisCanvasWrapEl.parentNode.insertBefore(unconfiguredNotice, qrisCanvasWrapEl.nextSibling);
  }

  // Jika kasir belum memasang/menyinkronkan QRIS resmi resto
  if (!dynamicPayload) {
    qrisLoadingEl.style.display = "none";
    qrisDynamicImageEl.style.display = "none";
    qrisCanvasWrapEl.style.display = "none";
    unconfiguredNotice.style.display = "block";
    unconfiguredNotice.innerHTML = `
      <div style="background: rgba(245, 158, 11, 0.12); border: 1.5px dashed #f59e0b; border-radius: 14px; padding: 16px; margin: 12px 0; text-align: center;">
        <span style="font-size: 2rem;">🏪</span>
        <h4 style="margin: 8px 0 4px; color: #d97706; font-size: 0.95rem;">QRIS Toko Belum Dihubungkan</h4>
        <p style="font-size: 0.8rem; color: var(--text-muted); line-height: 1.4; margin: 0;">
          Kasir resto belum menyinkronkan stiker QRIS resmi dari menu <em>Pengaturan > QRIS</em> di aplikasi POS kasir.<br><br>
          Silakan bayar di meja kasir setelah pesanan Anda selesai disajikan.
        </p>
      </div>
    `;

    confirmPaidBtnEl.innerHTML = `<span>Bayar di Meja Kasir Saja</span> <span class="btn-icon">🏪</span>`;
    confirmPaidBtnEl.onclick = () => {
      qrisPaymentModalEl.style.display = "none";
      startOrderTracking(orderId, orderData);
    };
    return;
  }

  // Jika payload QRIS resmi valid dari kasir
  qrisCanvasWrapEl.style.display = "block";
  unconfiguredNotice.style.display = "none";
  confirmPaidBtnEl.innerHTML = `<span>Saya Sudah Bayar</span> <span class="btn-icon">✅</span>`;

  // 1. Coba render instan menggunakan library QRCode lokal
  if (typeof QRCode !== "undefined" && qrisDirectCanvasEl) {
    qrisDirectCanvasEl.innerHTML = "";
    qrisDirectCanvasEl.style.display = "flex";
    qrisDynamicImageEl.style.display = "none";
    qrisLoadingEl.style.display = "none";
    try {
      new QRCode(qrisDirectCanvasEl, {
        text: dynamicPayload,
        width: 220,
        height: 220,
        colorDark: "#111827",
        colorLight: "#FFFFFF",
        correctLevel: QRCode.CorrectLevel.M
      });
    } catch(e) {
      console.warn("Fallback load gambar QR:", e);
    }
  } else {
    // 2. Fallback menggunakan image URL jika library belum ter-load
    if (qrisDirectCanvasEl) qrisDirectCanvasEl.style.display = "none";
    qrisLoadingEl.style.display = "block";
    qrisDynamicImageEl.style.display = "none";
    const qrUrl = `https://quickchart.io/qr?text=${encodeURIComponent(dynamicPayload)}&size=240&margin=1`;
    qrisDynamicImageEl.src = qrUrl;
    qrisDynamicImageEl.onload = () => {
      qrisLoadingEl.style.display = "none";
      qrisDynamicImageEl.style.display = "block";
    };
  }

  confirmPaidBtnEl.onclick = async () => {
    confirmPaidBtnEl.disabled = true;
    confirmPaidBtnEl.innerHTML = `<span>Menyimpan Konfirmasi...</span> ⏳`;
    if (db) {
      try {
        const ordersCol = getRestoCollection("table_orders");
        if (ordersCol) {
          await ordersCol.doc(orderId).update({
            paymentStatus: "waiting_verification",
            updatedAt: new Date().toISOString()
          });
        }
      } catch (err) {
        console.warn("Gagal update paymentStatus ke waiting_verification:", err);
      }
    }
    confirmPaidBtnEl.disabled = false;
    confirmPaidBtnEl.innerHTML = `<span>Saya Sudah Bayar</span> <span class="btn-icon">✅</span>`;
    qrisPaymentModalEl.style.display = "none";
    startOrderTracking(orderId, { ...orderData, paymentStatus: "waiting_verification" });
  };
}

// 18. PELACAK STATUS REALTIME & ESTIMASI WAKTU DAPUR (ORDER TRACKER)
function startOrderTracking(orderId, initialData) {
  trackerOrderIdEl.textContent = `#${orderId}`;
  trackerTablePillEl.textContent = `Meja ${initialData.tableNo || tableNumber}`;
  
  if (initialData) {
    saveTableRound(initialData);
  }

  renderTrackerSummary(initialData);
  updateTrackerVisuals(initialData.status || "pending");
  updateCookingTimer(initialData.status || "pending", initialData.createdAt);
  lastKnownOrderStatus = initialData.status || "pending";
  trackerModalEl.style.display = "flex";
  
  // Sembunyikan floating bar saat modal tracker aktif
  if (activeOrderFloatingBarEl) activeOrderFloatingBarEl.style.display = "none";

  if (orderTrackerUnsubscribe) {
    orderTrackerUnsubscribe();
    orderTrackerUnsubscribe = null;
  }

  if (db) {
    const ordersCol = getRestoCollection("table_orders");
    if (ordersCol) {
      orderTrackerUnsubscribe = ordersCol.doc(orderId)
        .onSnapshot((doc) => {
        if (doc.exists) {
          const updated = doc.data();
          
          // Jika pesanan telah dilunasi di kasir, tampilkan struk pembayaran digital
          if (updated.status === "paid") {
            if (orderTrackerUnsubscribe) {
              orderTrackerUnsubscribe();
              orderTrackerUnsubscribe = null;
            }
            if (trackerModalEl) trackerModalEl.style.display = "none";
            playAudioChime("orderReady");
            showPaymentSuccessReceipt(updated);
            return;
          }

          // Jika pesanan dibatalkan oleh kasir, kosongkan sesi meja
          if (updated.status === "cancelled") {
            clearTableSession(tableNumber);
            return;
          }

          // Simpan pembaruan status ke rounds
          saveTableRound(updated);

          // Audio Alert jika status berubah menjadi Disajikan / Selesai!
          if ((updated.status === "completed" || updated.status === "served") && lastKnownOrderStatus !== "completed") {
            playAudioChime("orderReady");
          }
          lastKnownOrderStatus = updated.status;

          updateTrackerVisuals(updated.status);
          updateCookingTimer(updated.status, updated.createdAt);
          if (updated.items) {
            renderTrackerSummary(updated);
          }
          updateActiveOrderTrackerUI();
        } else {
          // Dokumen pesanan telah dihapus/dibersihkan oleh kasir saat meja dikosongkan
          clearTableSession(tableNumber);
        }
      }, (err) => {
        console.warn("Listener status pesanan:", err);
      });
  }
}

function updateTrackerVisuals(status) {
  stepPendingEl.className = "timeline-step";
  stepProcessingEl.className = "timeline-step";
  stepCompletedEl.className = "timeline-step";

  if (status === "pending") {
    stepPendingEl.classList.add("active");
  } else if (status === "processing" || status === "confirmed") {
    stepPendingEl.classList.add("completed");
    stepProcessingEl.classList.add("active");
  } else if (status === "completed" || status === "served") {
    stepPendingEl.classList.add("completed");
    stepProcessingEl.classList.add("completed");
    stepCompletedEl.classList.add("active");
  }

  // Tampilkan tombol "Selesai Santap / Mulai Meja Baru" ketika hidangan telah disajikan
  if (finishAndClearTableBtnEl) {
    if (status === "completed" || status === "served") {
      finishAndClearTableBtnEl.style.display = "flex";
    } else {
      finishAndClearTableBtnEl.style.display = "none";
    }
  }
}

// Menghitung & Memperbarui Tampilan Estimasi Waktu Dapur Realtime
function updateCookingTimer(status, createdAt) {
  if (!cookingTimerCardEl) return;

  if (status === "pending") {
    cookingTimerCardEl.classList.remove("timer-completed");
    if (timerIconEl) timerIconEl.textContent = "⏳";
    if (timerHeadingEl) timerHeadingEl.textContent = "Menunggu Konfirmasi Kasir";
    if (timerDurationBadgeEl) timerDurationBadgeEl.textContent = "~15 Mnt";
    if (timerProgressBarEl) timerProgressBarEl.style.width = "20%";
    if (timerStatusHintEl) timerStatusHintEl.textContent = "Pesanan telah dikirim ke kasir. Koki siap memasak setelah dikonfirmasi.";
  } else if (status === "processing" || status === "confirmed") {
    cookingTimerCardEl.classList.remove("timer-completed");
    if (timerIconEl) timerIconEl.textContent = "🍳";
    if (timerHeadingEl) timerHeadingEl.textContent = "Sedang Dimasak di Dapur";
    
    let elapsedMinutes = 0;
    if (createdAt) {
      const orderDate = new Date(createdAt);
      if (!isNaN(orderDate.getTime())) {
        elapsedMinutes = Math.max(0, Math.floor((Date.now() - orderDate.getTime()) / 60000));
      }
    }
    const estimatedTotal = 15;
    const remainingMinutes = Math.max(2, estimatedTotal - elapsedMinutes);
    const progressPercent = Math.min(88, Math.max(35, 30 + (elapsedMinutes * 5)));

    if (timerDurationBadgeEl) timerDurationBadgeEl.textContent = `~${remainingMinutes} Mnt Lagi`;
    if (timerProgressBarEl) timerProgressBarEl.style.width = `${progressPercent}%`;
    if (timerStatusHintEl) timerStatusHintEl.textContent = "Koki sedang mengolah hidangan Anda dengan cermat. Harap santai sejenak!";
  } else if (status === "completed" || status === "served") {
    cookingTimerCardEl.classList.add("timer-completed");
    if (timerIconEl) timerIconEl.textContent = "✨";
    if (timerHeadingEl) timerHeadingEl.textContent = "Hidangan Telah Disajikan";
    if (timerDurationBadgeEl) timerDurationBadgeEl.textContent = "Selesai!";
    if (timerProgressBarEl) timerProgressBarEl.style.width = "100%";
    if (timerStatusHintEl) timerStatusHintEl.textContent = "Semua hidangan telah disajikan ke meja Anda. Selamat menikmati santapan!";
  }
}

function renderTrackerSummary(orderData) {
  const rounds = getTableRounds();
  if (rounds.length === 0 && orderData) {
    rounds.push(orderData);
  }

  const grandTotal = getTableGrandTotal();
  const customerName = (orderData && orderData.customerName) || 
                       localStorage.getItem("resto_customer_name") || 
                       "Pelanggan";

  let html = `<div style="margin-bottom: 10px; font-size: 0.88rem;"><strong>Pesanan Meja: ${customerName}</strong></div>`;

  rounds.forEach((round, rIdx) => {
    const roundNum = round.roundNumber || (rIdx + 1);
    const roundTitle = roundNum === 1 
      ? "Pesanan Utama" 
      : (rounds.length > 2 ? `Pesanan Tambahan #${roundNum - 1}` : "Pesanan Tambahan");
    const payInfo = round.paymentMethod === "qris" ? " • [QRIS Mandiri]" : " • [Bayar di Kasir]";

    const itemsHtml = (round.items || []).map(i => {
      return `<div style="padding: 2.5px 0;">• <strong>${i.qty}x</strong> ${i.name} ${i.note ? `<em>(${i.note})</em>` : ''} <span style="float:right; font-weight:600;">${formatRupiah(i.price * i.qty)}</span></div>`;
    }).join("");

    html += `
      <div class="tracker-round-box">
        <div class="tracker-round-header">
          <span class="tracker-round-badge">${roundTitle}${payInfo}</span>
          <span class="tracker-round-subtotal">${formatRupiah(round.totalAmount)}</span>
        </div>
        <div style="font-size: 0.78rem; color: var(--text-muted); line-height: 1.5; margin-top: 4px;">
          ${itemsHtml}
        </div>
      </div>
    `;
  });

  html += `
    <div class="tracker-grand-total-banner">
      <span class="tgt-label">TOTAL KESELURUHAN MEJA:</span>
      <span class="tgt-amount">${formatRupiah(grandTotal)}</span>
    </div>
  `;

  trackerItemsSummaryEl.innerHTML = html;
}

// Membuka modal pelacak status pesanan secara manual dari tombol pantau
function openTrackerModal() {
  if (!activeOrderId) return;
  const rounds = getTableRounds();
  const lastData = rounds[rounds.length - 1] || JSON.parse(localStorage.getItem(`resto_last_order_data_${tableNumber}`) || "{}");
  if (lastData && lastData.tableNo && lastData.tableNo !== tableNumber) {
    return;
  }
  startOrderTracking(activeOrderId, lastData);
}

function checkExistingActiveOrder() {
  if (!activeOrderId) {
    updateActiveOrderTrackerUI();
    return;
  }
  const rounds = getTableRounds();
  const savedData = rounds[rounds.length - 1] || (localStorage.getItem(`resto_last_order_data_${tableNumber}`) ? JSON.parse(localStorage.getItem(`resto_last_order_data_${tableNumber}`)) : null);
  if (savedData) {
    if (savedData.tableNo && savedData.tableNo !== tableNumber) {
      activeOrderId = null;
      updateActiveOrderTrackerUI();
      return;
    }

    // Jalankan listener Firestore di latar belakang dan perbarui UI tracker button
    if (db) {
      const ordersCol = getRestoCollection("table_orders");
      if (ordersCol) {
        orderTrackerUnsubscribe = ordersCol.doc(activeOrderId)
          .onSnapshot((doc) => {
          if (doc.exists) {
            const updated = doc.data();
            if (updated.tableNo && updated.tableNo !== tableNumber) {
              return;
            }
            if (updated.status === "paid") {
              if (orderTrackerUnsubscribe) {
                orderTrackerUnsubscribe();
                orderTrackerUnsubscribe = null;
              }
              if (trackerModalEl) trackerModalEl.style.display = "none";
              playAudioChime("orderReady");
              showPaymentSuccessReceipt(updated);
              return;
            }
            if (updated.status === "cancelled") {
              clearTableSession(tableNumber);
              return;
            }
            saveTableRound(updated);
            lastKnownOrderStatus = updated.status;
            updateActiveOrderTrackerUI();
          }
        }, (err) => console.warn("Background order listener:", err));
    }
    updateActiveOrderTrackerUI();
  }
}

// ============================================================================
// STRUK DIGITAL PEMBAYARAN LUNAS (DIGITAL RECEIPT MODAL)
// ============================================================================
function showPaymentSuccessReceipt(orderData) {
  if (!paymentSuccessModalEl) return;

  if (paidStoreNameEl && storeNameEl) {
    paidStoreNameEl.textContent = storeNameEl.textContent || "Resto Digital";
  }
  if (paidTablePillEl) {
    paidTablePillEl.textContent = `Meja ${orderData.tableNo || tableNumber}`;
  }
  if (paidOrderIdEl) {
    paidOrderIdEl.textContent = `#${orderData.orderId || orderData.id || activeOrderId || "RESTO"}`;
  }
  if (paidMethodBadgeEl) {
    const isQris = (orderData.paymentMethod || "").toLowerCase() === "qris";
    paidMethodBadgeEl.textContent = isQris ? "📱 QRIS DINAMIS" : "💵 KASIR / TUNAI";
  }

  // Hitung total dari seluruh rounds jika pelanggan pesan multi-round
  const rounds = getTableRounds();
  let totalAmount = orderData.totalAmount || 0;
  let items = orderData.items || [];

  if (rounds.length > 1) {
    totalAmount = rounds.reduce((sum, r) => sum + (r.totalAmount || 0), 0);
    items = rounds.flatMap(r => r.items || []);
  }

  if (paidTotalAmountEl) {
    paidTotalAmountEl.textContent = formatRupiah(totalAmount);
  }

  if (paidItemsListWrapEl) {
    if (items && items.length > 0) {
      paidItemsListWrapEl.innerHTML = items.map(item => `
        <div style="display: flex; justify-content: space-between; align-items: flex-start; padding: 7px 0; border-bottom: 1px dashed var(--border-color); font-size: 0.85rem;">
          <div>
            <span style="font-weight: 600; color: var(--text-dark);">${item.name}</span>
            <span style="color: var(--text-muted); font-size: 0.8rem; margin-left: 4px;">x${item.qty}</span>
            ${item.note ? `<div style="font-size: 0.75rem; color: #b45309; margin-top: 2px;">📝 ${item.note}</div>` : ""}
          </div>
          <span style="font-weight: 600; color: var(--text-dark);">${formatRupiah((item.price || 0) * (item.qty || 1))}</span>
        </div>
      `).join("");
    } else {
      paidItemsListWrapEl.innerHTML = `<p style="text-align: center; color: var(--text-muted); font-size: 0.85rem;">Pesanan telah diselesaikan.</p>`;
    }
  }

  paymentSuccessModalEl.style.display = "flex";
}

// 19. EVENT LISTENERS
function setupEventListeners() {
  // Pencarian
  searchInputEl.addEventListener("input", (e) => {
    searchQuery = e.target.value;
    clearSearchBtn.style.display = searchQuery ? "flex" : "none";
    renderMenu();
  });

  clearSearchBtn.addEventListener("click", () => {
    searchInputEl.value = "";
    searchQuery = "";
    clearSearchBtn.style.display = "none";
    renderMenu();
  });

  // FAB Panggil Pelayan
  callWaiterFabEl.addEventListener("click", openCallWaiterModal);
  closeCallWaiterModalBtnEl.addEventListener("click", () => {
    callWaiterModalEl.style.display = "none";
  });

  waiterRequestOptionsEl.querySelectorAll(".request-option-item").forEach(item => {
    item.addEventListener("click", () => {
      waiterRequestOptionsEl.querySelectorAll(".request-option-item").forEach(i => i.classList.remove("selected"));
      item.classList.add("selected");
      selectedWaiterRequestType = item.getAttribute("data-type");
    });
  });

  sendCallWaiterBtnEl.addEventListener("click", sendCallWaiter);

  // Floating Cart Bar Click -> Buka Checkout Modal
  floatingCartBarEl.addEventListener("click", () => {
    renderCartList();
    const savedName = localStorage.getItem(`resto_customer_name_${tableNumber}`) || localStorage.getItem("resto_customer_name");
    if (savedName && !customerNameInputEl.value) {
      customerNameInputEl.value = savedName;
    }
    checkoutModalEl.style.display = "flex";
  });

  closeCheckoutModalBtnEl.addEventListener("click", () => {
    checkoutModalEl.style.display = "none";
  });

  // Pemilihan Metode Pembayaran (Cashier vs QRIS)
  const paymentCards = document.querySelectorAll(".payment-option-card");
  paymentCards.forEach(card => {
    card.addEventListener("click", () => {
      paymentCards.forEach(c => c.classList.remove("active"));
      card.classList.add("active");
      const radio = card.querySelector('input[name="paymentMethod"]');
      if (radio) {
        radio.checked = true;
        selectedPaymentMethod = radio.value;
        if (selectedPaymentMethod === "qris") {
          paymentNoticeEl.textContent = "Setelah kirim pesanan, QRIS dengan nominal pas akan muncul di layar HP Anda.";
        } else {
          paymentNoticeEl.textContent = "Pembayaran dilakukan di kasir setelah pesanan diterima / selesai makan.";
        }
      }
    });
  });

  // Ubah Nomor Meja Manual
  changeTableBtnEl.addEventListener("click", () => {
    const input = prompt("Masukkan nomor meja Anda:", tableNumber);
    if (input && input.trim()) {
      tableNumber = input.trim().padStart(2, "0");
      localStorage.setItem("resto_table_number", tableNumber);
      loadTableState();
      updateTableDisplay();
      checkExistingActiveOrder();
    }
  });

  tableBadgeEl.addEventListener("click", () => {
    const input = prompt("Masukkan nomor meja Anda:", tableNumber);
    if (input && input.trim()) {
      tableNumber = input.trim().padStart(2, "0");
      localStorage.setItem("resto_table_number", tableNumber);
      loadTableState();
      updateTableDisplay();
      checkExistingActiveOrder();
    }
  });

  // Quick Tags Modifier
  quickTagsWrapEl.querySelectorAll(".quick-tag").forEach(btn => {
    btn.addEventListener("click", () => {
      const tagText = btn.getAttribute("data-note");
      let currentVal = itemNotesInputEl.value.trim();
      
      if (btn.classList.contains("selected")) {
        btn.classList.remove("selected");
        currentVal = currentVal.replace(tagText, "").replace(/,\s*,/g, ",").replace(/^,\s*/, "").replace(/,\s*$/, "").trim();
      } else {
        btn.classList.add("selected");
        currentVal = currentVal ? `${currentVal}, ${tagText}` : tagText;
      }
      itemNotesInputEl.value = currentVal;
    });
  });

  // Simpan Catatan Modifiers
  saveNotesBtnEl.addEventListener("click", () => {
    if (editingCartIndex >= 0 && cart[editingCartIndex]) {
      cart[editingCartIndex].note = itemNotesInputEl.value.trim();
    }
    notesModalEl.style.display = "none";
    renderCartList();
  });

  closeNotesModalBtnEl.addEventListener("click", () => {
    notesModalEl.style.display = "none";
  });

  closeQrisModalBtnEl.addEventListener("click", () => {
    qrisPaymentModalEl.style.display = "none";
  });

  // Submit Order
  submitOrderBtnEl.addEventListener("click", submitOrder);

  // Tracker Modal Buttons & Pemantauan Pesanan Aktif
  if (headerTrackOrderBtnEl) {
    headerTrackOrderBtnEl.addEventListener("click", openTrackerModal);
  }

  if (openTrackerFromFloatingBtnEl) {
    openTrackerFromFloatingBtnEl.addEventListener("click", openTrackerModal);
  }

  if (closeTrackerXBtnEl) {
    closeTrackerXBtnEl.addEventListener("click", () => {
      trackerModalEl.style.display = "none";
      updateActiveOrderTrackerUI();
    });
  }

  if (closeTrackerBtnEl) {
    closeTrackerBtnEl.addEventListener("click", () => {
      trackerModalEl.style.display = "none";
      updateActiveOrderTrackerUI();
    });
  }

  if (newOrderBtnEl) {
    newOrderBtnEl.addEventListener("click", () => {
      trackerModalEl.style.display = "none";
      isAdditionalOrderMode = true;
      parentOrderId = activeOrderId;
      currentOrderRound = parseInt(localStorage.getItem(`resto_order_round_${tableNumber}`) || "2", 10);
      updateActiveOrderTrackerUI();

      alert(`✨ Mode Pesanan Tambahan Aktif!\n\nSilakan pilih menu makanan / minuman tambahan untuk Meja ${tableNumber}.\nPesanan baru ini otomatis digabungkan ke tagihan kasir Anda.`);
    });
  }

  if (finishAndClearTableBtnEl) {
    finishAndClearTableBtnEl.addEventListener("click", () => {
      const confirmClear = confirm(
        `✨ Selesai santap di Meja ${tableNumber}?\n\n` +
        `Klik OK untuk mengosongkan status meja ini dan menyiapkan halaman pemesanan baru untuk pelanggan berikutnya.`
      );
      if (confirmClear) {
        clearTableSession(tableNumber);
        alert(`Meja ${tableNumber} telah dikosongkan dan siap menerima pesanan tamu baru.`);
      }
    });
  }

  // Tombol Modal Struk Pembayaran Sukses (Lunas)
  if (finishSessionAfterPaidBtnEl) {
    finishSessionAfterPaidBtnEl.addEventListener("click", () => {
      clearTableSession(tableNumber);
      if (paymentSuccessModalEl) paymentSuccessModalEl.style.display = "none";
      alert(`Terima kasih atas kunjungan Anda di Meja ${tableNumber}! Meja telah siap untuk tamu berikutnya.`);
      location.reload();
    });
  }

  if (closePaidReceiptBtnEl) {
    closePaidReceiptBtnEl.addEventListener("click", () => {
      if (paymentSuccessModalEl) paymentSuccessModalEl.style.display = "none";
    });
  }
}
