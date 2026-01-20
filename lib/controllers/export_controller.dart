import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:shital_video_editor/shared/helpers/ffmpeg.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_compress/video_compress.dart';
import 'dart:io';

class ExportController extends GetxController {
  static ExportController get to => Get.find();

  final String command;
  final String outputPath;
  final int videoDuration; // In milliseconds
  RxBool isExporting = true.obs;
  RxBool isSavingToGallery = true.obs;
  RxBool isCompressing = false.obs;
  RxDouble compressionProgress = 0.0.obs;
  RxString progressLabel = "".obs;
  RxBool errorExporting = false.obs;
  RxDouble exportProgress = 0.0.obs;
  List<Log> logs = [];
  File? compressedFile;
  Subscription? _compressionSubscription;

  ExportController(
      {required this.command,
      required this.outputPath,
      required this.videoDuration});

  @override
  void onInit() async {
    super.onInit();

    // Register fonts
    await registerFonts();

    // Start the export process
    _exportVideo();
  }

  _exportVideo() async {
    // Execute the export command. Save the video to the gallery if the export is successful.
    await FFmpegKit.executeAsync(command, (Session session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        isExporting.value = false;

        SaverGallery.saveFile(
          filePath: outputPath,
          fileName: 'video_export',
          skipIfExists: false,
        ).then((saved) {
          if (saved != null) {
            isSavingToGallery.value = false;
          }
          // Start compression after saving to gallery
          _compressVideo();
        });
      } else if (ReturnCode.isCancel(returnCode)) {
        print('VIDEO EXPORT CANCELLED ${session.getLogsAsString()}');
      } else {
        // There was an error exporting the video
        logs = await session.getLogs();
        for (var element in logs) {
          print('${element.getMessage()}\n');
        }
        isExporting.value = false;
        errorExporting.value = true;
      }
    }, (Log log) {
      print('${log.getMessage()}\n');
    }, (Statistics statistics) {
      if (statistics.getTime() > 0) {
        exportProgress.value = statistics.getTime() / videoDuration;
        print('Progress: ${exportProgress.value * 100}%');
      }
    });
  }

  Future<void> _compressVideo() async {
    isCompressing.value = true;
    compressionProgress.value = 0;
    progressLabel.value = "Compressing 0%";

    try {
      _compressionSubscription =
          VideoCompress.compressProgress$.subscribe((progress) {
        final p = progress / 100;
        compressionProgress.value = p;
        progressLabel.value = "Compressing ${progress.ceil()}%";
      });

      final compressedMediaInfo = await VideoCompress.compressVideo(
        outputPath,
        quality: VideoQuality.HighestQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedMediaInfo != null && compressedMediaInfo.file != null) {
        compressedFile = compressedMediaInfo.file;
        print(
            "Video Compression Success: ${(compressedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB");
      } else {
        print("Compression failed!");
      }
    } catch (e) {
      print("Error during compression: $e");
    } finally {
      _compressionSubscription?.unsubscribe();
      isCompressing.value = false;
      isExporting.value = false;
    }
  }

  void _cancelCompression() {
    VideoCompress.cancelCompression();
    _compressionSubscription?.unsubscribe();
  }

  @override
  void onClose() {
    _cancelCompression();
    super.onClose();
  }
}
