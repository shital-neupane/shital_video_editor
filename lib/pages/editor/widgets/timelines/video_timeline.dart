import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shital_video_editor/controllers/editor_controller.dart';
import 'package:shital_video_editor/services/thumbnail_service.dart';
import 'package:shital_video_editor/shared/custom_painters.dart';
import 'package:shital_video_editor/shared/thumbnail_painter.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:get/get.dart';

class VideoTimeline extends StatefulWidget {
  const VideoTimeline({Key? key});

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

class _VideoTimelineState extends State<VideoTimeline> {
  ui.Image? _cachedSpriteSheet;
  String? _cachedPath;

  // Visual offsets for handles during trimming - accumulated drag distance
  double _startHandleVisualOffset = 0.0;
  double _endHandleVisualOffset = 0.0;

  // Store playhead position when starting to trim
  double _savedPlayheadPosition = 0.0;

  // Track if currently dragging
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  Future<ui.Image?> _loadSpriteSheet(String spriteSheetPath) async {
    if (spriteSheetPath.isEmpty) return null;

    // Return cached image if path hasn't changed
    if (_cachedPath == spriteSheetPath && _cachedSpriteSheet != null) {
      return _cachedSpriteSheet;
    }

    try {
      final file = File(spriteSheetPath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      _cachedSpriteSheet = frame.image;
      _cachedPath = spriteSheetPath;

      return frame.image;
    } catch (e) {
      print('Error loading sprite sheet: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditorController>(
      builder: (controller) {
        if (!controller.isVideoInitialized) {
          return const SizedBox.shrink();
        }

        final bool isInTrimMode =
            controller.selectedOptions == SelectedOptions.TRIM;

        // Timeline always shows only the trimmed portion
        double timelineWidth =
            ((controller.trimEnd - controller.trimStart) / 1000.0) *
                controller.timelineScale;

        // Handle positions: normally at edges, but shifted by visual offset during drag
        double startHandlePosition = _startHandleVisualOffset;
        double endHandlePosition = timelineWidth + _endHandleVisualOffset;

        // Base timeline widget with thumbnails
        Widget timelineContent = FutureBuilder<ui.Image?>(
          future: _loadSpriteSheet(controller.project.spriteSheetPath),
          builder: (context, snapshot) {
            final spriteSheet = snapshot.data;

            // Calculate sprite sheet metadata
            final fps =
                ThumbnailService.calculateOptimalFPS(controller.videoDuration);
            final thumbnailCount = ThumbnailService.getThumbnailCount(
                controller.videoDuration, fps);
            final gridSize = ThumbnailService.calculateGridSize(thumbnailCount);

            return Stack(
              children: [
                // Thumbnail layer - clips to only show content between trim handles
                if (spriteSheet != null)
                  CustomPaint(
                    painter: ThumbnailPainter(
                      spriteSheet: spriteSheet,
                      videoDuration: controller.videoDuration,
                      thumbnailCount: thumbnailCount,
                      columns: gridSize[0],
                      rows: gridSize[1],
                      timelineWidth: timelineWidth,
                      msTrimStart: controller.trimStart,
                      msTrimEnd: controller.trimEnd,
                      timelineScale: controller.timelineScale,
                      // Pass visual offsets for seamless clipping during drag
                      leftClipOffset: _startHandleVisualOffset,
                      rightClipOffset: _endHandleVisualOffset,
                    ),
                    size: Size(timelineWidth, 50.0),
                  ),
                // Overlay with trim painter and container
                CustomPaint(
                  painter: TrimPainterWithOffset(
                    controller.trimStart,
                    controller.trimEnd,
                    isTrimmingMode: isInTrimMode,
                    timelineScale: controller.timelineScale,
                    startOffset: _startHandleVisualOffset,
                    endOffset: _endHandleVisualOffset,
                    timelineWidth: timelineWidth,
                  ),
                  child: Container(
                    width: timelineWidth,
                    height: 50.0,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: const ui.Color.fromARGB(0, 255, 255, 255),
                        width: 2.0,
                      ),
                    ),
                    child: spriteSheet == null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.video_camera_back,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  controller.project.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        );

        // Create the base timeline widget
        Widget timelineWidget = timelineContent;

        // If in trim mode, use a Stack to overlay gesture detectors for handles
        if (isInTrimMode) {
          const double handleTouchWidth = 40.0;
          timelineWidget = Stack(
            clipBehavior: Clip.none,
            children: [
              timelineContent,
              // Start Handle Detector
              Positioned(
                left: startHandlePosition - (handleTouchWidth / 2),
                top: 0,
                bottom: 0,
                width: handleTouchWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {}, // Prevent toggle when tapping handle
                  onHorizontalDragStart: (_) {
                    _isDraggingStart = true;
                    _savedPlayheadPosition = controller.videoPosition;
                    _startHandleVisualOffset = 0.0;
                    controller.isTimelineScrollLocked = true;
                    controller.update();
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateTrimStartWithOffset(controller, details.delta.dx);
                  },
                  onHorizontalDragEnd: (_) {
                    _finishTrimStart(controller);
                  },
                  onHorizontalDragCancel: () {
                    _cancelTrim(controller);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              // End Handle Detector
              Positioned(
                left: endHandlePosition - (handleTouchWidth / 2),
                top: 0,
                bottom: 0,
                width: handleTouchWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {}, // Prevent toggle when tapping handle
                  onHorizontalDragStart: (_) {
                    _isDraggingEnd = true;
                    _savedPlayheadPosition = controller.videoPosition;
                    _endHandleVisualOffset = 0.0;
                    controller.isTimelineScrollLocked = true;
                    controller.update();
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateTrimEndWithOffset(controller, details.delta.dx);
                  },
                  onHorizontalDragEnd: (_) {
                    _finishTrimEnd(controller);
                  },
                  onHorizontalDragCancel: () {
                    _cancelTrim(controller);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          );
        }

        // Wrap with toggle detector (always active)
        timelineWidget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (controller.selectedOptions != SelectedOptions.TRIM) {
              controller.selectedOptions = SelectedOptions.TRIM;
            } else {
              controller.selectedOptions = SelectedOptions.BASE;
            }
          },
          child: timelineWidget,
        );

        return Container(
          color: Color(0xFF1A1A1A), // Dark grey background
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            children: [
              SizedBox(width: MediaQuery.of(context).size.width * 0.5 - 10.0),
              timelineWidget,
              SizedBox(width: MediaQuery.of(context).size.width * 0.5 - 10.0),
            ],
          ),
        );
      },
    );
  }

  void _updateTrimStartWithOffset(
      EditorController controller, double deltaPixels) {
    // Accumulate visual offset - this makes the handle appear to move
    double newOffset = _startHandleVisualOffset + deltaPixels;

    // Calculate what the new trimStart would be
    double proposedDeltaMs = (newOffset / controller.timelineScale) * 1000;
    int proposedNewStartMs = controller.trimStart + proposedDeltaMs.toInt();
    int currentEndMs = controller.trimEnd;

    // Apply constraints
    if (proposedNewStartMs < 0) {
      newOffset = (-controller.trimStart / 1000.0) * controller.timelineScale;
    }
    if (proposedNewStartMs >= currentEndMs - 100) {
      newOffset = ((currentEndMs - 100 - controller.trimStart) / 1000.0) *
          controller.timelineScale;
    }
    if (proposedNewStartMs < currentEndMs - EditorController.maxDurationMs) {
      newOffset = ((currentEndMs -
                  EditorController.maxDurationMs -
                  controller.trimStart) /
              1000.0) *
          controller.timelineScale;
    }

    _startHandleVisualOffset = newOffset;

    // Calculate new position for video preview
    int previewMs = controller.trimStart +
        ((newOffset / controller.timelineScale) * 1000).toInt();
    previewMs = previewMs.clamp(0, controller.videoDurationMs.toInt());
    controller.updateVideoPosition(previewMs / 1000.0);

    setState(() {});
  }

  void _updateTrimEndWithOffset(
      EditorController controller, double deltaPixels) {
    // Accumulate visual offset - this makes the handle appear to move
    double newOffset = _endHandleVisualOffset + deltaPixels;

    // Calculate what the new trimEnd would be
    double proposedDeltaMs = (newOffset / controller.timelineScale) * 1000;
    int proposedNewEndMs = controller.trimEnd + proposedDeltaMs.toInt();
    int currentStartMs = controller.trimStart;

    // Apply constraints
    if (proposedNewEndMs > controller.videoDurationMs) {
      newOffset = ((controller.videoDurationMs - controller.trimEnd) / 1000.0) *
          controller.timelineScale;
    }
    if (proposedNewEndMs <= currentStartMs + 100) {
      newOffset = ((currentStartMs + 100 - controller.trimEnd) / 1000.0) *
          controller.timelineScale;
    }
    if (proposedNewEndMs > currentStartMs + EditorController.maxDurationMs) {
      newOffset = ((currentStartMs +
                  EditorController.maxDurationMs -
                  controller.trimEnd) /
              1000.0) *
          controller.timelineScale;
    }

    _endHandleVisualOffset = newOffset;

    // Calculate new position for video preview
    int previewMs = controller.trimEnd +
        ((newOffset / controller.timelineScale) * 1000).toInt();
    previewMs = previewMs.clamp(0, controller.videoDurationMs.toInt());
    controller.updateVideoPosition(previewMs / 1000.0);

    setState(() {});
  }

  void _finishTrimStart(EditorController controller) {
    // Apply the accumulated offset to the actual trim value
    double deltaMs =
        (_startHandleVisualOffset / controller.timelineScale) * 1000;
    int newStartMs = controller.trimStart + deltaMs.toInt();

    // Apply final constraints
    newStartMs = newStartMs.clamp(0, controller.trimEnd - 100);
    if (newStartMs < controller.trimEnd - EditorController.maxDurationMs) {
      newStartMs = controller.trimEnd - EditorController.maxDurationMs;
    }

    controller.project.transformations.trimStart =
        Duration(milliseconds: newStartMs);

    _resetTrimState(controller);
  }

  void _finishTrimEnd(EditorController controller) {
    // Apply the accumulated offset to the actual trim value
    double deltaMs = (_endHandleVisualOffset / controller.timelineScale) * 1000;
    int newEndMs = controller.trimEnd + deltaMs.toInt();

    // Apply final constraints
    newEndMs = newEndMs.clamp(
        controller.trimStart + 100, controller.videoDurationMs.toInt());
    if (newEndMs > controller.trimStart + EditorController.maxDurationMs) {
      newEndMs = controller.trimStart + EditorController.maxDurationMs;
    }

    controller.project.transformations.trimEnd =
        Duration(milliseconds: newEndMs);

    _resetTrimState(controller);
  }

  void _cancelTrim(EditorController controller) {
    _resetTrimState(controller);
  }

  void _resetTrimState(EditorController controller) {
    // Reset visual offsets
    _startHandleVisualOffset = 0.0;
    _endHandleVisualOffset = 0.0;
    _isDraggingStart = false;
    _isDraggingEnd = false;

    // Restore playhead to safe position within trim range
    double restoredPosition = _savedPlayheadPosition;
    double trimStartSeconds = controller.trimStart / 1000.0;
    double trimEndSeconds = controller.trimEnd / 1000.0;

    // Clamp restored position to be within trim bounds
    if (restoredPosition < trimStartSeconds) {
      restoredPosition = trimStartSeconds;
    } else if (restoredPosition > trimEndSeconds) {
      restoredPosition = trimEndSeconds;
    }

    controller.updateVideoPosition(restoredPosition);
    controller.isTimelineScrollLocked = false;
    controller.update();
    setState(() {});
  }
}

/// Custom TrimPainter that supports visual offsets for handles during drag
class TrimPainterWithOffset extends CustomPainter {
  final int msTrimStart;
  final int msTrimEnd;
  final bool isTrimmingMode;
  final double timelineScale;
  final double startOffset;
  final double endOffset;
  final double timelineWidth;

  TrimPainterWithOffset(
    this.msTrimStart,
    this.msTrimEnd, {
    this.isTrimmingMode = false,
    this.timelineScale = 50.0,
    this.startOffset = 0.0,
    this.endOffset = 0.0,
    required this.timelineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Handle positions with offsets applied
    double startX = startOffset;
    double endX = timelineWidth + endOffset;

    // Instagram style frame color (Purple/Violet)
    const Color frameColor = Color(0xFF9C27B0); // Purple
    const double handleWidth = 20.0;
    const double lineWidth = 2.0;

    // Only draw the frame if in trimming mode
    if (isTrimmingMode) {
      Paint framePaint = Paint()
        ..color = frameColor
        ..style = PaintingStyle.fill;

      // Draw Start Handle (Thick vertical bar)
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(startX, 0, handleWidth, size.height),
          topLeft: const Radius.circular(8.0),
          bottomLeft: const Radius.circular(8.0),
        ),
        framePaint,
      );

      // Draw End Handle (Thick vertical bar)
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(endX - handleWidth, 0, handleWidth, size.height),
          topRight: const Radius.circular(8.0),
          bottomRight: const Radius.circular(8.0),
        ),
        framePaint,
      );

      // Draw Top line (connecting the two handles)
      double topLineStart = startX + handleWidth;
      double topLineWidth = endX - startX - handleWidth * 2;
      if (topLineWidth > 0) {
        canvas.drawRect(
          Rect.fromLTWH(topLineStart, 0, topLineWidth, lineWidth),
          framePaint,
        );
      }

      // Draw Bottom line (connecting the two handles)
      if (topLineWidth > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
              topLineStart, size.height - lineWidth, topLineWidth, lineWidth),
          framePaint,
        );
      }

      // Add a small detail: vertical grip lines on the thicker handles
      _drawGrip(canvas, Offset(startX + handleWidth / 2, size.height / 2),
          Colors.white38);
      _drawGrip(canvas, Offset(endX - handleWidth / 2, size.height / 2),
          Colors.white38);
    }
  }

  void _drawGrip(Canvas canvas, Offset center, Color color) {
    Paint gripPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw two vertical lines for grip on the thick handle
    for (int i = -1; i <= 1; i += 2) {
      double x = center.dx + (i * 4.0);
      canvas.drawLine(
        Offset(x, center.dy - 10),
        Offset(x, center.dy + 10),
        gripPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is TrimPainterWithOffset) {
      return msTrimStart != oldDelegate.msTrimStart ||
          msTrimEnd != oldDelegate.msTrimEnd ||
          isTrimmingMode != oldDelegate.isTrimmingMode ||
          startOffset != oldDelegate.startOffset ||
          endOffset != oldDelegate.endOffset ||
          timelineWidth != oldDelegate.timelineWidth;
    }
    return true;
  }
}
