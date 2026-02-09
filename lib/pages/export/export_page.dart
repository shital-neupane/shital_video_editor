// ignore_for_file: unused_field

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shital_video_editor/controllers/export_controller.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:percent_indicator/circular_percent_indicator.dart';

class ExportPage extends StatelessWidget {
  final ExportController _exportController = Get.put(
    ExportController(
      command: Get.arguments['command'],
      outputPath: Get.arguments['outputPath'],
      videoDuration: Get.arguments['videoDuration'],
    ),
  );

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
    return Obx(
      () => Scaffold(
        // Hide the app bar when exporting the video.
        appBar:
            _exportController.isExporting.value ? null : _exportAppBar(context),
        body: _exportController.isExporting.value
            ? _loadingScreen(context)
            : _exportController.errorExporting.value
                ? _errorExportingVideoScreen(context)
                : _exportedVideoScreen(context),
      ),
    );
  }

  _exportAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // Don't show the leading button
      titleSpacing: 0,
      shape: RoundedRectangleBorder(),
      title: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Get back to editor page
            // InkWell(
            //   onTap: () => Get.back(),
            //   highlightColor: Colors.transparent,
            //   splashFactory: NoSplash.splashFactory,
            //   child: Row(
            //     children: [
            //       Icon(Icons.keyboard_backspace, color: Theme.of(context).colorScheme.onBackground, size: 26.0),
            //       SizedBox(width: 4.0),
            //       Transform.rotate(
            //         angle: -90 * math.pi / 180,
            //         child: Icon(
            //           Icons.cut,
            //           color: Theme.of(context).colorScheme.onBackground,
            //           size: 26.0,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  _loadingScreen(BuildContext context) {
    return Obx(
      () => WillPopScope(
        onWillPop: () async => false,
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
            SizedBox(height: 8.0),
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
            SizedBox(height: 16.0),
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
    _exitWithOutput(context);
    return SizedBox();
    // return Padding(
    //   padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
    //   child: Column(
    //     children: [
    //       Expanded(
    //         child: Column(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           crossAxisAlignment: CrossAxisAlignment.stretch,
    //           children: [
    //             Text(translations.exportPageSuccessTitle.tr,
    //                 style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
    //             Image.asset(
    //               'assets/check.png',
    //               height: MediaQuery.of(context).size.width / 2.5,
    //               width: MediaQuery.of(context).size.width / 2.5,
    //             ),
    //             Text(
    //               translations.exportPageSuccessMessage.tr, // Changed from share message to success message
    //               style: Theme.of(context).textTheme.bodyMedium,
    //               textAlign: TextAlign.center,
    //             ),
    //             SizedBox(height: 12.0),
    //             Text(
    //               translations.exportPageFilePath.tr, // Add text to indicate file path
    //               style: Theme.of(context).textTheme.bodySmall,
    //               textAlign: TextAlign.center,
    //             ),
    //             Container(
    //               padding: EdgeInsets.all(12.0),
    //               margin: EdgeInsets.symmetric(horizontal: 16.0),
    //               decoration: BoxDecoration(
    //                 color: Theme.of(context).primaryColorLight.withOpacity(0.1),
    //                 border: Border.all(color: Theme.of(context).primaryColorLight, width: 1.0),
    //                 borderRadius: BorderRadius.circular(8.0),
    //               ),
    //               child: Text(
    //                 _exportController.outputPath,
    //                 style: Theme.of(context).textTheme.bodySmall,
    //                 textAlign: TextAlign.center,
    //                 overflow: TextOverflow.ellipsis,
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //       ElevatedButton(
    //         onPressed: () =>
    //         _exitWithOutput(context),

    //         style: ElevatedButton.styleFrom(
    //           backgroundColor: Theme.of(context).primaryColorLight,
    //           foregroundColor: Colors.white,
    //           padding: EdgeInsets.all(16),
    //           shape: RoundedRectangleBorder(
    //             side: BorderSide(color: Theme.of(context).primaryColorLight, width: 2.0),
    //             borderRadius: BorderRadius.circular(100.0),
    //           ),
    //         ),
    //         child: Text(
    //           translations.exportPageGoBack.tr, // Changed text
    //           style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }

  _errorExportingVideoScreen(BuildContext context) {
    _exitWithOutput(context);
    return SizedBox();
    // Padding(
    //   padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
    //   child: Column(
    //     children: [
    //       Expanded(
    //         child: Column(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           crossAxisAlignment: CrossAxisAlignment.stretch,
    //           children: [
    //             Text(translations.exportPageErrorTitle.tr,
    //                 style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
    //             SizedBox(height: 18.0),
    //             Image.asset(
    //               'assets/error.png',
    //               height: MediaQuery.of(context).size.width / 2.5,
    //               width: MediaQuery.of(context).size.width / 2.5,
    //             ),
    //             SizedBox(height: 18.0),
    //             Text(
    //               translations.exportPageErrorSubtitle.tr,
    //               style: Theme.of(context).textTheme.bodyMedium,
    //               textAlign: TextAlign.center,
    //             ),
    //             SizedBox(height: 18.0),
    //             Expanded(
    //               child: Container(
    //                 padding: EdgeInsets.all(16.0),
    //                 decoration: BoxDecoration(
    //                   color: Theme.of(context).primaryColorLight.withOpacity(0.1),
    //                   border: Border.all(color: Theme.of(context).primaryColorLight, width: 2.0),
    //                   borderRadius: BorderRadius.circular(16.0),
    //                 ),
    //                 child: SingleChildScrollView(
    //                   child: Column(
    //                     children: [
    //                       Text(
    //                         translations.exportPageErrorLogsTitle.tr,
    //                         style: Theme.of(context).textTheme.titleMedium,
    //                       ),
    //                       SizedBox(height: 8.0),
    //                       for (var log in _exportController.logs)
    //                         Text(
    //                           log.getMessage(),
    //                           style: Theme.of(context).textTheme.bodySmall,
    //                         ),
    //                       SizedBox(height: 18.0),
    //                       Text(
    //                         translations.exportPageErrorCommandTitle.tr,
    //                         style: Theme.of(context).textTheme.titleMedium,
    //                       ),
    //                       SizedBox(height: 8.0),
    //                       Text(
    //                         _exportController.command,
    //                         style: Theme.of(context).textTheme.bodySmall,
    //                       ),
    //                     ],
    //                   ),
    //                 ),
    //               ),
    //             ),
    //             SizedBox(height: 18.0)
    //           ],
    //         ),
    //       ),
    //       ElevatedButton(
    //          onPressed: () =>
    //         _exitWithOutput(context),
    //         // onPressed: () {
    //         //   // Get.back();

    //         //   Navigator.popUntil(context, (route)=>route.isFirst);
    //         //   }, // Go back to editor instead of home
    //         style: ElevatedButton.styleFrom(
    //           backgroundColor: Theme.of(context).primaryColorLight,
    //           foregroundColor: Colors.white,
    //           padding: EdgeInsets.all(16),
    //           shape: RoundedRectangleBorder(
    //             side: BorderSide(color: Theme.of(context).primaryColorLight, width: 2.0),
    //             borderRadius: BorderRadius.circular(100.0),
    //           ),
    //         ),
    //         child: Text(
    //           translations.exportPageGoBack.tr, // Changed text
    //           style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}
