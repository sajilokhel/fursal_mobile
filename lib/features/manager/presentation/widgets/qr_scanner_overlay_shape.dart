import 'package:flutter/material.dart';

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;

    // Calculate cut-out rect
    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutSize / 2 + borderOffset,
      rect.top +
          height / 2 -
          cutOutSize / 2 +
          borderOffset -
          cutOutBottomOffset,
      cutOutSize - borderOffset * 2,
      cutOutSize - borderOffset * 2,
    );

    // Draw Overlay
    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(
          RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw Border Corners
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final borderPath = Path();

    // Top left
    borderPath.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    borderPath.lineTo(cutOutRect.left, cutOutRect.top);
    borderPath.lineTo(cutOutRect.left + borderLength, cutOutRect.top);

    // Top right
    borderPath.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    borderPath.lineTo(cutOutRect.right, cutOutRect.top);
    borderPath.lineTo(cutOutRect.right, cutOutRect.top + borderLength);

    // Bottom right
    borderPath.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    borderPath.lineTo(cutOutRect.right, cutOutRect.bottom);
    borderPath.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);

    // Bottom left
    borderPath.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    borderPath.lineTo(cutOutRect.left, cutOutRect.bottom);
    borderPath.lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
      borderRadius: borderRadius,
      borderLength: borderLength,
      cutOutSize: cutOutSize,
      cutOutBottomOffset: cutOutBottomOffset,
    );
  }
}
