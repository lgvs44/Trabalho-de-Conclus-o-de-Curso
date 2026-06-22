plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17) // Define a versão da JVM para Kotlin
}

android {
    namespace = "com.example.irrigador_inteligente"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Mantenha esta linha

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.irrigador_inteligente"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Adicione ou atualize este bloco
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Adicione ou atualize este bloco
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../../" // Linha corrigida: aponta para a raiz do projeto Flutter
}

dependencies {
    implementation(kotlin("stdlib", "1.9.0")) // Use a versão do Kotlin que você está usando
}
