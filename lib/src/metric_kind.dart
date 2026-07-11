import 'metrics.dart';

/// Describes one metric: how to read it, how to label it, its threshold key,
/// and whether a *higher* value is worse (complexity) or better
/// (maintainability index).
class MetricKind {
  const MetricKind({
    required this.key,
    required this.label,
    required this.read,
    required this.higherIsWorse,
  });

  /// Stable key, matching [Config.thresholds] keys.
  final String key;
  final String label;
  final double Function(Metrics) read;

  /// True for complexity-style metrics (min is best); false for the
  /// maintainability index (max is best).
  final bool higherIsWorse;

  /// Whether [value] violates [threshold] given this metric's direction.
  bool violates(double value, double threshold) =>
      higherIsWorse ? value > threshold : value < threshold;

  static const all = <MetricKind>[
    MetricKind(
        key: 'cyclomatic',
        label: 'Cyclomatic',
        read: _cyclo,
        higherIsWorse: true),
    MetricKind(
        key: 'cognitive',
        label: 'Cognitive',
        read: _cogn,
        higherIsWorse: true),
    MetricKind(key: 'npath', label: 'NPath', read: _npath, higherIsWorse: true),
    MetricKind(key: 'abc', label: 'ABC', read: _abc, higherIsWorse: true),
    MetricKind(
        key: 'halsteadBugs',
        label: 'Est. Bugs',
        read: _bugs,
        higherIsWorse: true),
    MetricKind(
        key: 'maintainability',
        label: 'Maintainability',
        read: _mi,
        higherIsWorse: false),
  ];

  static double _cyclo(Metrics m) => m.cyclomatic;
  static double _cogn(Metrics m) => m.cognitive;
  static double _npath(Metrics m) => m.npath;
  static double _abc(Metrics m) => m.abc;
  static double _bugs(Metrics m) => m.halsteadBugs;
  static double _mi(Metrics m) => m.maintainability;
}
