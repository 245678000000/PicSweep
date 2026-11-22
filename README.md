# 图片清理 PicSweep

<img src="icon.png" width="128" alt="icon">

一个简约的 macOS 小工具：扫描 **桌面** 和 **下载** 文件夹里的图片与截图，按时间分类浏览，一键移到废纸篓。

## 功能

- 统计桌面 / 下载 / 截图的数量与占用空间
- 按天、按月或不分组浏览，可整组选中
- 悬停点 🗑 直接删除，或多选批量删除（移到废纸篓，可恢复）
- 双击在应用内放大预览：← → 切换、捏合/双击缩放、⌫ 删除、Esc 关闭
- 支持 iCloud 桌面中的文件
- 可选包含子文件夹，缩略图大小可调

## 构建

需要 macOS 14+ 和 Xcode Command Line Tools：

```bash
./build.sh
open 图片清理.app
```

重新生成图标：`swift icon.swift icon.png`，然后用 `iconutil` 生成 `AppIcon.icns`。
