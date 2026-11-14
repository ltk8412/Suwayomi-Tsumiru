const isGooglePlayBuild = bool.fromEnvironment(
  'TSUMIRU_GOOGLE_PLAY',
  defaultValue: false,
);

/// Tsumiru-Eink does not check the original repo for app updates: its releases
/// do not apply to this fork. Re-enable (and repoint the release URLs in
/// `constants/urls.dart` at this fork) once we publish our own releases.
const appUpdateChecksEnabled = false;
