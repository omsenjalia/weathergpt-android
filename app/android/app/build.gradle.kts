plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.weathergpt.weathergpt_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.weathergpt.weathergpt_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Optional release keystore from CI secrets / local env.
    // SIGNING_MODE=unsigned | signed | debug-keys (default)
    val keystorePath = System.getenv("KEYSTORE_PATH")
    val keystorePassword = System.getenv("KEYSTORE_PASSWORD")
    val keyAlias = System.getenv("KEY_ALIAS")
    val keyPassword = System.getenv("KEY_PASSWORD")
    val hasReleaseKeystore =
        !keystorePath.isNullOrBlank() &&
            !keystorePassword.isNullOrBlank() &&
            !keyAlias.isNullOrBlank() &&
            !keyPassword.isNullOrBlank() &&
            file(keystorePath).exists()

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            val mode = (System.getenv("SIGNING_MODE") ?: "debug-keys").lowercase()
            when {
                mode == "unsigned" -> {
                    // Produce an unsigned release artifact for later signing.
                    signingConfig = null
                }
                mode == "signed" -> {
                    require(hasReleaseKeystore) { "SIGNING_MODE=signed requires a valid keystore and all signing credentials" }
                    signingConfig = signingConfigs.getByName("release")
                }
                mode == "debug-keys" -> {
                    // Local `flutter run --release` and CI without secrets.
                    signingConfig = signingConfigs.getByName("debug")
                }
                else -> error("Unknown SIGNING_MODE: $mode")
            }
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
