import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Layanan Audio Alert & Notifikasi Suara POS Resto Digital.
/// Menggunakan berkas MP3 kustom: assets/sounds/order_notification.mp3
/// Dipicu otomatis saat pesanan online meja atau panggilan pelayan masuk.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _player;
  bool _soundEnabled = true;

  bool get isSoundEnabled => _soundEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Memutar suara notifikasi pesanan masuk menggunakan file mp3 kustom
  Future<void> playOrderAlert() async {
    if (!_soundEnabled) return;

    try {
      final p = player;
      // Hentikan pemutaran sebelumnya jika sedang berjalan agar tidak tumpang tindih
      await p.stop();
      await p.setVolume(1.0);
      await p.setReleaseMode(ReleaseMode.stop);
      // AssetSource secara default merujuk ke folder 'assets/'
      await p.play(AssetSource('sounds/order_notification.mp3'));
      debugPrint('[SoundService] Berhasil memutar audio notifikasi pesanan baru.');
    } catch (e) {
      debugPrint('[SoundService] Kendala memutar audio asset via audioplayers: $e');
      // Fallback ke nada sistem jika perangkat belum mendukung driver audio
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Uji coba memutar audio notifikasi untuk verifikasi kasir/owner
  Future<void> testSound() async {
    await playOrderAlert();
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
