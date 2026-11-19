import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Flutter's --target-platform limits Flutter engine artifacts, but Android
// plugin AARs can still contribute JNI libraries for every ABI. Mirror the
// requested Flutter target in Gradle so an ARM64 APK cannot package x86 or
// 32-bit native libraries. Leave the filters unset for universal builds.
val flutterTargetAbis = mapOf(
    "android-arm" to "armeabi-v7a",
    "android-arm64" to "arm64-v8a",
    "android-x86" to "x86",
    "android-x64" to "x86_64",
)
val requestedFlutterTargets = project.findProperty("target-platform")
    ?.toString()
    ?.split(",")
    ?.map(String::trim)
    ?.filter(String::isNotEmpty)
    .orEmpty()
val requestedAndroidAbis = requestedFlutterTargets.mapNotNull(flutterTargetAbis::get).toSet()

android {
    namespace = "com.example.novyn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.novyn"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ABI selection is handled by Flutter's --target-platform / --split-per-abi
        // arguments. Do not set ndk.abiFilters here: AGP rejects combining
        // ndk abiFilters with Flutter's split ABI APK configuration.
    }

    packaging {
        jniLibs {
            if (requestedAndroidAbis.isNotEmpty()) {
                val allAndroidAbis = setOf(
                    "armeabi-v7a",
                    "arm64-v8a",
                    "x86",
                    "x86_64",
                )
                excludes.addAll(
                    (allAndroidAbis - requestedAndroidAbis).map { "lib/$it/**" },
                )
            }
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
