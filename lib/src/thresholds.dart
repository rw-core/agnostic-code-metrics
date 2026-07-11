import 'analyzer.dart';
import 'metric_kind.dart';

/// A single metric on a single file breaching its configured threshold.
class Violation {
  const Violation({
    required this.path,
    required this.metric,
    required this.value,
    required this.threshold,
  });

  final String path;
  final MetricKind metric;
  final double value;
  final double threshold;
}

/// Evaluates every file's head metrics against the configured thresholds.
/// Only metrics present in [thresholds] are enforced.
List<Violation> evaluate(
    List<FileReport> reports, Map<String, double> thresholds) {
  final violations = <Violation>[];
  for (final report in reports) {
    for (final metric in MetricKind.all) {
      final threshold = thresholds[metric.key];
      if (threshold == null) continue;
      final value = metric.read(report.head);
      if (metric.violates(value, threshold)) {
        violations.add(Violation(
          path: report.path,
          metric: metric,
          value: value,
          threshold: threshold,
        ));
      }
    }
  }
  return violations;
}

/// The file with the highest cyclomatic complexity at head, or null if empty.
String? worstFile(List<FileReport> reports) {
  if (reports.isEmpty) return null;
  final sorted = [...reports]
    ..sort((a, b) => b.head.cyclomatic.compareTo(a.head.cyclomatic));
  return sorted.first.path;
}
