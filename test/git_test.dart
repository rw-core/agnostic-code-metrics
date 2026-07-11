import 'package:agnostic_code_metrics/src/git.dart';
import 'package:test/test.dart';

void main() {
  group('isSourceFile', () {
    test('recognises common source extensions', () {
      expect(GitRepo.isSourceFile('lib/a.dart'), isTrue);
      expect(GitRepo.isSourceFile('src/app.ts'), isTrue);
      expect(GitRepo.isSourceFile('main.py'), isTrue);
    });
    test('rejects non-source and extensionless files', () {
      expect(GitRepo.isSourceFile('README.md'), isFalse);
      expect(GitRepo.isSourceFile('data.json'), isFalse);
      expect(GitRepo.isSourceFile('Makefile'), isFalse);
    });
  });

  group('matches', () {
    test('empty include allows everything not excluded', () {
      expect(
          GitRepo.matches('lib/a.dart', include: [], exclude: []), isTrue);
    });
    test('exclude glob with ** spans directories', () {
      expect(
          GitRepo.matches('pkg/test/a_test.dart',
              include: [], exclude: ['**/test/**']),
          isFalse);
    });
    test('single star does not cross a slash', () {
      expect(GitRepo.matches('a/b.dart', include: ['*.dart'], exclude: []),
          isFalse);
      expect(GitRepo.matches('b.dart', include: ['*.dart'], exclude: []),
          isTrue);
    });
    test('include must match to keep the file', () {
      expect(GitRepo.matches('src/a.py', include: ['lib/**'], exclude: []),
          isFalse);
      expect(GitRepo.matches('lib/x/a.py', include: ['lib/**'], exclude: []),
          isTrue);
    });
    test('generated-file glob matches a suffix pattern', () {
      expect(
          GitRepo.matches('lib/model.g.dart',
              include: [], exclude: ['**/*.g.dart']),
          isFalse);
    });
  });
}
