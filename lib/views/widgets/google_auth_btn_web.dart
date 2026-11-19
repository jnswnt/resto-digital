import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Implementasi tombol resmi Google Identity Services (GIS) untuk Web
Widget buildGoogleSignInPlatformButton({
  required VoidCallback onPressed,
  required bool isLoading,
}) {
  return SizedBox(
    height: 48,
    width: double.infinity,
    child: Center(
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.filledBlue,
          shape: web.GSIButtonShape.rectangular,
          text: web.GSIButtonText.continueWith,
          size: web.GSIButtonSize.large,
        ),
      ),
    ),
  );
}
