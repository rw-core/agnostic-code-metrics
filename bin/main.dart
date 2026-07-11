import 'dart:io';

import 'package:agnostic_code_metrics/src/analyzer.dart';
import 'package:agnostic_code_metrics/src/config.dart';
import 'package:agnostic_code_metrics/src/git.dart';
import 'package:agnostic_code_metrics/src/github.dart';
import 'package:agnostic_code_metrics/src/report.dart';
import 'package:agnostic_code_metrics/src/thresholds.dart';

Future<void> main() async {
  final env = Platform.environment;
  final config = Config.fromEnvironment(env);

  final shas = GitRepo.readPrShas(env['GITHUB_EVENT_PATH']);
  if (shas == null) {
    stderr.writeln('agnostic-code-metrics: not a pull_request event; '
        'nothing to analyse.');
    return;
  }

  final repo = GitRepo(config.workspace);
  final changed = repo.changedFiles(
    base: shas.base,
    head: shas.head,
    include: config.include,
    exclude: config.exclude,
  );

  final reports = analyze(changed);
  final violations = evaluate(reports, config.thresholds);
  final report = buildReport(reports, violations, config.thresholds);

  // 1. Job summary (always).
  GitHub.writeStepSummary(report);

  // 2. Action outputs.
  GitHub.writeOutputs({
    'violation-count': '${violations.length}',
    'worst-file': worstFile(reports) ?? '',
  });

  // 3. Sticky PR comment.
  if (config.comment && config.token.isNotEmpty) {
    final number = GitHub.prNumber(env['GITHUB_EVENT_PATH']);
    final repository = env['GITHUB_REPOSITORY'];
    if (number != null && repository != null) {
      final gh = GitHub(token: config.token, repository: repository);
      try {
        await gh.upsertStickyComment(number, report);
      } catch (e) {
        stderr.writeln('agnostic-code-metrics: failed to post comment: $e');
      } finally {
        gh.close();
      }
    }
  }

  stdout.writeln('agnostic-code-metrics: analysed ${reports.length} file(s), '
      '${violations.length} violation(s).');

  // 4. Quality gate.
  if (config.failOnViolation && violations.isNotEmpty) {
    exitCode = 1;
  }
}
