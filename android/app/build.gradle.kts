import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.restaurant.orderlyy_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.restaurant.orderlyy_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            keyAlias = System.getenv("ORDERLII_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
            keyPassword = System.getenv("ORDERLII_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
            storeFile = if (System.getenv("ORDERLII_KEYSTORE_PATH") != null) {
                file(System.getenv("ORDERLII_KEYSTORE_PATH"))
            } else if (keystoreProperties.getProperty("storeFile") != null) {
                file(keystoreProperties.getProperty("storeFile"))
            } else null
            storePassword = System.getenv("ORDERLII_STORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            val releaseSigning = signingConfigs.getByName("release")
            val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
            if (isReleaseBuild && (releaseSigning.storeFile == null || !releaseSigning.storeFile!!.exists())) {
                throw GradleException("RELEASE BUILD REJECTED: Production signing keystore not found. Valid production signing credentials (key.properties or ORDERLII_* environment variables) are strictly required for release builds. Debug-signing fallback is prohibited.")
            }
            signingConfig = releaseSigning
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
