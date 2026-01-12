import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shital_video_editor/services/thumbnail_service.dart';

class ThumbnailPainter extends CustomPainter {
  final ui.Image? spriteSheet;
  final double videoDuration;
  final int thumbnailCount;
  final int columns;
  final int rows;
  final double timelineWidth;

  ThumbnailPainter({
    required this.spriteSheet,
    required this.videoDuration,
    required this.thumbnailCount,
    required this.columns,
    required this.rows,
    required this.timelineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spriteSheet == null || thumbnailCount == 0) return;

    // Calculate thumbnail dimensions in the sprite sheet
    final double thumbnailWidth = spriteSheet!.width / columns;
    final double thumbnailHeight = spriteSheet!.height / rows;

    // Calculate how many thumbnails to draw across the timeline
    // Timeline is 50px per second, but cap at actual video duration
    final int maxThumbnails = (timelineWidth / 50).ceil();
    final int thumbnailsForDuration = videoDuration.ceil();
    final int thumbnailsToDraw = maxThumbnails < thumbnailsForDuration
        ? maxThumbnails
        : thumbnailsForDuration;

    for (int i = 0; i < thumbnailsToDraw; i++) {
      // Calculate time position for this thumbnail
      double timeInSeconds = i.toDouble();

      // Get the thumbnail index from the sprite sheet
      int thumbnailIndex = ThumbnailService.getThumbnailIndex(
        timeInSeconds: timeInSeconds,
        videoDuration: videoDuration,
        totalThumbnails: thumbnailCount,
      );

      // Get position in sprite sheet grid
      List<int> position = ThumbnailService.getThumbnailPosition(
        thumbnailIndex: thumbnailIndex,
        columns: columns,
      );
      int row = position[0];
      int column = position[1];

      // Source rectangle in sprite sheet
      Rect srcRect = Rect.fromLTWH(
        column * thumbnailWidth,
        row * thumbnailHeight,
        thumbnailWidth,
        thumbnailHeight,
      );

      // Destination rectangle on timeline
      Rect dstRect = Rect.fromLTWH(
        i * 50.0,
        0,
        50.0,
        size.height,
      );

      // Draw the thumbnail
      canvas.drawImageRect(
        spriteSheet!,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ThumbnailPainter oldDelegate) {
    return spriteSheet != oldDelegate.spriteSheet ||
        videoDuration != oldDelegate.videoDuration ||
        thumbnailCount != oldDelegate.thumbnailCount;
  }
}
