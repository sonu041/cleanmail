import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web_gis;

Widget buildPlatformGsiButton() {
  try {
    final plugin = GoogleSignInPlatform.instance;
    if (plugin is web_gis.GoogleSignInPlugin) {
      return plugin.renderButton(
        configuration: web_gis.GSIButtonConfiguration(
          type: web_gis.GSIButtonType.standard,
          theme: web_gis.GSIButtonTheme.outline,
          size: web_gis.GSIButtonSize.large,
          text: web_gis.GSIButtonText.signinWith,
          shape: web_gis.GSIButtonShape.rectangular,
        ),
      );
    }
  } catch (_) {
    // If not initialized yet, avoid throwing StateError during build
  }
  return const SizedBox.shrink();
}
