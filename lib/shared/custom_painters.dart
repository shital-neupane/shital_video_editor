import 'package:flutter/material.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:get/get.dart';

class LinePainter extends CustomPainter {
  final double videoPosition;

  LinePainter(this.videoPosition);

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0;

    // Draw a vertical line at the center
    canvas.drawLine(Offset(size.width / 2, -5),
        Offset(size.width / 2, size.height), linePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class TrimPainter extends CustomPainter {
  final int msTrimStart;
  final int msTrimEnd;
  final bool isTrimmingMode;
  final double timelineScale;
  final bool fullVideoMode;

  TrimPainter(this.msTrimStart, this.msTrimEnd,
      {this.isTrimmingMode = false,
      this.timelineScale = 50.0,
      this.fullVideoMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    // In fullVideoMode: handles at absolute positions based on trim values
    // In normal mode: handles at 0 and size.width (relative to trimmed duration)
    double startX;
    double endX;

    if (fullVideoMode) {
      // Absolute positions based on trim values
      startX = (msTrimStart / 1000.0) * timelineScale;
      endX = (msTrimEnd / 1000.0) * timelineScale;
    } else {
      // Relative positions at edges
      startX = 0;
      endX = size.width;
    }

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
      canvas.drawRect(
        Rect.fromLTWH(startX + handleWidth, 0, endX - startX - handleWidth * 2,
            lineWidth),
        framePaint,
      );

      // Draw Bottom line (connecting the two handles)
      canvas.drawRect(
        Rect.fromLTWH(startX + handleWidth, size.height - lineWidth,
            endX - startX - handleWidth * 2, lineWidth),
        framePaint,
      );

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
    if (oldDelegate is TrimPainter) {
      return msTrimStart != oldDelegate.msTrimStart ||
          msTrimEnd != oldDelegate.msTrimEnd ||
          isTrimmingMode != oldDelegate.isTrimmingMode ||
          timelineScale != oldDelegate.timelineScale ||
          fullVideoMode != oldDelegate.fullVideoMode;
    }
    return true;
  }
}

class DragHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Theme.of(Get.context!).colorScheme.onBackground.withOpacity(0.2)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    const double handleWidth = 60.0;
    const double handleHeight = 6.0;

    // Draw the rounded rectangle handle
    final RRect handleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: handleWidth,
        height: handleHeight,
      ),
      Radius.circular(handleHeight / 2),
    );
    canvas.drawRRect(handleRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class RoundedProgressBarPainter extends CustomPainter {
  final double msMaxAudioDuration;
  final double currentPosition;

  RoundedProgressBarPainter({
    required this.msMaxAudioDuration,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color =
          Theme.of(Get.context!).primaryColorLight // Color of the progress bar
      ..style = PaintingStyle.fill;

    double progressBarHeight = 40.0;
    double borderRadius = progressBarHeight / 4;
    double progressBarWidth =
        (msMaxAudioDuration / 1000) * 12.0; // 12 pixels per second

    // Adjust the y-coordinate to position the bars at the bottom of the container
    double startY = size.height - progressBarHeight + 6.0;

    // Draw the background bar with border
    RRect backgroundBar = RRect.fromLTRBR(
      0,
      startY,
      progressBarWidth,
      size.height,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(backgroundBar, Paint()..color = Colors.transparent);

    // Draw the progress bar with border
    double progressWidth =
        (currentPosition / msMaxAudioDuration) * progressBarWidth;
    RRect progressBar = RRect.fromLTRBR(
      0,
      startY,
      progressWidth,
      size.height,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(progressBar, paint);

    Paint borderPaint = Paint()
      ..color =
          Theme.of(Get.context!).colorScheme.onBackground // Color of the border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; // Width of the border
    canvas.drawRRect(backgroundBar, borderPaint);
  }

  @override
  bool shouldRepaint(covariant RoundedProgressBarPainter oldDelegate) {
    return oldDelegate.msMaxAudioDuration != msMaxAudioDuration ||
        oldDelegate.currentPosition != currentPosition;
  }
}

class CropGridPainter extends CustomPainter {
  CropAspectRatio aspectRatio;

  CropGridPainter(this.aspectRatio);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw the grid
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width / 3 * i, 0),
          Offset(size.width / 3 * i, size.height), paint);
      canvas.drawLine(Offset(0, size.height / 3 * i),
          Offset(size.width, size.height / 3 * i), paint);
    }

    // Draw the border
    paint.strokeWidth = 2.0;
    canvas.drawRect(Offset.zero & size, paint);

    // Draw white filled cirles handles in the corners
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(0, 0), 5, paint);
    canvas.drawCircle(Offset(size.width, 0), 5, paint);
    canvas.drawCircle(Offset(0, size.height), 5, paint);
    canvas.drawCircle(Offset(size.width, size.height), 5, paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5, paint);

    // Draw little white filled squares in the middle of the sides. Only if the aspect ratio is free.
    if (aspectRatio == CropAspectRatio.FREE) {
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(size.width / 2 - 5, -5, 10, 10), paint);
      canvas.drawRect(Rect.fromLTWH(-5, size.height / 2 - 5, 10, 10), paint);
      canvas.drawRect(
          Rect.fromLTWH(size.width - 5, size.height / 2 - 5, 10, 10), paint);
      canvas.drawRect(
          Rect.fromLTWH(size.width / 2 - 5, size.height - 5, 10, 10), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return (oldDelegate as CropGridPainter).aspectRatio != aspectRatio;
  }
}

class CropPainter extends CustomPainter {
  double x;
  double y;
  double width;
  double height;

  CropPainter(
      {required this.x,
      required this.y,
      required this.width,
      required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    Paint fillPaint = Paint()..color = Colors.black.withOpacity(0.4);
    canvas.drawRect(Rect.fromLTWH(0, 0, x, size.height), fillPaint); // Left
    canvas.drawRect(Rect.fromLTWH(x, 0, size.width - x, y), fillPaint); // Top
    canvas.drawRect(
        Rect.fromLTWH(x + width, y, size.width - (x + width), size.height - y),
        fillPaint); // Right
    canvas.drawRect(
        Rect.fromLTWH(x, y + height, width, size.height - (y + height)),
        fillPaint); // Bottom

    // Draw white border
    Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTRB(x, y, x + width, y + height), borderPaint);

    // Draw crop corners with white color.
    borderPaint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(x - 2, y, 4, 12), borderPaint);
    canvas.drawRect(Rect.fromLTWH(x - 2, y - 2, 14, 4), borderPaint);
    canvas.drawRect(Rect.fromLTWH(x + width - 2, y, 4, 12), borderPaint);
    canvas.drawRect(Rect.fromLTWH(x + width - 12, y - 2, 14, 4), borderPaint);
    canvas.drawRect(Rect.fromLTWH(x - 2, y + height - 12, 4, 12), borderPaint);
    canvas.drawRect(Rect.fromLTWH(x - 2, y + height - 2, 14, 4), borderPaint);
    canvas.drawRect(
        Rect.fromLTWH(x + width - 2, y + height - 12, 4, 12), borderPaint);
    canvas.drawRect(
        Rect.fromLTWH(x + width - 12, y + height - 2, 14, 4), borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
