import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:satisfied_version/satisfied_version.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:update_helper/src/utils/open_store.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'models/stateful_alert.dart';
part 'models/update_platform_config.dart';

class UpdateHelper {
  /// Create instance for UpdateHelper
  static final instance = UpdateHelper._();

  UpdateHelper._();

  bool _isDebug = false;

  /// This is internal variable. Only use for testing.
  @visibleForTesting
  String packageName = '';

  /// Intitalize the package.
  Future<void> initial({
    /// Current context.
    required BuildContext context,

    /// Configuration for each platform.
    required UpdateConfig updateConfig,

    /// Force update on this version. The user can't close this dialog until it's updated.
    bool forceUpdate = false,

    /// Use `satisfied_version` package to compare with current version to force update.
    ///
    /// Ex: ["<=1.0.0"] means the app have to update if current version <= 1.0.0
    List<String> bannedVersions = const [],

    /// Only show the update dialog when the current version is banned or
    /// [forceUpdate] is `true`.
    bool onlyShowDialogWhenBanned = false,

    /// Title of the dialog.
    String title = 'Update',

    /// Content of the dialog (No force).
    ///
    /// `%currentVersion` will be replaced with the current version
    /// `%latestVersion` wull be replaced with the latest version
    String content = 'New version is available!\n\n'
        'Current version: %currentVersion\n'
        'Latest version: %latestVersion\n\n'
        'Do you want to update?',

    /// OK button text
    String okButtonText = 'OK',

    /// Later button text
    String laterButtonText = 'Later',

    /// Content of the dialog in force mode.
    String forceUpdateContent = 'New version is available!\n\n'
        'Current version: %currentVersion\n'
        'Latest version: %latestVersion\n\n'
        'You have to update to continue using the app!',

    /// Show changelogs if `changelogs` is not empty.
    ///
    /// Changelogs:
    /// - Changelog 1
    /// - Changelog 2
    List<String> changelogs = const [],

    /// Changelogs text: 'Changelogs' -> 'Changelogs:'
    String changelogsText = 'Changelogs',

    /// Show this text if the Store cannot be opened
    ///
    /// `%error` will be replaced with the error log.
    String failToOpenStoreError = 'Got an error when trying to open the Store, '
        'please update the app manually. '
        '\nSorry for the inconvenience.\n(Logs: %error)',

    /// Print debuglog.
    bool isDebug = false,
  }) async {
    _isDebug = isDebug;

    UpdatePlatformConfig? updatePlatformConfig;
    if (UniversalPlatform.isAndroid) {
      updatePlatformConfig = updateConfig.android;
    } else if (UniversalPlatform.isIOS) {
      updatePlatformConfig = updateConfig.ios;
    } else if (UniversalPlatform.isWeb) {
      updatePlatformConfig = updateConfig.web;
    } else if (UniversalPlatform.isWindows) {
      updatePlatformConfig = updateConfig.windows;
    } else if (UniversalPlatform.isLinux) {
      updatePlatformConfig = updateConfig.linux;
    } else if (UniversalPlatform.isMacOS) {
      updatePlatformConfig = updateConfig.macos;
    }

    updatePlatformConfig ??= updateConfig.defaultConfig;

    if (updatePlatformConfig == null ||
        updatePlatformConfig.latestVersion == null) {
      _print('Config from this platform is null');
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version;
    _print('current version: $currentVersion');

    if (updatePlatformConfig.latestVersion!.compareTo(currentVersion) <= 0) {
      _print('Current version is up to date');
      return;
    }

    if (!forceUpdate && SatisfiedVersion.list(currentVersion, bannedVersions)) {
      _print('Current version have to force to update');
      forceUpdate = true;
    }

    if (!onlyShowDialogWhenBanned ||
        (onlyShowDialogWhenBanned && forceUpdate)) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => _StatefulAlert(
            forceUpdate: forceUpdate,
            title: title,
            content: content,
            forceUpdateContent: forceUpdateContent,
            changelogs: changelogs,
            changelogsText: changelogsText,
            okButtonText: okButtonText,
            laterButtonText: laterButtonText,
            updatePlatformConfig: updatePlatformConfig!,
            currentVersion: currentVersion,
            packageInfo: packageInfo,
            failToOpenStoreError: failToOpenStoreError),
      );
    }
  }

  void _print(Object? object) =>
      // ignore: avoid_print
      _isDebug ? debugPrint('[Update Helper] $object') : null;

  /// Open the store
  static Future<void> openStore({
    /// Use this Url if any error occurs
    String? fallbackUrl,

    /// Print debug log
    bool debugLog = false,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      await openStoreImpl(
        packageInfo.packageName,
        fallbackUrl,
        (progress) {
          if (debugLog) debugPrint('[UpdateHelper.openStore] $progress');
        },
      );
    } catch (_) {
      if (fallbackUrl != null && await canLaunchUrlString(fallbackUrl)) {
        await launchUrlString(fallbackUrl);
      }
    }
  }
}
