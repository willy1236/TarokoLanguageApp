# 頭像框素材 (Avatar Frames)

把頭像框圖片直接丟進這個資料夾就好，不用改 `pubspec.yaml`（已經用資料夾方式註冊，新檔案會自動被打包）。

## 規格建議
- 格式：PNG（透明背景）或 SVG
- 尺寸：正方形，建議 512x512（會疊在圓形頭像上）
- 命名：`frame_<主題或稀有度>_<編號>.png`，例如：
  - `frame_gold_01.png`
  - `frame_limited_lunar.png`

## 注意
- 第一次新增檔案後，若 app 沒吃到，執行一次 `flutter pub get` 再重新跑 app。
- 檔案大小盡量控制在幾百 KB 以內；素材數量或畫質大幅增加時再考慮改用 SVG 或 Git LFS（不是現階段必要）。
