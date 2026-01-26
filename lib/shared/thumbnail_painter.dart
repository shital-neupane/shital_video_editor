import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ThumbnailPainter extends CustomPainter {
  final ui.Image? spriteSheet;
  final double videoDuration;
  final int thumbnailCount;
  final int columns;
  final int rows;
  final double timelineWidth;
  final int msTrimStart;
  final int msTrimEnd;
  final double timelineScale;

  /// The left clip boundary (offset from start). Thumbnails before this point are hidden.
  final double leftClipOffset;

  /// The right clip boundary (offset from end). Thumbnails after this point are hidden.
  final double rightClipOffset;

  ThumbnailPainter({
    required this.spriteSheet,
    required this.videoDuration,
    required this.thumbnailCount,
    required this.columns,
    required this.rows,
    required this.timelineWidth,
    this.msTrimStart = 0,
    required this.msTrimEnd,
    this.timelineScale = 50.0,
    this.leftClipOffset = 0.0,
    this.rightClipOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spriteSheet == null || thumbnailCount == 0) return;

    // Calculate visible clip bounds based on trim handle positions
    // leftClipOffset is the position of the left handle (0 = at start, positive = moved right)
    // rightClipOffset is the offset from end (0 = at end, negative = moved left)
    double clipLeft = leftClipOffset.clamp(0.0, size.width);
    double clipRight =
        (size.width + rightClipOffset).clamp(clipLeft, size.width);

    // Clip to only show thumbnails between the trim handles
    // This creates the seamless masking effect during handle dragging
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(clipLeft, 0, clipRight - clipLeft, size.height));

    // Calculate thumbnail dimensions in the sprite sheet
    final double thumbnailWidth = spriteSheet!.width / columns;
    final double thumbnailHeight = spriteSheet!.height / rows;

    // Calculate trim bounds in seconds
    final double trimStartSec = msTrimStart / 1000.0;
    final double trimEndSec = msTrimEnd / 1000.0;
    final double trimDurationSec = trimEndSec - trimStartSec;

    if (trimDurationSec <= 0) return;

    // Each thumbnail in the sprite sheet covers this many seconds of video
    final double secondsPerThumbnail = videoDuration / thumbnailCount;

    // We want to fill size.width with trimDurationSec worth of video
    // So pixelsPerSecond = size.width / trimDurationSec
    final double pixelsPerSecond = size.width / trimDurationSec;

    // Width of each thumbnail on screen
    final double pixelsPerThumbnail = secondsPerThumbnail * pixelsPerSecond;

    // How many thumbnails to draw to fill the visible timeline
    final int thumbnailsToDraw =
        (trimDurationSec / secondsPerThumbnail).ceil() + 2;

    // Index of the first thumbnail to draw
    final int startThumbnailIdx = (trimStartSec / secondsPerThumbnail).floor();

    for (int i = 0; i < thumbnailsToDraw; i++) {
      final int thumbnailIdx = startThumbnailIdx + i;
      if (thumbnailIdx < 0) continue;
      if (thumbnailIdx >= thumbnailCount) break;

      // Time position of this thumbnail in seconds (absolute to video start)
      final double thumbTimeSec = thumbnailIdx * secondsPerThumbnail;

      // Position on screen (relative to trimStart)
      final double xPos = (thumbTimeSec - trimStartSec) * pixelsPerSecond;

      // Skip if completely outside visible bounds
      if (xPos + pixelsPerThumbnail < 0 || xPos > size.width) continue;

      // Get position in sprite sheet grid
      final int row = thumbnailIdx ~/ columns;
      final int column = thumbnailIdx % columns;

      // Source rectangle in sprite sheet
      Rect srcRect = Rect.fromLTWH(
        column * thumbnailWidth,
        row * thumbnailHeight,
        thumbnailWidth,
        thumbnailHeight,
      );

      // Destination rectangle on timeline
      Rect dstRect = Rect.fromLTWH(
        xPos,
        0,
        pixelsPerThumbnail,
        size.height,
      );

      // Draw the thumbnail
      canvas.drawImageRect(
        spriteSheet!,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // Restore canvas after clipping
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThumbnailPainter oldDelegate) {
    return spriteSheet != oldDelegate.spriteSheet ||
        videoDuration != oldDelegate.videoDuration ||
        thumbnailCount != oldDelegate.thumbnailCount ||
        msTrimStart != oldDelegate.msTrimStart ||
        msTrimEnd != oldDelegate.msTrimEnd ||
        timelineScale != oldDelegate.timelineScale ||
        leftClipOffset != oldDelegate.leftClipOffset ||
        rightClipOffset != oldDelegate.rightClipOffset;
  }
}
