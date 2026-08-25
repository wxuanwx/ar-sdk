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
    implementation("com.github.wxuanwx.ar-sdk:ypjar-lib:1.0.0-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:libyuv:1.0.0-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:bubbleseekbar:1.0.0-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:breakpad-build:1.0.0-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:android-gif-drawable:1.2.28-jitpack.1")
    implementation("com.github.wxuanwx.ar-sdk:oaid-sdk:1.0.25-jitpack.1")
}
```

JitPack uses the requested Git tag as the version for every module in that build. Tags `1.0.0-jitpack.1`, `1.0.25-jitpack.1`, and `1.2.28-jitpack.1` point to the same artifact set. The suffix avoids immutable failed builds previously cached for this repository's older tags.

The `ypjar-lib` AAR exceeds GitHub's per-file Git limit, so it is stored as binary parts and reconstructed with SHA-256 verification during the JitPack build.
