plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.kopkar_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.budiberlianmotor.kopkar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "KOPKAR BBM"
    }

    flavorDimensions += "portal"
    productFlavors {
        create("karyawan") {
            dimension = "portal"
            applicationId = "com.budiberlianmotor.kopkar.karyawan"
            manifestPlaceholders["appName"] = "KOPKAR BBM"
        }
        create("admin") {
            dimension = "portal"
            applicationId = "com.budiberlianmotor.kopkar.admin"
            manifestPlaceholders["appName"] = "KOPKAR Admin"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
