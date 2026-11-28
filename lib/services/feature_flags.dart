import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing feature flags and versioned releases.
class FeatureFlags {
  static const String _prefsName = 'feature_flags';

  // Version keys
  static const String _keyNewDrawRelease = 'newDrawReleaseVersion';
  static const String _keyNewFontRelease = 'newFontReleaseVersion';
  static const String _keyNewEmojiRelease = 'newEmojiReleaseVersion';
  static const String _keyNewWidgetRelease = 'newWidgetReleaseVersion';
  static const String _keyWhatsNewVersion = 'whatsNewVersion';
  static const String _keySurveyVersion = 'surveyVersion';

  // Default versions
  static const int _defaultDrawRelease = 0x12; // 18
  static const int _defaultFontRelease = 0x11; // 17
  static const int _defaultEmojiRelease = 0x3;  // 3
  static const int _defaultWidgetRelease = 0x17; // 23

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Draw Release Version ---
  int get newDrawReleaseVersion => _prefs.getInt(_keyNewDrawRelease) ?? _defaultDrawRelease;
  set newDrawReleaseVersion(int value) => _prefs.setInt(_keyNewDrawRelease, value);

  // --- Font Release Version ---
  int get newFontReleaseVersion => _prefs.getInt(_keyNewFontRelease) ?? _defaultFontRelease;
  set newFontReleaseVersion(int value) => _prefs.setInt(_keyNewFontRelease, value);

  // --- Emoji Release Version ---
  int get newEmojiReleaseVersion => _prefs.getInt(_keyNewEmojiRelease) ?? _defaultEmojiRelease;
  set newEmojiReleaseVersion(int value) => _prefs.setInt(_keyNewEmojiRelease, value);

  // --- Widget Release Version ---
  int get newWidgetReleaseVersion => _prefs.getInt(_keyNewWidgetRelease) ?? _defaultWidgetRelease;
  set newWidgetReleaseVersion(int value) => _prefs.setInt(_keyNewWidgetRelease, value);

  // --- Whats New Version ---
  int get whatsNewVersion => _prefs.getInt(_keyWhatsNewVersion) ?? 0;
  set whatsNewVersion(int value) => _prefs.setInt(_keyWhatsNewVersion, value);

  // --- Survey Version ---
  int get surveyVersion => _prefs.getInt(_keySurveyVersion) ?? 0;
  set surveyVersion(int value) => _prefs.setInt(_keySurveyVersion, value);

  /// Checks if a new draw release is available.
  bool get hasNewDrawRelease => newDrawReleaseVersion > _defaultDrawRelease;

  /// Checks if a new font release is available.
  bool get hasNewFontRelease => newFontReleaseVersion > _defaultFontRelease;

  /// Checks if a new emoji release is available.
  bool get hasNewEmojiRelease => newEmojiReleaseVersion > _defaultEmojiRelease;

  /// Checks if a new widget release is available.
  bool get hasNewWidgetRelease => newWidgetReleaseVersion > _defaultWidgetRelease;

  /// Resets all versions to defaults (for testing).
  Future<void> resetToDefaults() async {
    await _prefs.setInt(_keyNewDrawRelease, _defaultDrawRelease);
    await _prefs.setInt(_keyNewFontRelease, _defaultFontRelease);
    await _prefs.setInt(_keyNewEmojiRelease, _defaultEmojiRelease);
    await _prefs.setInt(_keyNewWidgetRelease, _defaultWidgetRelease);
    await _prefs.setInt(_keyWhatsNewVersion, 0);
    await _prefs.setInt(_keySurveyVersion, 0);
  }
}

/// Service for managing custom fonts.
class FontManager {
  static const String _prefsKey = 'custom_font_family';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get currentFontFamily => _prefs.getString(_prefsKey);

  Future<void> setFontFamily(String? fontFamily) async {
    if (fontFamily == null || fontFamily.isEmpty) {
      await _prefs.remove(_prefsKey);
    } else {
      await _prefs.setString(_prefsKey, fontFamily);
    }
  }

  /// Available font families (Google Fonts + system).
  static const List<String> availableFonts = [
    'Default (System)',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Nunito',
    'Inter',
    'Source Sans Pro',
    'Merriweather',
    'Playfair Display',
    'Pacifico',
    'Dancing Script',
    'Indie Flower',
    'Permanent Marker',
  ];

  /// Gets the font family string for Google Fonts.
  static String? getGoogleFontName(String displayName) {
    if (displayName == 'Default (System)') return null;
    return displayName;
  }
}

/// Service for managing custom backgrounds.
class BackgroundManager {
  static const String _prefsKey = 'custom_background_id';
  static const String _prefsCustomBgKey = 'custom_background_image';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get currentBackgroundId => _prefs.getString(_prefsKey);

  Future<void> setBackgroundId(String? backgroundId) async {
    if (backgroundId == null || backgroundId.isEmpty) {
      await _prefs.remove(_prefsKey);
    } else {
      await _prefs.setString(_prefsKey, backgroundId);
    }
  }

  /// Saves a custom background image (base64 encoded).
  Future<void> setCustomBackgroundImage(String base64Image) async {
    await _prefs.setString(_prefsCustomBgKey, base64Image);
  }

  String? getCustomBackgroundImage() => _prefs.getString(_prefsCustomBgKey);

  /// Clears custom background.
  Future<void> clearCustomBackground() async {
    await _prefs.remove(_prefsCustomBgKey);
    await _prefs.remove(_prefsKey);
  }

  /// Built-in background options.
  static const List<BackgroundOption> builtInBackgrounds = [
    BackgroundOption(
      id: 'default',
      name: 'Default',
      color: Colors.white,
      pattern: BackgroundPattern.none,
    ),
    BackgroundOption(
      id: 'grid',
      name: 'Grid',
      color: Colors.white,
      pattern: BackgroundPattern.grid,
    ),
    BackgroundOption(
      id: 'dots',
      name: 'Dots',
      color: Colors.white,
      pattern: BackgroundPattern.dots,
    ),
    BackgroundOption(
      id: 'lines',
      name: 'Lines',
      color: Colors.white,
      pattern: BackgroundPattern.lines,
    ),
    BackgroundOption(
      id: 'dark',
      name: 'Dark',
      color: Color(0xFF1E1E1E),
      pattern: BackgroundPattern.none,
    ),
    BackgroundOption(
      id: 'sepia',
      name: 'Sepia',
      color: Color(0xFFF5F0E1),
      pattern: BackgroundPattern.none,
    ),
    BackgroundOption(
      id: 'graph_paper',
      name: 'Graph Paper',
      color: Colors.white,
      pattern: BackgroundPattern.grid,
    ),
  ];
}

/// Represents a background option.
class BackgroundOption {
  const BackgroundOption({
    required this.id,
    required this.name,
    required this.color,
    required this.pattern,
    this.imageUrl,
  });

  final String id;
  final String name;
  final Color color;
  final BackgroundPattern pattern;
  final String? imageUrl;
}

/// Background pattern types.
enum BackgroundPattern {
  none,
  grid,
  dots,
  lines,
  crosshatch,
}