# 設定 Deep Link

模板出貨的是**機制與 native 骨架**,網域是佔位符 `example.com`。本文說明
換成你的網域要動哪些地方。

Deep link 的 native 設定是那種「**一次做對就不用再碰、做錯就完全不會觸發
且沒有任何錯誤訊息**」的東西——所以驗證步驟比設定步驟更重要,請不要跳過。

## 1. 換掉網域

| 平台 | 檔案 | 改什麼 |
|---|---|---|
| Android | [`app/android/app/src/main/AndroidManifest.xml`](../../app/android/app/src/main/AndroidManifest.xml) | `<data android:host="example.com" />` |
| iOS | [`app/ios/Runner/Runner.entitlements`](../../app/ios/Runner/Runner.entitlements) | `applinks:example.com` |

**iOS 還要在 Xcode 引用 entitlements 檔**:開啟 `app/ios/Runner.xcworkspace`
→ Runner target → Signing & Capabilities → 加入 **Associated Domains**
capability。沒做這步的話 entitlements 檔存在也不會生效。

## 2. 上傳網站端的驗證檔

### Android:`https://<你的網域>/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "<你的 applicationId>",
    "sha256_cert_fingerprints": ["<簽章憑證的 SHA256>"]
  }
}]
```

取得 SHA256 指紋:

```bash
keytool -list -v -keystore <你的 keystore> -alias <你的 alias> | grep SHA256
```

**上架用的指紋與本機 debug 的不同。** Play Console 若啟用 App Signing,
要用的是 Google 重新簽章後的憑證指紋(Play Console → App integrity 可查)。

### iOS:`https://<你的網域>/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "details": [{
      "appIDs": ["<TeamID>.<BundleID>"],
      "components": [{ "/": "/home*" }]
    }]
  }
}
```

**這個檔不能有 `.json` 副檔名,且必須以 `application/json` 提供。**

## 3. 驗證

### Android

```bash
adb shell am start -a android.intent.action.VIEW -d "https://<你的網域>/home"
```

App 應該開啟並停在正確頁面(未登入時被登入守衛導去 login——**deep link
不繞過登入守衛**,這是刻意的)。

驗證 App Links 是否通過網域驗證:

```bash
adb shell pm get-app-links <你的 applicationId>
```

### iOS

**在備忘錄(Notes)App 裡貼上連結然後點它。**

**不要在 Safari 網址列直接輸入** —— 那不會觸發 Universal Link,只會開網頁。
這是「以為沒生效」最常見的原因,幾乎每個人都踩過一次。

## 4. 開放新頁面

要讓新頁面可被 deep link 進入,加進
[`ExternalAllowedRoutes.exact`](../../packages/core/lib/src/navigation/route_paths.dart)。

**推播與 deep link 共用同一份白名單。** 安全防護只蓋住一半等於沒蓋——
專案一開啟 deep link,只保護推播的白名單就被繞過了。

敏感操作頁(刪除、付款、確認類)一律不得列入。

## 已知缺口:暖啟動的 deep link

目前的校驗掛在 go_router 的 `redirect`,**只檢查第一次導航**(冷啟動的初始
路由)。App 已在背景執行時收到的 deep link 不會經過這層校驗。

刻意不用啟發式去猜「這次導航是不是外部來的」——猜錯會誤擋 App 內部導航,
那是比漏擋更難查的 bug。

真的需要覆蓋暖啟動時,做法是加 `app_links` 套件訂閱連結事件,在 handler 內
呼叫 `resolveExternalRoute()` 再 `context.go()`,與推播的 `_goIfAllowed()`
同一個形狀。本模板不預設加這個依賴。
