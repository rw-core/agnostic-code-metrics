import 'package:agnostic_code_metrics/src/analyzer.dart';
import 'package:agnostic_code_metrics/src/git.dart';
import 'package:agnostic_code_metrics/src/metrics.dart';
import 'package:agnostic_code_metrics/src/report.dart';
import 'package:agnostic_code_metrics/src/thresholds.dart';
import 'package:test/test.dart';

Metrics _m(double cyclo, {double mi = 100}) => Metrics(
      cyclomatic: cyclo,
      cognitive: 0,
      maintainability: mi,
      halsteadBugs: 0,
      abc: 0,
      npath: 1,
    );

void main() {
  test('empty report is self-contained and marked', () {
    final md = buildReport([], [], {});
    expect(md, contains(marker));
    expect(md, contains('No analysable source files'));
  });

  test('renders a row per file, a delta arrow, and a violation badge', () {
    final reports = [
      FileReport(
        path: 'lib/a.dart',
        status: ChangeStatus.modified,
        head: _m(12),
        base: _m(9),
        delta: _m(12) - _m(9),
      ),
    ];
    final violations = evaluate(reports, {'cyclomatic': 10});
    final md = buildReport(reports, violations, {'cyclomatic': 10});

    expect(md, contains('`lib/a.dart`'));
    expect(md, contains('🔴▲')); // cyclomatic went up → worse
    expect(md, contains('❌')); // exceeds threshold
    expect(md, contains('**1** violation'));
  });

  test('improved maintainability shows the better arrow', () {
    final reports = [
      FileReport(
        path: 'lib/a.dart',
        status: ChangeStatus.added,
        head: _m(5, mi: 80),
        base: _m(5, mi: 70),
        delta: _m(5, mi: 80) - _m(5, mi: 70),
      ),
    ];
    final md = buildReport(reports, [], {});
    expect(md, contains('🟢▲+10')); // MI up by 10 → up arrow, green
    expect(md, contains('🆕')); // added-file tag
  });
}
