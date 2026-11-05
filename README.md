# 东来讲堂

一个观看胖东来百科中于东来相关视频的个人项目，包含 Android 和 macOS 客户端。目录和视频来自 [胖东来百科](https://baike.azpdl.net/)，播放需要网络；内容及服务的可用性取决于来源网站。

## 使用

从 [Releases](https://github.com/wangbrightly/donglai-video/releases) 下载对应版本。

- **Android**：需要 Android 8.0（API 26）或更高版本。安装 APK 后上下滑动切换视频；支持横屏、倍速、观看历史、进度续播和后台音频。首次安装可能需要允许从当前来源安装应用。
- **macOS**：需要 macOS 13 或更高版本。当前发布包适用于 Intel Mac；Apple Silicon 用户可以从源码构建。解压后打开应用，支持目录搜索、视频切换、倍速、进度续播和本地目录缓存。应用使用临时签名，未经过 Apple 公证，首次打开可能需要在系统设置中允许。

视频目录依据来源网站的分类及项目中的筛选规则生成，不能保证所有条目均符合预期。观看历史和播放位置保存在本机。

## 从源码构建

Android 版需要 Android SDK 36、兼容 Android Gradle Plugin 9.3.1 的 Gradle 和 JDK。配置本机 Android SDK 后，在项目根目录执行：

```sh
gradle :app:testDebugUnitTest :app:assembleDebug
```

APK 位于 `app/build/outputs/apk/debug/`。本仓库未包含 Gradle Wrapper；生成的 debug APK 使用本机调试密钥签名。

macOS 版需要 Swift 5.9 或更高版本和 Apple 命令行开发工具：

```sh
cd macOS
swift run
./scripts/build-app.sh
```

构建脚本生成 `macOS/build/东来讲堂.app`，使用本机临时签名。更多信息见 [macOS 说明](macOS/README.md)。

本项目是个人项目，与胖东来百科的关系未作声明；视频内容及相关权利归其各自权利人所有。
