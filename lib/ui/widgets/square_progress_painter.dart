import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SquareProgressPainter extends CustomPainter {
  final Color color;
  final double percentage;

  SquareProgressPainter({required this.color, required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final lineLength = size.width * 2 + size.height * 2;
    double lineOffset = lineLength * percentage;

    List<Offset> points = [];

    if (lineOffset > 0) {
      // bottom right to top right
      final p1 = Offset(size.width, size.height);

      double height = 0;

      if (lineOffset > size.height) {
        height = size.height;
        lineOffset -= size.height;
      } else {
        height = lineOffset;
        lineOffset = 0;
      }
      final p2 = Offset(
        size.width,
        size.height - height,
      );
      points.add(p1);
      points.add(p2);
    }

    if (lineOffset > 0) {
      // top right to top left
      final p1 = Offset(size.width, 0);

      double width = 0;

      if (lineOffset > size.width) {
        width = size.width;
        lineOffset -= size.width;
      } else {
        width = lineOffset;
        lineOffset = 0;
      }
      final p2 = Offset(
        size.width - width,
        0,
      );
      points.add(p1);
      points.add(p2);
    }

    if (lineOffset > 0) {
      // top left to bottom left
      const p1 = Offset(0, 0);

      double height = 0;

      if (lineOffset > size.height) {
        height = size.height;
        lineOffset -= size.height;
      } else {
        height = lineOffset;
        lineOffset = 0;
      }
      final p2 = Offset(
        0,
        height,
      );
      points.add(p1);
      points.add(p2);
    }

    if (lineOffset > 0) {
      // bottom left to bottom right
      final p1 = Offset(0, size.height);

      double width = 0;

      if (lineOffset > size.width) {
        width = size.width;
        lineOffset -= size.width;
      } else {
        width = lineOffset;
        lineOffset = 0;
      }
      final p2 = Offset(
        width,
        size.height,
      );
      points.add(p1);
      points.add(p2);
    }

    canvas.drawPoints(ui.PointMode.lines, points, paint);
  }

  @override
  bool shouldRepaint(SquareProgressPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.percentage != percentage;
  }
}
