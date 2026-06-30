# Google 登入除錯筆記：SHA-1 指紋設定

## 症狀

點擊「Google 登入」後，選完 Google 帳號，App 卡在 loading（按鈕一直轉圈），
不會跳出明確錯誤訊息，或要很久才以「使用者取消登入」收尾。

## 根因

Google 登入流程會由 Google 的伺服器檢查「目前這支 APK 的簽章指紋（SHA-1）」
是否有登記在 Firebase / Google Cloud Console 的 OAuth client 設定裡
（對應 `android/app/google-services.json` 裡每個 `oauth_client` 項目的
`certificate_hash`）。如果指紋沒登記，授權會在背景被擋下，部分情況下
`google_sign_in` 套件不會立刻丟出例外，而是讓 `signIn()` 的 Future
長時間不 resolve，UI 就停在 loading 狀態。

驗證方式：比對本機 debug keystore 的 SHA-1，跟
`android/app/google-services.json` 裡 `certificate_hash` 是否一致：

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

（Windows 路徑：`C:\Users\<使用者>\.android\debug.keystore`）

## SHA-1 是怎麼來的

第一次在某台機器上跑 `flutter run` / debug build 時，Gradle 會自動產生
（若不存在）一把 debug 簽章金鑰 `~/.android/debug.keystore`
（固定密碼 `android`/`android`，alias `androiddebugkey`）。debug build
都用這把金鑰簽章，所以**每台開發機器的 debug SHA-1 天生不同**（除非團隊
共用同一把 keystore）。

## 多人協作怎麼處理

不需要每人各自一份 `google-services.json`。正確做法：

1. 每位開發者各自跑上面的 `keytool` 指令，算出自己的 debug SHA-1
2. 全部加進 Firebase Console →專案設定 → 該 Android app → 「SHA 憑證指紋」
   （此欄位可以登記多筆，debug 跟 release 都可以並存）
3. 加完後重新下載**同一份** `google-services.json`（內含所有已登記指紋對應
   的 `oauth_client`），覆蓋 `android/app/google-services.json`，全隊共用
   這一份檔案即可

替代方案是把同一把 `debug.keystore` commit 進 repo 讓全隊共用，這樣只要
登記一筆 SHA-1，但安全性較弱、CI 環境通常也是用獨立的 debug keystore，
故多數情況建議「每人指紋各自登記」。

## 修復步驟

1. Firebase Console → 專案設定 → Android app
   （`tw.idv.willy1236.truku`）→ 新增 SHA 憑證指紋
2. 貼上 `keytool` 算出的 SHA-1
3. 重新下載新的 `google-services.json`，覆蓋
   `android/app/google-services.json`
4. `flutter clean` 後重新建置
