// 下架影片（後台影片 T-08）：archiveVideo 的端點與回傳值（規格範例，不打正式 API）。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/services/admin_service.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/widget_test_helpers.dart';

const _archivePath = '/api/admin/videos/7/archive';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  group('AdminService.archiveVideo', () {
    late List<http.Request> requests;

    void mockArchive(String fixture) {
      requests = [];
      installMockClient({
        _archivePath: loadSpecFixtureMap(fixture),
      }, onRequest: requests.add);
    }

    test('POST 不帶 body，檔案刪乾淨回 true', () async {
      mockArchive('post_api_admin_videos_archive.json');
      expect(await AdminService.archiveVideo(7), isTrue);
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, _archivePath);
      expect(r.body, isEmpty);
    });

    test('files_deleted: false 回 false', () async {
      mockArchive('post_api_admin_videos_archive_files_not_deleted.json');
      expect(await AdminService.archiveVideo(7), isFalse);
    });
  });
}
