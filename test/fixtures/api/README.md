# API fixtures

這裡放的是**後端真實回應的快照**，由 `integration_test/api_inspector_test.dart`
在實機／模擬器上錄製、經 PII 遮罩後產生，是前端對後端格式的契約基準。

不要手寫這些檔案。手寫等於用「我以為的格式」取代「後端實際的格式」，
那正是這套機制要防的事。

## 錄製 / 重錄

```bash
flutter test integration_test/api_inspector_test.dart -d <device_id> \
    --dart-define=RECORD_FIXTURES=true > fixtures.log
dart run tool/extract_fixtures.dart fixtures.log
```

錄完 `git diff` 這個資料夾就能看出後端這次改了什麼。

## 誰在用

`test/contract/api_contract_test.dart` 把每個 fixture 餵進對應的
`lib/models/*.dart` `fromJson`。後端改格式 → 重錄 → 測試紅在確切的 model 上。
未錄製的端點會 skip，不會假裝通過。

## 遮罩

遮罩名單在 `integration_test/helpers/contract.dart` 的 `_stringMasks`。
遮罩會保留原本的型別與結構（字串換成固定假值、null 維持 null），
確保 fixture 仍能被 `fromJson` 正常解析。
新增會回傳個資的端點時，記得同步補遮罩欄位，並在 commit 前檢查 diff。
