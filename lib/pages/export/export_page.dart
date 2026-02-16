// ignore_for_file: unused_field

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shital_video_editor/controllers/export_controller.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shital_video_editor/shared/logger_service.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class ExportPage extends StatelessWidget {
  ExportController get _exportController => Get.find<ExportController>();

  Future<void> _clearProjectData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('initialVideo');
    await prefs.remove('editedVideo');
  }

  void _exitWithOutput(BuildContext context) async {
    // Clear temporary project data before exiting
    await _clearProjectData();

    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.of(context, rootNavigator: true).pop(
        _exportController.compressedFile ?? File(_exportController.outputPath));
  }

  @override
  Widget build(BuildContext context) {
    try {
      final controller = _exportController;
      return Obx(
        () => Scaffold(
          // Hide the app bar when exporting the video.
          appBar: controller.isExporting.value ? null : _exportAppBar(context),
          body: controller.isExporting.value
              ? _loadingScreen(context)
              : controller.errorExporting.value
                  ? _errorExportingVideoScreen(context)
                  : _exportedVideoScreen(context),
        ),
      );
    } catch (e) {
      logger.error('ExportPage: CRASH in build: $e');
      return Scaffold(
        appBar: AppBar(title: const Text('Export Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Failed to initialize export',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  _exportAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // Don't show the leading button
      titleSpacing: 0,
      shape: const RoundedRectangleBorder(),
      title: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Get back to editor page
          ],
        ),
      ),
    );
  }

  _loadingScreen(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                _exportController.isCompressing.value
                    ? "Compressing Video..."
                    : translations.exportPageLoadingTitle.tr,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                _exportController.isCompressing.value
                    ? _exportController.progressLabel.value
                    : translations.exportPageLoadingSubtitle.tr,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16.0),
            CircularPercentIndicator(
              radius: 60.0,
              animateFromLastPercent: true,
              progressColor: Theme.of(context).colorScheme.primary,
              backgroundColor:
                  Theme.of(context).primaryColorLight.withOpacity(0.2),
              circularStrokeCap: CircularStrokeCap.round,
              percent: (_exportController.isCompressing.value
                      ? _exportController.compressionProgress.value
                      : _exportController.exportProgress.value)
                  .clamp(0.0, 1.0),
              center: Text(
                _exportController.isCompressing.value
                    ? "${(_exportController.compressionProgress.value * 100).toStringAsFixed(0)}%"
                    : '${(_exportController.exportProgress.value * 100).toStringAsFixed(2)}%',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _exportedVideoScreen(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitWithOutput(context);
    });
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text("Export Successful!"),
          ],
        ),
      ),
    );
  }

  _errorExportingVideoScreen(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exitWithOutput(context);
    });
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text("Export Failed"),
          ],
        ),
      ),
    );
  }
}
