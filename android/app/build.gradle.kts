import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")//original
//    id("org.jetbrains.kotlin.android")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.digistall.gotan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true//added for notification
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.digistall.gotan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")//prod remove
            signingConfig = signingConfigs.getByName("release")
        }
    }

    dependencies {
        implementation("androidx.multidex:multidex:2.0.1")
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")// add for the firebase notification
//        implementation(platform("com.google.firebase:firebase-bom:32.3.1"))//prod okay
//        implementation(platform("com.google.firebase:firebase-bom:32.7.3"))//works
//        implementation("com.google.firebase:firebase-analytics")//prod okay
//        implementation("com.google.firebase:firebase-auth")//prod okay

//        implementation(platform("com.google.firebase:firebase-bom:33.15.0"))
//        implementation("com.google.firebase:firebase-auth")
//        implementation("com.google.firebase:firebase-analytics")
    }
}

flutter {
    source = "../.."
}
