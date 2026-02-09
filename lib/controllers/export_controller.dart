import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:shital_video_editor/shared/helpers/ffmpeg.dart';
import 'package:shital_video_editor/shared/logger_service.dart';
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
        // Save to gallery first
        SaverGallery.saveFile(
          filePath: outputPath,
          fileName: 'video_export',
          skipIfExists: false,
        ).then((saved) async {
          if (saved != null) {
            isSavingToGallery.value = false;
          }
          // Start compression after saving to gallery and await completion
          await _compressVideo();
          // Only mark export as complete after compression finishes
          isExporting.value = false;
        });
      } else if (ReturnCode.isCancel(returnCode)) {
        logger.warning('VIDEO EXPORT CANCELLED ${session.getLogsAsString()}');
      } else {
        // There was an error exporting the video
        logs = await session.getLogs();
        for (var element in logs) {
          logger.error('${element.getMessage()}\n');
        }
        isExporting.value = false;
        errorExporting.value = true;
      }
    }, (Log log) {
      logger.debug('${log.getMessage()}\n');
    }, (Statistics statistics) {
      if (statistics.getTime() > 0) {
        exportProgress.value = statistics.getTime() / videoDuration;
        logger.debug('Progress: ${exportProgress.value * 100}%');
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

      // Debug: Check if input file exists
      final inputFile = File(outputPath);
      logger.debug("Input path: $outputPath");
      logger.debug("Input file exists: ${inputFile.existsSync()}");
      if (inputFile.existsSync()) {
        logger.debug(
            "Input file size: ${(inputFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB");
      }

      final compressedMediaInfo = await VideoCompress.compressVideo(
        outputPath,
        quality: VideoQuality.MediumQuality, // Try lower quality first
        deleteOrigin: false,
        includeAudio: true,
      );

      // Debug: Log full result
      logger.debug("compressedMediaInfo: $compressedMediaInfo");
      logger.debug(
          "compressedMediaInfo?.file: ${compressedMediaInfo?.file}");
      logger.debug(
          "compressedMediaInfo?.path: ${compressedMediaInfo?.path}");

      if (compressedMediaInfo != null && compressedMediaInfo.file != null) {
        compressedFile = compressedMediaInfo.file;
        logger.info(
            "Video Compression Success: ${(compressedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB");
      } else {
        logger.warning(
            "Compression failed! MediaInfo was null or file was null");
        // Fallback: use original file if compression fails
        compressedFile = inputFile;
        logger.debug("Fallback: Using original file instead");
      }
    } catch (e) {
      logger.error("Error during compression: $e");
    } finally {
      _compressionSubscription?.unsubscribe();
      isCompressing.value = false;
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
