import 'analyzer.dart';
import 'git.dart';
import 'metric_kind.dart';
import 'thresholds.dart';

/// Hidden HTML marker used to locate and update the sticky PR comment.
const marker = '<!-- agnostic-code-metrics -->';

/// Builds the Markdown report shown in the sticky PR comment and job summary.
String buildReport(
  List<FileReport> reports,
  List<Violation> violations,
  Map<String, double> thresholds,
) {
  final sb = StringBuffer()
    ..writeln(marker)
    ..writeln('## 📊 Code Metrics')
    ..writeln();

  if (reports.isEmpty) {
    sb.writeln('_No analysable source files changed in this pull request._');
    return sb.toString();
  }

  // Which (path, metricKey) pairs are in violation, for cell badges.
  final flagged = <String>{
    for (final v in violations) '${v.path}|${v.metric.key}'
  };

  final gate = violations.isEmpty
      ? '✅ **${reports.length}** file(s) analysed, no threshold violations'
      : '❌ **${violations.length}** violation(s) across '
          '**${reports.length}** file(s)';
  sb
    ..writeln(gate)
    ..writeln()
    ..writeln('| File | ${MetricKind.all.map((m) => m.label).join(' | ')} |')
    ..writeln('|------|${MetricKind.all.map((_) => ':--:').join('|')}|');

  final sorted = [...reports]..sort(_worstFirst(flagged));
  for (final r in sorted) {
    final cells = MetricKind.all.map((m) {
      final value = m.read(r.head);
      final delta = r.delta == null ? null : m.read(r.delta!);
      final badge = flagged.contains('${r.path}|${m.key}') ? ' ❌' : '';
      return '${_num(value)}${_delta(delta, m.higherIsWorse)}$badge';
    }).join(' | ');
    sb.writeln('| `${r.path}` ${_statusTag(r.status)} | $cells |');
  }

  sb
    ..writeln()
    ..writeln('<sub>Δ vs base · ▲/▼ value went up/down · 🟢 better · '
        '🔴 worse · Maintainability 0–100 '
        '(higher is better) · powered by '
        '[`rw_git`](https://pub.dev/packages/rw_git)</sub>');
  return sb.toString();
}

int Function(FileReport, FileReport) _worstFirst(Set<String> flagged) {
  int score(FileReport r) => MetricKind.all
      .where((m) => flagged.contains('${r.path}|${m.key}'))
      .length;
  return (a, b) {
    final byViolations = score(b).compareTo(score(a));
    if (byViolations != 0) return byViolations;
    return b.head.cyclomatic.compareTo(a.head.cyclomatic);
  };
}

String _statusTag(ChangeStatus status) => switch (status) {
      ChangeStatus.added => '🆕',
      ChangeStatus.renamed => '↪️',
      ChangeStatus.modified => '',
    };

String _num(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String _delta(double? d, bool higherIsWorse) {
  if (d == null || d.abs() < 0.005) return '';
  final worse = higherIsWorse ? d > 0 : d < 0;
  final color = worse ? '🔴' : '🟢';
  final arrow = d > 0 ? '▲' : '▼';
  final sign = d > 0 ? '+' : '−';
  return ' $color$arrow$sign${_num(d.abs())}';
}
