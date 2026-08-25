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
    implementation("com.github.wxuanwx.ar-sdk:ypjar-lib:v1.0.0")
    implementation("com.github.wxuanwx.ar-sdk:libyuv:v1.0.0")
    implementation("com.github.wxuanwx.ar-sdk:bubbleseekbar:v1.0.0")
    implementation("com.github.wxuanwx.ar-sdk:breakpad-build:v1.0.0")
    implementation("com.github.wxuanwx.ar-sdk:android-gif-drawable:v1.2.28")
    implementation("com.github.wxuanwx.ar-sdk:oaid-sdk:v1.0.25")
}
```

JitPack uses the requested Git tag as the version for every module in that build. Tags `v1.0.0`, `v1.0.25`, and `v1.2.28` point to the same artifact set so each dependency can retain its existing version number.

The `ypjar-lib` AAR exceeds GitHub's per-file Git limit, so it is stored as binary parts and reconstructed with SHA-256 verification during the JitPack build.
