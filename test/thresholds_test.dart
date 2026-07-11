import 'package:agnostic_code_metrics/src/analyzer.dart';
import 'package:agnostic_code_metrics/src/git.dart';
import 'package:agnostic_code_metrics/src/metrics.dart';
import 'package:agnostic_code_metrics/src/thresholds.dart';
import 'package:test/test.dart';

Metrics m({
  double cyclomatic = 1,
  double cognitive = 0,
  double maintainability = 100,
  double halsteadBugs = 0,
  double abc = 0,
  double npath = 1,
}) =>
    Metrics(
      cyclomatic: cyclomatic,
      cognitive: cognitive,
      maintainability: maintainability,
      halsteadBugs: halsteadBugs,
      abc: abc,
      npath: npath,
    );

FileReport report(String path, Metrics head) => FileReport(
      path: path,
      status: ChangeStatus.modified,
      head: head,
      base: null,
      delta: null,
    );

void main() {
  test('flags complexity metrics that exceed their max', () {
    final reports = [report('a.dart', m(cyclomatic: 20))];
    final v = evaluate(reports, {'cyclomatic': 10});
    expect(v, hasLength(1));
    expect(v.single.metric.key, 'cyclomatic');
    expect(v.single.value, 20);
  });

  test('maintainability flags values BELOW the minimum', () {
    final reports = [report('a.dart', m(maintainability: 40))];
    expect(evaluate(reports, {'maintainability': 50}), hasLength(1));
    expect(evaluate(reports, {'maintainability': 30}), isEmpty);
  });

  test('metrics without a configured threshold are never enforced', () {
    final reports = [report('a.dart', m(cyclomatic: 999, cognitive: 999))];
    expect(evaluate(reports, {'cyclomatic': 10}), hasLength(1));
  });

  test('delta subtraction reports the correct sign per metric', () {
    final head = m(cyclomatic: 12, maintainability: 55);
    final base = m(cyclomatic: 9, maintainability: 60);
    final d = head - base;
    expect(d.cyclomatic, 3);
    expect(d.maintainability, -5);
  });

  test('worstFile picks the highest cyclomatic complexity', () {
    final reports = [
      report('a.dart', m(cyclomatic: 5)),
      report('b.dart', m(cyclomatic: 42)),
      report('c.dart', m(cyclomatic: 8)),
    ];
    expect(worstFile(reports), 'b.dart');
    expect(worstFile([]), isNull);
  });
}
