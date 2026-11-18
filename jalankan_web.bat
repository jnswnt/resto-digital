@echo off
title Mini Resto POS - Web Server Lokal
color 0A
echo =========================================================================
echo               MENJALANKAN MINI RESTO POS - VERSI WEB
echo =========================================================================
echo.
echo Sedang menyiapkan server lokal di http://localhost:8080 ...
echo.

if not exist "%~dp0build\web\index.html" (
    echo [Info] Berkas build web belum ditemukan. Membangun aplikasi web...
    call flutter build web --release
)

echo Membuka browser...
start http://localhost:8080

echo.
echo Server aktif! Jangan tutup jendela ini selama menggunakan POS Web.
echo Tekan Ctrl+C untuk menghentikan server.
echo.
python "%~dp0server.py"

pause
