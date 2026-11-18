import 'package:flutter/material.dart';
import '../../services/file_helper.dart';
import '../../theme/app_theme.dart';

/// Widget Universal untuk menampilkan foto produk menu resto.
/// Secara otomatis mendeteksi apakah sumber foto berasal dari:
/// 1. Tautan URL Internet (http:// atau https://)
/// 2. Data URI / Blob di lingkungan Web (data:image/ atau blob:)
/// 3. Berkas File Lokal Perangkat Native (dari galeri owner / kamera)
/// 4. Fallback Ikon Kategori (jika foto kosong atau gagal dimuat)
class ProductImageView extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? backgroundColor;

  const ProductImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.restaurant_rounded,
    this.fallbackIconSize = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(8);
    final url = imageUrl?.trim();

    Widget content;

    if (url != null && url.isNotEmpty) {
      final isNetwork = url.startsWith('http://') ||
          url.startsWith('https://') ||
          url.startsWith('data:image') ||
          url.startsWith('blob:');

      if (isNetwork) {
        // Sumber gambar dari Tautan Web / Data URI / Blob
        content = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: backgroundColor ?? AppTheme.primaryAmber.withValues(alpha: 0.1),
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            );
          },
        );
      } else {
        // Sumber gambar dari Berkas Lokal Perangkat (ditangani helper lintas platform)
        final fileWidget = buildPlatformFileImage(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
        content = fileWidget is SizedBox ? _buildFallback() : fileWidget;
      }
    } else {
      content = _buildFallback();
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: content,
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? AppTheme.primaryAmber.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: AppTheme.primaryAmber,
        ),
      ),
    );
  }
}
