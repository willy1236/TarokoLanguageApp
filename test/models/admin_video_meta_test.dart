import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/admin_video_meta.dart';

void main() {
  group('AdminVideoMeta.toJson（建立用）', () {
    test('只輸出有值的欄位', () {
      expect(const AdminVideoMeta(category: 'cultural').toJson(), {
        'category': 'cultural',
      });
      expect(
        const AdminVideoMeta(
          title: '織布',
          description: '說明',
          category: 'cultural',
          tribeId: 3,
        ).toJson(),
        {
          'title': '織布',
          'description': '說明',
          'category': 'cultural',
          'tribe_id': 3,
        },
      );
    });

    test('空白字串視同沒填、前後空白去掉', () {
      expect(
        const AdminVideoMeta(
          title: '  ',
          description: ' 說明 ',
          category: 'other',
        ).toJson(),
        {'description': '說明', 'category': 'other'},
      );
    });
  });

  group('AdminVideoMeta.patchFrom（編輯用）', () {
    const original = AdminVideoMeta(
      title: '織布',
      description: '說明',
      category: 'cultural',
      tribeId: 3,
    );

    test('沒有改動回空 Map', () {
      expect(
        const AdminVideoMeta(
          title: '織布 ',
          description: '說明',
          category: 'cultural',
          tribeId: 3,
        ).patchFrom(original),
        isEmpty,
      );
    });

    test('只輸出改動的欄位', () {
      expect(
        const AdminVideoMeta(
          title: '新標題',
          description: '說明',
          category: '新分類',
          tribeId: 3,
        ).patchFrom(original),
        {'title': '新標題', 'category': '新分類'},
      );
    });

    test('說明、部落清掉時送 null', () {
      final patch = const AdminVideoMeta(
        title: '織布',
        description: ' ',
        category: 'cultural',
      ).patchFrom(original);
      expect(patch, {'description': null, 'tribe_id': null});
    });

    test('標題沒填不送（不能清空標題）', () {
      expect(
        const AdminVideoMeta(
          description: '說明',
          category: 'cultural',
          tribeId: 3,
        ).patchFrom(original),
        isEmpty,
      );
    });

    test('原本是空字串、現在也沒填，不算改動', () {
      expect(
        const AdminVideoMeta(title: 't', category: 'c').patchFrom(
          const AdminVideoMeta(title: 't', description: '', category: 'c'),
        ),
        isEmpty,
      );
    });
  });
}
