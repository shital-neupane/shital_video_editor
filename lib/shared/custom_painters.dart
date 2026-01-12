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

  TrimPainter(this.msTrimStart, this.msTrimEnd, {this.isTrimmingMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the x-coordinates for trim start and trim end lines
    double startX = (msTrimStart / 1000) * 50.0;
    double endX = (msTrimEnd / 1000) * 50.0;

    endX = endX.clamp(0.0, size.width);
    startX = startX.clamp(0.0, size.width);

    // Draw the background region that is trimmed out (before start and after end)
    if (startX > 0) {
      drawRoundedRectangleWithOpacity(
          canvas, 0.0, startX, Colors.black.withOpacity(0.15), size, true);
    }

    if (endX < size.width) {
      drawRoundedRectangleWithOpacity(canvas, endX, size.width,
          Colors.black.withOpacity(0.15), size, false);
    }

    // Draw trim start handle only if it's within the visible range
    if (startX >= 0 && startX <= size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX, size.height),
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2.0,
      );

      // Draw a handle if in trimming mode
      if (isTrimmingMode) {
        drawHandle(canvas, Offset(startX, size.height / 2), Colors.red);
      } else {
        drawTriangle(
          canvas,
          Offset(startX, 1),
          Colors.red,
          false, // pointing down
        );
      }
    }

    // Draw trim end handle only if it's within the visible range
    if (endX >= 0 && endX <= size.width) {
      canvas.drawLine(
        Offset(endX, 0),
        Offset(endX, size.height),
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2.0,
      );

      // Draw a handle if in trimming mode
      if (isTrimmingMode) {
        drawHandle(canvas, Offset(endX, size.height / 2), Colors.blue);
      } else {
        drawTriangle(
          canvas,
          Offset(endX, 1),
          Colors.blue,
          false,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is TrimPainter) {
      return msTrimStart != oldDelegate.msTrimStart ||
          msTrimEnd != oldDelegate.msTrimEnd ||
          isTrimmingMode != oldDelegate.isTrimmingMode;
    }
    return true;
  }

  void drawTriangle(
      Canvas canvas, Offset position, Color color, bool pointingDown) {
    final path = Path();
    const triangleHeight = 6.0;

    if (pointingDown) {
      path.moveTo(position.dx, position.dy);
      path.lineTo(position.dx - triangleHeight, position.dy + triangleHeight);
      path.lineTo(position.dx + triangleHeight, position.dy + triangleHeight);
    } else {
      path.moveTo(position.dx, position.dy);
      path.lineTo(position.dx - triangleHeight, position.dy - triangleHeight);
      path.lineTo(position.dx + triangleHeight, position.dy - triangleHeight);
    }

    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void drawHandle(Canvas canvas, Offset position, Color color) {
    // Draw a symmetric rectangular handle centered on the trim line
    double handleWidth = 18.0; // 3x the original 6.0
    double handleHeight = 30.0;

    // Draw white background rectangle centered on position
    Paint handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Rect handleRect = Rect.fromLTWH(
      position.dx - handleWidth / 2,
      position.dy - handleHeight / 2,
      handleWidth,
      handleHeight,
    );

    RRect roundedHandle = RRect.fromRectAndRadius(
      handleRect,
      Radius.circular(4.0),
    );
    canvas.drawRRect(roundedHandle, handlePaint);

    // Add a colored indicator stripe in the center
    Paint indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Rect indicatorRect = Rect.fromLTWH(
      position.dx - 2.0,
      position.dy - handleHeight / 2 + 4,
      4.0,
      handleHeight - 8,
    );

    RRect roundedIndicator = RRect.fromRectAndRadius(
      indicatorRect,
      Radius.circular(2.0),
    );
    canvas.drawRRect(roundedIndicator, indicatorPaint);

    // Draw arrows on both sides to indicate draggable direction
    Paint arrowPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    double arrowSize = 4.0;
    double gapFromCenter = 4.0; // Gap between arrow and center trim line

    // Left arrow
    Path leftArrowPath = Path();
    double leftArrowX = position.dx - gapFromCenter - arrowSize;
    leftArrowPath.moveTo(leftArrowX, position.dy);
    leftArrowPath.lineTo(leftArrowX + arrowSize, position.dy - arrowSize);
    leftArrowPath.lineTo(leftArrowX + arrowSize, position.dy + arrowSize);
    leftArrowPath.close();
    canvas.drawPath(leftArrowPath, arrowPaint);

    // Right arrow
    Path rightArrowPath = Path();
    double rightArrowX = position.dx + gapFromCenter + arrowSize;
    rightArrowPath.moveTo(rightArrowX, position.dy);
    rightArrowPath.lineTo(rightArrowX - arrowSize, position.dy - arrowSize);
    rightArrowPath.lineTo(rightArrowX - arrowSize, position.dy + arrowSize);
    rightArrowPath.close();
    canvas.drawPath(rightArrowPath, arrowPaint);
  }

  void drawRoundedRectangleWithOpacity(Canvas canvas, double start, double end,
      Color color, Size size, bool isStart) {
    final radius = Radius.circular(10.0);
    final rect = RRect.fromRectAndCorners(
      Rect.fromPoints(Offset(start, 0), Offset(end, size.height)),
      topLeft: isStart ? radius : Radius.zero,
      topRight: isStart ? Radius.zero : radius,
      bottomLeft: isStart ? radius : Radius.zero,
      bottomRight: isStart ? Radius.zero : radius,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
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
