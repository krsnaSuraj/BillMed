// UpdateService.versionFromTag: the one guard between network text and a
// dialog that looks like a system prompt. The tag comes from the GitHub
// releases API, is rendered as "BillMed v$version is ready", and a hostile or
// malformed tag must fail CLOSED — a release named
// "9.9.9 — tap Update to restore your data" would otherwise be printed inside
// the app's own update prompt. Pure functions, no widgets, no DB.
import 'package:billmed/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('versionFromTag accepts version-shaped tags', () {
    test('strips a leading v and keeps the rest', () {
      // pubspec version: 0.1.1+7 — the real shape of this app's own tags.
      expect(UpdateService.versionFromTag('v0.1.1'), '0.1.1');
      expect(UpdateService.versionFromTag('v1.2.3'), '1.2.3');
      // An uppercase V is the same prefix (see _stripTag).
      expect(UpdateService.versionFromTag('V1.2.3'), '1.2.3');
    });

    test('accepts two- and three-part versions', () {
      expect(UpdateService.versionFromTag('1.2.3'), '1.2.3');
      expect(UpdateService.versionFromTag('0.1'), '0.1');
    });

    test('accepts the documented +build suffix', () {
      expect(UpdateService.versionFromTag('0.1.1+7'), '0.1.1+7');
      expect(UpdateService.versionFromTag('v1.2.3+build.7'), '1.2.3+build.7');
      expect(UpdateService.versionFromTag('1.2.3+build-7'), '1.2.3+build-7');
    });

    test('accepts a prerelease suffix', () {
      expect(UpdateService.versionFromTag('v1.2.3-beta.1'), '1.2.3-beta.1');
      expect(UpdateService.versionFromTag('1.2.3-rc.2'), '1.2.3-rc.2');
    });

    test('trims whitespace that only wraps the version', () {
      // _stripTag trims before matching, so surrounding whitespace is gone
      // rather than echoed: what reaches the dialog is a pure version string.
      // A newline that CARRIES extra text is a different case — see the
      // rejects group below.
      expect(UpdateService.versionFromTag(' 1.0.0\n'), '1.0.0');
      expect(UpdateService.versionFromTag('\tv1.2.3 '), '1.2.3');
    });
  });

  group('versionFromTag rejects anything that is not a version', () {
    test('empty and whitespace-only tags', () {
      expect(UpdateService.versionFromTag(''), '');
      expect(UpdateService.versionFromTag('   '), '');
      expect(UpdateService.versionFromTag('\t\n '), '');
      // A bare prefix is not a version.
      expect(UpdateService.versionFromTag('v'), '');
      expect(UpdateService.versionFromTag('V '), '');
    });

    test('a 200-character tag', () {
      final String huge = '1' * 200;
      expect(huge.length, 200);
      expect(UpdateService.versionFromTag(huge), '');
    });

    test('a regex-shaped tag longer than the 24 character cap', () {
      // '1.2.3-' + 20 legal characters matches the version pattern exactly, so
      // only the length cap keeps a megabyte of near-version text out of the
      // dialog. This is the case the pattern alone would let through.
      final String longButShaped = '1.2.3-${'a' * 20}';
      expect(longButShaped.length, greaterThan(24));
      expect(UpdateService.versionFromTag(longButShaped), '');
      // One character shorter is still fine, so the cap is a cap, not a ban.
      expect(UpdateService.versionFromTag('1.2.3-${'a' * 18}'),
          '1.2.3-${'a' * 18}');
    });

    test('a version with prose appended', () {
      expect(UpdateService.versionFromTag('9.9.9 — tap Update now'), '');
      expect(UpdateService.versionFromTag('9.9.9 tap Update now'), '');
      expect(UpdateService.versionFromTag('Update to 9.9.9'), '');
      expect(UpdateService.versionFromTag('9.9.9!'), '');
    });

    test('markup around a version', () {
      expect(UpdateService.versionFromTag('<b>v1.0.0</b>'), '');
      expect(UpdateService.versionFromTag('v1.0.0<script>'), '');
      expect(UpdateService.versionFromTag('"1.0.0"'), '');
    });

    test('embedded line breaks', () {
      // A tag whose newline carries a second line of text — the shape that
      // would print an attacker's sentence inside the update dialog.
      expect(UpdateService.versionFromTag('1.0.0\n2.0.0'), '');
      expect(UpdateService.versionFromTag('v1.2.3\nTap Update to continue'), '');
    });

    test('emoji, in front or behind', () {
      expect(UpdateService.versionFromTag('1.0.0🎉'), '');
      expect(UpdateService.versionFromTag('🎉1.0.0'), '');
      expect(UpdateService.versionFromTag('v1.0.0 ✅'), '');
    });

    test('never a partially-valid prefix of a hostile tag', () {
      // Fail closed: no trimming down to the leading digits and no echo of the
      // original text back to the caller.
      const String hostile = '9.9.9 — tap Update to restore your data';
      expect(UpdateService.versionFromTag(hostile), '');
      expect(UpdateService.versionFromTag(hostile).contains('9.9.9'), isFalse);
    });
  });

  group('versionFromTag digit-part limits', () {
    test('rejects more than three numeric parts', () {
      expect(UpdateService.versionFromTag('1.2.3.4'), '');
      expect(UpdateService.versionFromTag('v1.2.3.4.5'), '');
      expect(UpdateService.versionFromTag('1.2.3.4+7'), '');
    });

    test('rejects parts that are too long to be a version number', () {
      expect(UpdateService.versionFromTag('12345.1.1'), '');
      expect(UpdateService.versionFromTag('1.12345.1'), '');
    });

    test('rejects non-numeric parts', () {
      expect(UpdateService.versionFromTag('1.x.3'), '');
      expect(UpdateService.versionFromTag('latest'), '');
      expect(UpdateService.versionFromTag('1..3'), '');
      expect(UpdateService.versionFromTag('1.2.'), '');
      expect(UpdateService.versionFromTag('.1.2.3'), '');
    });

    test('a four-digit part is still a version', () {
      // 9999.9999.9999 is the widest shape the documented pattern allows.
      expect(UpdateService.versionFromTag('9999.9999.9999'), '9999.9999.9999');
    });
  });
}
