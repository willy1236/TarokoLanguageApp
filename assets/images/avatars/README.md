# 頭像素材 (Avatars)

把頭像圖片直接丟進這個資料夾就好，不用改 `pubspec.yaml`（已經用資料夾方式註冊，新檔案會自動被打包）。

## 規格建議
- 格式：PNG（透明背景）或 JPG
- 尺寸：正方形，建議 512x512（會裁切成圓形顯示，並可能疊上 [頭像框](../frames/README.md)）
- 命名：`avatar_<主題或編號>.png`，例如：
  - `avatar_default_01.png`
  - `avatar_animal_fox.png`

## 注意
- 第一次新增檔案後，若 app 沒吃到，執行一次 `flutter pub get` 再重新跑 app。
- 檔案大小盡量控制在幾百 KB 以內。
