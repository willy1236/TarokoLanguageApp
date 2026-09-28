import 'package:flutter_application_1/services/app_update/app_update_service.dart';
import 'package:flutter_application_1/services/app_update/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion v(String s) => AppVersion.tryParse(s)!;

void main() {
  group('AppVersion', () {
    test('先比名稱再比 build', () {
      expect(v('1.0.1') > v('1.0.0+99'), isTrue);
      expect(v('1.0.0+8') > v('1.0.0+7'), isTrue);
      expect(v('1.0').compareTo(v('1.0.0')), 0);
      expect(v('1.0.0').compareTo(v('1.0.0+7')), 0);
    });
    test('格式錯誤回傳 null', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });
  });

  group('pickUpdateVersion', () {
    final current = v('1.0.0+7');
    test('兩邊都查不到不提示', () {
      expect(pickUpdateVersion(current: current), isNull);
    });
    test('Remote Config build 較新就提示', () {
      expect(
        pickUpdateVersion(current: current, remote: v('1.0.0+8')).toString(),
        '1.0.0+8',
      );
    });
    test('等於或低於目前版本不提示', () {
      expect(pickUpdateVersion(current: current, remote: v('1.0.0+7')), isNull);
      expect(pickUpdateVersion(current: current, store: v('1.0.0')), isNull);
      expect(
        pickUpdateVersion(current: current, remote: v('0.9.0+20')),
        isNull,
      );
    });
    test('取兩者較新', () {
      expect(
        pickUpdateVersion(
          current: current,
          store: v('1.0.2'),
          remote: v('1.0.1+9'),
        ).toString(),
        '1.0.2',
      );
      expect(
        pickUpdateVersion(
          current: current,
          store: v('1.0.1'),
          remote: v('1.0.1+9'),
        ).toString(),
        '1.0.1+9',
      );
    });
    test('略過該版不提示，更新版本照常提示', () {
      expect(
        pickUpdateVersion(
          current: current,
          remote: v('1.0.0+8'),
          skipped: '1.0.0+8',
        ),
        isNull,
      );
      expect(
        pickUpdateVersion(
          current: current,
          remote: v('1.0.0+9'),
          skipped: '1.0.0+8',
        ).toString(),
        '1.0.0+9',
      );
    });
  });

  group('isUpdateRequired', () {
    final current = v('1.0.0+7');
    test('沒設最低版本時不強制', () {
      expect(isUpdateRequired(current: current), isFalse);
    });
    test('低於最低版本才強制', () {
      expect(isUpdateRequired(current: current, minimum: v('1.0.0+8')), isTrue);
      expect(isUpdateRequired(current: current, minimum: v('1.0.1')), isTrue);
    });
    test('等於或高於最低版本不強制', () {
      expect(
        isUpdateRequired(current: current, minimum: v('1.0.0+7')),
        isFalse,
      );
      expect(
        isUpdateRequired(current: current, minimum: v('1.0.0+6')),
        isFalse,
      );
      // 最低版本只寫版本名稱時，同名的任何 build 都算達標。
      expect(isUpdateRequired(current: current, minimum: v('1.0.0')), isFalse);
    });
  });

  group('decideUpdate', () {
    final current = v('1.0.0+7');
    const url = 'https://example.com/store';

    test('最低版本留空：行為同原本的提醒，可被略過', () {
      final update = decideUpdate(
        current: current,
        remote: v('1.0.0+8'),
        url: url,
      );
      expect(update!.required, isFalse);
      expect(update.version.toString(), '1.0.0+8');
      expect(
        decideUpdate(
          current: current,
          remote: v('1.0.0+8'),
          skipped: '1.0.0+8',
          url: url,
        ),
        isNull,
      );
    });

    test('低於最低版本：強制更新，不受略過紀錄影響', () {
      final update = decideUpdate(
        current: current,
        remote: v('1.0.0+9'),
        minimum: v('1.0.0+8'),
        skipped: '1.0.0+9',
        url: url,
      );
      expect(update!.required, isTrue);
      expect(update.version.toString(), '1.0.0+9');
    });

    test('低於最低版本但查不到最新版：版本至少是最低版本', () {
      final update = decideUpdate(
        current: current,
        minimum: v('1.0.0+8'),
        url: url,
      );
      expect(update!.required, isTrue);
      expect(update.version.toString(), '1.0.0+8');
    });

    test('最新版本比最低版本還舊（設定有誤）：版本取最低版本', () {
      final update = decideUpdate(
        current: current,
        store: v('1.0.0+8'),
        minimum: v('1.0.1'),
        url: url,
      );
      expect(update!.version.toString(), '1.0.1');
    });

    test('低於最低版本但沒有連結（iOS 沒設 update_url_ios）：仍然擋下', () {
      final update = decideUpdate(current: current, minimum: v('1.0.0+8'));
      expect(update!.required, isTrue);
      expect(update.url, isNull);
    });

    test('一般提醒沒有連結就不提示', () {
      expect(decideUpdate(current: current, remote: v('1.0.0+8')), isNull);
    });

    test('讀不到 Remote Config（沒有最低版本也沒有最新版）：不擋也不提示', () {
      expect(decideUpdate(current: current, url: url), isNull);
    });
  });
}
