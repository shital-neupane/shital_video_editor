import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  /// Calculate optimal FPS based on video duration
  /// Returns lower FPS for longer videos to limit thumbnail count
  static double calculateOptimalFPS(double durationSeconds) {
    if (durationSeconds <= 60) {
      // Short videos (≤1 min): 4 thumbnails per second for smooth zoom
      return 4.0;
    } else if (durationSeconds <= 300) {
      // Medium videos (1-5 min): 2 thumbnails per second
      return 2.0;
    } else if (durationSeconds <= 600) {
      // Long videos (5-10 min): 1 thumbnail per second
      return 1.0;
    } else {
      // Very long videos (>10 min): 1 thumbnail per 2 seconds
      return 0.5;
    }
  }

  /// Calculate total number of thumbnails based on duration and FPS
  static int getThumbnailCount(double durationSeconds, double fps) {
    return (durationSeconds * fps).ceil();
  }

  /// Calculate optimal grid size for sprite sheet
  /// Returns [columns, rows]
  static List<int> calculateGridSize(int thumbnailCount) {
    // Try to make a roughly square grid
    int columns = sqrt(thumbnailCount).ceil();
    int rows = (thumbnailCount / columns).ceil();
    return [columns, rows];
  }

  /// Generate sprite sheet for video thumbnails
  /// Returns the path to the generated sprite sheet, or null if failed
  static Future<String?> generateSpriteSheet({
    required String videoPath,
    required double durationSeconds,
    Function(double)? onProgress,
  }) async {
    try {
      // Calculate optimal parameters
      double fps = calculateOptimalFPS(durationSeconds);
      int thumbnailCount = getThumbnailCount(durationSeconds, fps);
      List<int> gridSize = calculateGridSize(thumbnailCount);
      int columns = gridSize[0];
      int rows = gridSize[1];

      // Get temporary directory for sprite sheet
      final tempDir = await getTemporaryDirectory();
      final spriteSheetPath =
          '${tempDir.path}/sprite_sheet_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // FFmpeg command to generate sprite sheet
      // - Extract frames at calculated FPS
      // - Scale to 50px height (matches timeline)
      // - Arrange in grid using tile filter
      // - q:v 5 = lower quality for faster generation (1-31, lower is better quality)
      final command = '-i "$videoPath" '
          '-vf "fps=$fps,scale=-1:50,tile=${columns}x$rows" '
          '-frames:v 1 '
          '-q:v 20 '
          '-threads 0 '
          '"$spriteSheetPath"';

      print(
          'Generating sprite sheet with $thumbnailCount thumbnails (${columns}x$rows grid)...');

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Sprite sheet generated successfully: $spriteSheetPath');
        final file = File(spriteSheetPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print(
              'Sprite sheet size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
          return spriteSheetPath;
        }
      } else {
        print('Failed to generate sprite sheet');
        final logs = await session.getAllLogsAsString();
        print('FFmpeg logs: $logs');
      }

      return null;
    } catch (e) {
      print('Error generating sprite sheet: $e');
      return null;
    }
  }

  /// Calculate which thumbnail index to display for a given time position
  static int getThumbnailIndex({
    required double timeInSeconds,
    required double videoDuration,
    required int totalThumbnails,
  }) {
    if (totalThumbnails <= 0 || videoDuration <= 0) return 0;

    double progress = (timeInSeconds / videoDuration).clamp(0.0, 1.0);
    int index = (progress * (totalThumbnails - 1)).floor();
    return index.clamp(0, totalThumbnails - 1);
  }

  /// Calculate the position of a thumbnail in the sprite sheet grid
  /// Returns [row, column]
  static List<int> getThumbnailPosition({
    required int thumbnailIndex,
    required int columns,
  }) {
    int row = thumbnailIndex ~/ columns;
    int column = thumbnailIndex % columns;
    return [row, column];
  }
}
