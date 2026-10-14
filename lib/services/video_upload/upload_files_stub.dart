// 網頁版沒有檔案系統：未完成上傳只記檔名與大小，續傳時請管理員重選檔案。

Future<String> moveIntoUploadDir(String path) async => path;

Future<bool> uploadFileMatches(String path, int size) async => false;

Future<void> deleteUploadFile(String path) async {}

Future<void> deleteOrphanUploadFiles(Set<String> keep) async {}
