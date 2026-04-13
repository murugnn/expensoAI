import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/version_model.dart';
import 'package:version/version.dart';
import 'package:flutter/material.dart';
import '../widgets/update_dialog.dart';

class UpdateService {
  final Dio _dio = Dio();
  final String checkUrl = 'https://murugan-one.vercel.app/releases/version.json';

  /// Standard instance method to check for updates
  Future<VersionModel?> checkForUpdate() async {
    try {
      final response = await _dio.get(checkUrl);
      if (response.statusCode == 200) {
        final serverVersionInfo = VersionModel.fromJson(response.data);
        
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersionString = packageInfo.version;

        final currentVersion = Version.parse(currentVersionString);
        final serverVersion = Version.parse(serverVersionInfo.version);

        if (serverVersion > currentVersion) {
          return serverVersionInfo;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error checking for update: $e");
      return null;
    }
  }

  /// Downloads the APK and reports progress.
  Future<String?> downloadApk({
    required String url,
    required Function(int count, int total) onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // For Android 13+, READ_EXTERNAL_STORAGE is deprecated. REQUEST_INSTALL_PACKAGES is most critical.
      if (Platform.isAndroid) {
        if (await Permission.requestInstallPackages.isDenied) {
          await Permission.requestInstallPackages.request();
        }
      }

      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;

      final savePath = '${dir.path}/update.apk';
      
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );

      return savePath;
    } catch (e) {
      debugPrint("Error downloading APK: $e");
      return null;
    }
  }

  /// Triggers the Android installer with the downloaded APK.
  Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint("Error installing APK: $e");
      return false;
    }
  }

  // --- Static Utility Methods for Backwards Compatibility ---

  static Future<bool> checkNewVersion() async {
    final service = UpdateService();
    final model = await service.checkForUpdate();
    return model != null;
  }

  static Future<void> checkForUpdates(BuildContext context, {bool showIfLatest = false}) async {
    final service = UpdateService();
    final model = await service.checkForUpdate();

    if (!context.mounted) return;

    if (model != null) {
      showDialog(
        context: context,
        barrierDismissible: !model.forceUpdate,
        builder: (context) => UpdateDialog(versionModel: model),
      );
    } else if (showIfLatest) {
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("App is up to date!"))
      );
    }
  }
}
