import http.server
import socketserver
import os
import sys

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class RestoWebHandler(http.server.SimpleHTTPRequestHandler):
    """
    HTTP Request Handler khusus untuk Flutter Web POS.
    Menyajikan berkas statis dari folder build/web dengan header yang sesuai
    serta fallback ke index.html jika rute tidak ditemukan.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, must-revalidate')
        super().end_headers()

    def do_GET(self):
        # Cek apakah file ada, jika tidak ada arahkan ke index.html (SPA Fallback)
        path = self.translate_path(self.path)
        if not os.path.exists(path) and not '.' in os.path.basename(self.path):
            self.path = '/index.html'
        return super().do_GET()

if __name__ == '__main__':
    if not os.path.exists(WEB_DIR):
        print(f"[Error] Direktori {WEB_DIR} belum dibangun. Jalankan 'flutter build web --release' terlebih dahulu.")
        sys.exit(1)

    # Tambahkan MIME types penting jika belum terdaftar
    RestoWebHandler.extensions_map.update({
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.css': 'text/css',
        '.png': 'image/png',
        '.svg': 'image/svg+xml',
    })

    # Mengizinkan reuse address agar tidak error port binding saat restart
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), RestoWebHandler) as httpd:
        print(f"[Mini Resto POS Web Server] Berhasil berjalan di http://localhost:{PORT}")
        print(f"[Folder Web]: {WEB_DIR}")
        print(f"Tekan Ctrl+C untuk menghentikan server.")
        sys.exit_code = 0
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer dihentikan.")
            httpd.server_close()
