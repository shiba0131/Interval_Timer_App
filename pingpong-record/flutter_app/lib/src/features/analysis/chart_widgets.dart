import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChartBarDatum {
  const ChartBarDatum({
    required this.label,
    required this.value,
    this.valueLabel,
    this.color,
  });

  final String label;
  final double value;
  final String? valueLabel;
  final Color? color;
}

class ChartLineSeries {
  const ChartLineSeries({
    required this.name,
    required this.points,
    required this.color,
  });

  final String name;
  final List<double> points;
  final Color color;
}

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 220,
    this.maxValue,
    this.minColumnWidth = 72,
  });

  final List<ChartBarDatum> data;
  final double height;
  final double? maxValue;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final resolvedMax = (maxValue ?? data
                .map((item) => item.value)
                .fold<double>(0, (max, value) => value > max ? value : max))
            .clamp(1, double.infinity)
        as double;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth =
            math.max(constraints.maxWidth, data.length * minColumnWidth).toDouble();
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                theme.colorScheme.surface.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: SizedBox(
              width: chartWidth,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ChartGridPainter(
                        lineColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.28),
                        horizontalLines: 4,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final item in data)
                        SizedBox(
                          width: chartWidth / data.length,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  item.valueLabel ?? item.value.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: item.value / resolvedMax,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(18),
                                            bottom: Radius.circular(6),
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              (item.color ?? theme.colorScheme.primary)
                                                  .withValues(alpha: 0.95),
                                              (item.color ?? theme.colorScheme.primary)
                                                  .withValues(alpha: 0.55),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (item.color ?? theme.colorScheme.primary)
                                                      .withValues(alpha: 0.18),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 240,
    this.minValue = 0,
    this.maxValue,
    this.minPointSpacing = 56,
  });

  final List<String> labels;
  final List<ChartLineSeries> series;
  final double height;
  final double minValue;
  final double? maxValue;
  final double minPointSpacing;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || series.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final values = [
      for (final line in series) ...line.points,
    ];
    final resolvedMax = (maxValue ??
            values.fold<double>(minValue, (max, value) => value > max ? value : max))
        .clamp(minValue + 1, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math.max(
          constraints.maxWidth,
          labels.length * minPointSpacing,
        ).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final line in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: line.color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(line.name, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
                    theme.colorScheme.surface.withValues(alpha: 0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: SizedBox(
                  width: chartWidth,
                  height: height,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      labels: labels,
                      series: series,
                      minValue: minValue,
                      maxValue: resolvedMax,
                      textStyle: theme.textTheme.bodySmall ??
                          const TextStyle(fontSize: 12, color: Colors.black54),
                      axisColor: theme.colorScheme.outlineVariant,
                      gridColor: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.35),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.labels,
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.textStyle,
    required this.axisColor,
    required this.gridColor,
  });

  final List<String> labels;
  final List<ChartLineSeries> series;
  final double minValue;
  final double maxValue;
  final TextStyle textStyle;
  final Color axisColor;
  final Color gridColor;

  static const _leftPad = 30.0;
  static const _rightPad = 12.0;
  static const _topPad = 12.0;
  static const _bottomPad = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      size.width - _leftPad - _rightPad,
      size.height - _topPad - _bottomPad,
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + (chartRect.height * i / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final value = maxValue - ((maxValue - minValue) * i / 3);
      _paintText(
        canvas,
        value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
        Offset(0, y - 8),
        maxWidth: _leftPad - 6,
        align: TextAlign.right,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    final pointCount = labels.length;
    if (pointCount == 1) {
      _paintSinglePointSeries(canvas, chartRect);
    } else {
      _paintMultiPointSeries(canvas, chartRect);
    }

    for (var i = 0; i < labels.length; i++) {
      final x = pointCount == 1
          ? chartRect.left + chartRect.width / 2
          : chartRect.left + chartRect.width * i / (pointCount - 1);
      final label = labels[i];
      _paintText(
        canvas,
        label,
        Offset(x - 24, chartRect.bottom + 8),
        maxWidth: 48,
      );
    }
  }

  void _paintSinglePointSeries(Canvas canvas, Rect chartRect) {
    final x = chartRect.left + chartRect.width / 2;
    for (final line in series) {
      final value = line.points.first;
      final y = _mapY(value, chartRect);
      final pointPaint = Paint()..color = line.color;
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  void _paintMultiPointSeries(Canvas canvas, Rect chartRect) {
    for (var lineIndex = 0; lineIndex < series.length; lineIndex++) {
      final line = series[lineIndex];
      final pointPaint = Paint()..color = line.color;
      final linePaint = Paint()
        ..color = line.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final points = <Offset>[];

      for (var i = 0; i < line.points.length; i++) {
        final x = chartRect.left + chartRect.width * i / (line.points.length - 1);
        final y = _mapY(line.points[i], chartRect);
        points.add(Offset(x, y));
      }

      final smoothPath = _buildSmoothPath(points);

      if (lineIndex == 0 && points.length > 1) {
        final areaPath = Path.from(smoothPath)
          ..lineTo(points.last.dx, chartRect.bottom)
          ..lineTo(points.first.dx, chartRect.bottom)
          ..close();
        final areaPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              line.color.withValues(alpha: 0.22),
              line.color.withValues(alpha: 0.02),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chartRect);
        canvas.drawPath(areaPath, areaPaint);
      }

      canvas.drawPath(smoothPath, linePaint);

      for (final point in points) {
        canvas.drawCircle(point, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 3.2, pointPaint);
      }
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    if (points.isEmpty) {
      return Path();
    }
    if (points.length < 3) {
      return Path()..addPolygon(points, false);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midPoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midPoint.dx, midPoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  double _mapY(double value, Rect chartRect) {
    final ratio = (value - minValue) / math.max(maxValue - minValue, 1);
    return chartRect.bottom - (chartRect.height * ratio);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    double maxWidth = 60,
    TextAlign align = TextAlign.center,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.series != series ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _ChartGridPainter extends CustomPainter {
  const _ChartGridPainter({
    required this.lineColor,
    required this.horizontalLines,
  });

  final Color lineColor;
  final int horizontalLines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var i = 1; i <= horizontalLines; i++) {
      final y = size.height * i / (horizontalLines + 1);
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.horizontalLines != horizontalLines;
  }
}
