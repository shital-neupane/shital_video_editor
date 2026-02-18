import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/level.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
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

  ExportController({
    required this.command,
    required this.outputPath,
    required this.videoDuration,
  }) {
    logger.info('EXPORT_CTRL: Constructor called');
    logger.debug('EXPORT_CTRL: Received command: $command');
    logger.debug('EXPORT_CTRL: Received outputPath: $outputPath');
    logger.debug('EXPORT_CTRL: Received videoDuration: $videoDuration');
  }

  @override
  void onInit() async {
    logger.info('EXPORT_CTRL: onInit() started');
    super.onInit();

    try {
      // Start the export process after a small delay to allow navigation to settle
      logger.info('EXPORT_CTRL: Waiting for navigation to settle...');
      await Future.delayed(const Duration(milliseconds: 500));

      logger.info('EXPORT_CTRL: Starting _exportVideo()');
      _exportVideo();
    } catch (e, stackTrace) {
      logger.error('EXPORT_CTRL: CRITICAL ERROR in onInit: $e');
      logger.error('EXPORT_CTRL: StackTrace: $stackTrace');
      errorExporting.value = true;
      isExporting.value = false;
    }
  }

  _exportVideo() async {
    logger.info('EXPORT_CTRL: _exportVideo() execution started');
    logger.debug('EXPORT_CTRL: Command to execute: ffmpeg $command');

    try {
      // Execute the export command. Save the video to the gallery if the export is successful.
      await FFmpegKit.executeAsync(command, (Session session) async {
        final returnCode = await session.getReturnCode();
        logger.info(
            'EXPORT_CTRL: FFmpeg execution finished with return code: $returnCode');

        if (ReturnCode.isSuccess(returnCode)) {
          logger.info('EXPORT_CTRL: Export successful, saving to gallery...');
          SaverGallery.saveFile(
            filePath: outputPath,
            fileName: 'video_export',
            skipIfExists: false,
          ).then((saved) async {
            if (saved != null) {
              logger.info('EXPORT_CTRL: Saved to gallery successfully: $saved');
              isSavingToGallery.value = false;
            } else {
              logger
                  .warning('EXPORT_CTRL: SaverGallery.saveFile returned null');
            }

            // Start compression after saving to gallery and await completion
            logger.info('EXPORT_CTRL: Starting compression...');
            await _compressVideo();

            // Only mark export as complete after compression finishes
            logger.info('EXPORT_CTRL: Export and compression process complete');
            isExporting.value = false;
          }).catchError((error) {
            logger.error('EXPORT_CTRL: Error saving to gallery: $error');
            // Continue to compression even if gallery save fails?
            // For now, let's keep it consistent with original logic but add logging
            _compressVideo().then((_) => isExporting.value = false);
          });
        } else if (ReturnCode.isCancel(returnCode)) {
          logger.warning(
              'EXPORT_CTRL: VIDEO EXPORT CANCELLED ${session.getLogsAsString()}');
          isExporting.value = false;
        } else {
          // There was an error exporting the video
          logger.error('EXPORT_CTRL: FFmpeg execution FAILED');
          logs = await session.getLogs();
          for (var element in logs) {
            logger.error('EXPORT_CTRL: FFmpeg Log: ${element.getMessage()}');
          }
          isExporting.value = false;
          errorExporting.value = true;
        }
      }, (Log log) {
        // Reduced verbosity for debug logs unless it's an error
        if (log.getLevel() == Level.avLogFatal ||
            log.getLevel() == Level.avLogError) {
          logger.error('FFMPEG_LOG: ${log.getMessage()}');
        } else if (log.getLevel() == Level.avLogWarning) {
          logger.warning('FFMPEG_LOG: ${log.getMessage()}');
        }
        // logger.debug('${log.getMessage()}\n');
      }, (Statistics statistics) {
        if (statistics.getTime() > 0) {
          exportProgress.value =
              (statistics.getTime() / videoDuration).clamp(0.0, 1.0);
          // logger.debug('Progress: ${exportProgress.value * 100}%');
        }
      });
    } catch (e, stackTrace) {
      logger.error('EXPORT_CTRL: CRITICAL ERROR during FFmpeg execution: $e');
      logger.error('EXPORT_CTRL: StackTrace: $stackTrace');
      errorExporting.value = true;
      isExporting.value = false;
    }
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
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      // Debug: Log full result
      logger.debug("compressedMediaInfo: $compressedMediaInfo");
      logger.debug("compressedMediaInfo?.file: ${compressedMediaInfo?.file}");
      logger.debug("compressedMediaInfo?.path: ${compressedMediaInfo?.path}");

      if (compressedMediaInfo != null && compressedMediaInfo.file != null) {
        compressedFile = compressedMediaInfo.file;
        logger.info(
            "Video Compression Success: ${(compressedFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB");
      } else {
        logger
            .warning("Compression failed! MediaInfo was null or file was null");
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
