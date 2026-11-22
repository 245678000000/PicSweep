<div align="center">

<img src="icon.png" width="128" alt="图片清理 icon">

# 图片清理 · PicSweep

**简约、轻量的 macOS 截图与图片清理工具**

一眼看清桌面和下载文件夹里堆了多少图片，按时间整理，点一下就清理。

[![Release](https://img.shields.io/github/v/release/245678000000/PicSweep?label=下载&color=6366f1)](https://github.com/245678000000/PicSweep/releases/latest)
![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/SwiftUI-原生-orange?logo=swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## ✨ 功能

| | |
|---|---|
| 📊 **一目了然** | 自动统计 **桌面**、**下载** 中的图片数量、截图数量和占用空间 |
| 🗂 **按时间分类** | 按天（今天 / 昨天 / 11月20日 周五…）或按月分组，每组显示数量与大小 |
| 📸 **识别截图** | 根据系统截图元数据和常见文件名（截屏、Screenshot、CleanShot…）识别截图 |
| 🗑 **一键删除** | 悬停点击 🗑 立即删除；也可多选、整组选中后批量删除 |
| 🔍 **应用内预览** | 双击放大，支持捏合 / 双击缩放、拖动查看、键盘切换 |
| ♻️ **安全可恢复** | 所有删除都是移到 **废纸篓**，误删随时找回 |
| ☁️ **支持 iCloud** | 兼容开启了「iCloud 桌面与文稿」的桌面文件 |
| 🪶 **原生轻量** | 纯 SwiftUI 编写，单文件源码，安装包约 1.4 MB，无任何第三方依赖 |

## 📦 安装

1. 前往 [Releases](https://github.com/245678000000/PicSweep/releases/latest) 下载 `PicSweep-x.y.z.zip`
2. 解压后将 **图片清理.app** 拖入「应用程序」文件夹
3. 首次打开：由于应用未经 Apple 公证，请 **右键点击 → 打开**，或在终端执行

   ```bash
   xattr -cr /Applications/图片清理.app
   ```

4. 首次扫描时，系统会请求访问「桌面」和「下载」文件夹，点击 **允许**

> 系统要求：macOS 14 Sonoma 及以上，Apple Silicon 与 Intel 通用。

## ⌨️ 使用

**主界面**

| 操作 | 说明 |
|---|---|
| 单击图片 | 选中 / 取消选中 |
| 双击图片 | 应用内放大预览 |
| 悬停 → 🗑 | 立即移到废纸篓 |
| 分组标题 →「选择本组」| 选中这一天 / 这个月的全部图片 |
| 右键 | 放大查看、用默认程序打开、在访达中显示、删除 |
| 左下角开关 | 是否包含子文件夹 |
| 左下角滑块 | 调整缩略图大小 |

**预览模式**

| 按键 | 说明 |
|---|---|
| `←` `→` | 上一张 / 下一张 |
| 双击 / 捏合 | 放大缩小（最高 8 倍），放大后可拖动 |
| `⌫` | 删除当前图片并自动跳到下一张 |
| `Esc` / `空格` | 关闭预览 |

## 🛠 从源码构建

只需要 Xcode Command Line Tools（无需完整 Xcode）：

```bash
xcode-select --install          # 如未安装
git clone https://github.com/245678000000/PicSweep.git
cd PicSweep
./build.sh                      # 生成通用二进制的 图片清理.app
open 图片清理.app
```

**项目结构**

```
PicSweep/
├── main.swift     # 全部应用代码（SwiftUI）
├── build.sh       # 编译、打包 .app、ad-hoc 签名
├── icon.swift     # 用 Core Graphics 绘制应用图标
├── icon.png       # 图标源图（1024×1024）
└── AppIcon.icns   # 打包用图标
```

修改图标后重新生成：

```bash
swift icon.swift icon.png
mkdir icon.iconset
for z in 16 32 128 256 512; do
  sips -z $z $z icon.png --out icon.iconset/icon_${z}x${z}.png
  sips -z $((z*2)) $((z*2)) icon.png --out icon.iconset/icon_${z}x${z}@2x.png
done
iconutil -c icns icon.iconset -o AppIcon.icns && rm -r icon.iconset
```

## ❓ 常见问题

<details>
<summary><b>删除时提示「没有权限」？</b></summary>

应用会先通过系统废纸篓接口删除，失败时自动交给访达处理（首次会询问是否允许控制「访达」，请点允许）。若仍失败，可在
**系统设置 → 隐私与安全性 → 完全磁盘访问权限** 中添加「图片清理」。

</details>

<details>
<summary><b>重新编译后又要重新授权？</b></summary>

本地构建使用 ad-hoc 签名，每次编译签名都会变化，系统会把它当作新应用，需要重新授权一次。

</details>

<details>
<summary><b>程序坞里还是旧图标？</b></summary>

macOS 会缓存图标。退出应用后执行 `killall Dock`，再重新打开即可。

</details>

## 🗺 路线图

- [ ] 重复 / 相似图片检测
- [ ] 按文件大小排序与筛选
- [ ] 自定义扫描文件夹（文稿、图片等）
- [ ] 菜单栏快捷入口
- [ ] 撤销上一次删除

欢迎提 [Issue](https://github.com/245678000000/PicSweep/issues) 和 Pull Request！

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源，可自由使用、修改和分发。
