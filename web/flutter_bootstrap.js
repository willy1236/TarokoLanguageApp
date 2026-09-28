{{flutter_js}}
{{flutter_build_config}}

// FlutterFire 預設在 Firebase.initializeApp 時注入 inline script 載入 Firebase
// JS SDK，會被網站的 CSP（firebase.json）擋下。這裡改從外部檔先載入，掛到
// window.firebase_*；firebase_core_web 看到 window.firebase_core 就不再注入。
// 版本要與 firebase_core_web 的 supportedFirebaseJsSdkVersion 一致
// （test/web/firebase_sdk_preload_test.dart 會檢查）。
const firebaseJsSdkVersion = '12.19.0';

async function loadFirebaseSdk() {
  const base = `https://www.gstatic.com/firebasejs/${firebaseJsSdkVersion}/`;
  // 先載 firebase-app.js 再載其他模組，理由同 firebase_core_web：同時 import 會在
  // Safari 觸發模組初始化競態。
  const core = await import(`${base}firebase-app.js`);
  // 預先載入時 FlutterFire 不會再注入任何服務，每個有註冊的服務都要在這裡載入。
  const [auth, remoteConfig, messaging] = await Promise.all([
    import(`${base}firebase-auth.js`),
    import(`${base}firebase-remote-config.js`),
    import(`${base}firebase-messaging.js`),
  ]);
  window.firebase_auth = auth;
  window.firebase_remote_config = remoteConfig;
  window.firebase_messaging = messaging;
  window.firebase_core = core;
}

const firebaseSdkReady = loadFirebaseSdk().catch((e) => {
  console.error('Firebase JS SDK 載入失敗', e);
});

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  // main.dart.js 照常平行下載，只有執行 Dart main 前等 SDK 就緒。
  onEntrypointLoaded: async (engineInitializer) => {
    await firebaseSdkReady;
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
