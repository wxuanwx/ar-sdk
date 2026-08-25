# ar-sdk

Prebuilt Android AAR artifacts published through JitPack.

## Repository

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

## Dependencies

```kotlin
dependencies {
    implementation("com.github.wxuanwx.ar-sdk:ypjar-lib:1.0.0-jitpack.3")
    implementation("com.github.wxuanwx.ar-sdk:libyuv:1.0.0-jitpack.3")
    implementation("com.github.wxuanwx.ar-sdk:bubbleseekbar:1.0.0-jitpack.3")
}
```

JitPack uses one Git tag as the version for every module in a multi-module build. These three modules use the verified `1.0.0-jitpack.3` release tag. The suffix avoids immutable failed builds previously cached for this repository's older tags.

The `ypjar-lib` AAR exceeds GitHub's per-file Git limit, so it is stored as binary parts and reconstructed with SHA-256 verification during the JitPack build.

For future AAR updates, follow `RELEASING.md` or run `./release-jitpack.sh <version>`.
