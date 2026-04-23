plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // TODO: Altere o namespace para o applicationId definitivo após mudá-lo abaixo
    namespace = "com.example.app_medicamentos_pets"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Mude para seu domínio próprio antes de publicar (ex: br.com.seudominio.medicamentospets)
        // NUNCA publique com com.example.* — a Play Store rejeita automaticamente
        applicationId = "com.example.app_medicamentos_pets"
        minSdk = 21
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // TODO (MANUAL): Após criar o keystore de produção, preencha os dados abaixo
        // e substitua o signingConfig no bloco release.
        // create("release") {
        //     storeFile = file(System.getenv("KEYSTORE_PATH") ?: "keystore/release.jks")
        //     storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
        //     keyAlias = System.getenv("KEY_ALIAS") ?: ""
        //     keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        // }
    }

    buildTypes {
        release {
            // TODO (MANUAL): Quando criar o keystore, troque por: signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
