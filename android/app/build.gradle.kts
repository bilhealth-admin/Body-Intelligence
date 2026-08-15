import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
val hasReleaseSigning = releaseSigningPropertiesFile.isFile
val bilAdMobAndroidAppId = providers.gradleProperty("BIL_ADMOB_ANDROID_APP_ID")
    .orElse(providers.environmentVariable("BIL_ADMOB_ANDROID_APP_ID"))
    .orElse("ca-app-pub-0000000000000000~0000000000")

if (hasReleaseSigning) {
    FileInputStream(releaseSigningPropertiesFile).use(releaseSigningProperties::load)
    val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingKeys = requiredKeys.filter { releaseSigningProperties.getProperty(it).isNullOrBlank() }
    require(missingKeys.isEmpty()) {
        "Android release signing configuration is incomplete. Missing: ${missingKeys.joinToString()}"
    }
}

android {
    namespace = "com.bilhealth.bodyintelligencelog"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bilhealth.bodyintelligencelog"
        // Health Connect 1.1.0 requires Android 8.0 (API 26).
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["bilAdMobAndroidAppId"] = bilAdMobAndroidAppId.get()

        // BIL's release targets current 64-bit Android devices. The scanner's
        // legacy armeabi-v7a binary is 4 KB aligned, while its arm64-v8a and
        // x86_64 binaries satisfy Android's 16 KB page-size requirement.
        // Excluding the optional 32-bit ABI keeps the production bundle honest
        // and installable on current 16 KB devices without removing scanning.
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never sign a production release with the debug key. Until a private
            // key.properties file is supplied, Gradle produces an unsigned release.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            // Some AAR dependencies package optional 32-bit JNI binaries even
            // when Flutter targets only 64-bit ABIs. Exclude that ABI at the
            // final packaging boundary; equivalent 64-bit scanner binaries
            // remain packaged and are verified for 16 KB alignment.
            excludes += setOf("**/armeabi-v7a/**")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.health.connect:connect-client:1.1.0")
}
