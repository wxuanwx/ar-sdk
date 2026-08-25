# JitPack AAR 更新发布指南

本仓库只发布三个模块：

| 本地文件 | JitPack 模块 |
| --- | --- |
| `ypjar-lib-release.aar` | `ypjar-lib` |
| `libyuv-debug.aar` | `libyuv` |
| `bubbleseekbar-release.aar` | `bubbleseekbar` |

## 一键发布

1. 克隆并进入仓库。
2. 用新文件覆盖根目录下同名 AAR，文件名不要修改。
3. 执行：

```bash
./release-jitpack.sh 1.0.1
```

参数 `1.0.1` 是三个 AAR 的统一发布版本。脚本会自动查找未使用的标签：

```text
1.0.1-jitpack.1
1.0.1-jitpack.2
```

不要重复使用或强制覆盖已经触发过 JitPack 的标签。失败修复后再次运行脚本，它会自动选择下一个 `.N` 标签。

`jitpack-tag-history.txt` 永久记录所有使用过的 JitPack 标签。即使 GitHub 上删除了失败标签，也不要删除这里的历史记录，因为 JitPack 仍可能缓存旧构建。

## 脚本自动完成的工作

- 检查三个 AAR 是否存在。
- 重新计算并保存 SHA-256 到 `artifacts.sha256`。
- 将较大的 `ypjar-lib-release.aar` 分片，并验证重组文件一致。
- 更新 `README.md` 中的依赖版本。
- 在临时目录模拟 JitPack 安装，检查三个 Maven 模块。
- 提交修改、创建唯一 Git 标签并推送到 GitHub。
- 请求 JitPack 触发构建，自动等待标签同步和构建完成。
- 从 JitPack 下载三个发布后的 AAR，逐个核对 SHA-256。

## 只准备不发布

如果只想生成分片、校验文件和 README，暂时不提交或推送：

```bash
./release-jitpack.sh 1.0.1 --prepare-only
```

该模式会修改工作区文件，但不会创建 Git 提交、标签或访问 JitPack。

## 项目引用

先添加 JitPack 仓库：

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io") {
            content {
                includeGroup("com.github.wxuanwx.ar-sdk")
            }
        }
    }
}
```

假设脚本最终输出标签 `1.0.1-jitpack.1`：

```kotlin
dependencies {
    implementation("com.github.wxuanwx.ar-sdk:ypjar-lib:1.0.1-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:libyuv:1.0.1-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:bubbleseekbar:1.0.1-jitpack.1")
}
```

三个模块必须使用同一个 Git 标签版本。

## 文件职责

- `artifacts.conf`：AAR 文件名、模块名和存储方式的唯一清单。
- `artifacts.sha256`：当前三个原始 AAR 的 SHA-256。
- `jitpack-tag-history.txt`：所有已使用标签的永久记录，防止复用 JitPack 缓存标签。
- `jitpack-install.sh`：JitPack 构建机执行的安装脚本。
- `release-jitpack.sh`：维护者本地执行的一键发布脚本。
- `pom.xml` 与各模块 `pom.xml`：让 JitPack 识别 Maven 多模块结构。

## 常见问题

### Tag or commit not found

GitHub 标签刚推送后，JitPack 可能需要短时间同步。发布脚本会自动重试。

### Build failed

不要修复后覆盖原标签。再次运行发布脚本，它会选择新的 `.N` 标签。

### GitHub 提示文件超过 100 MB

不要直接提交 `ypjar-lib-release.aar`。发布脚本会提交 `ypjar-lib-release.aar.part-*` 分片，JitPack 构建时自动重组并校验。

### 本地校验成功但远端文件不一致

脚本会在发布后下载全部三个 AAR 并核验 SHA-256；任何不一致都会以失败状态退出，不能将该标签用于正式项目。
