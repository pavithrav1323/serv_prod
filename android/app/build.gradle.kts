// android/app/build.gradle.kts
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Read keystore properties
val keystorePropertiesFile = rootProject.file("../key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    println("Warning: key.properties not found at ${keystorePropertiesFile.absolutePath}")
}

android {
    namespace = "com.serv.serv_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ✅ Java 17 + DESUGARING (required by flutter_local_notifications 17+)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true   // <-- IMPORTANT
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.serv.serv_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storeFilePath = file("${project.rootDir}/../" + keystoreProperties.getProperty("storeFile")).absolutePath
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                println("Using keystore: $storeFilePath")
                println("Using key alias: $keyAlias")
            } else {
                println("Warning: Using debug signing config because key.properties not found")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Keep the mapping file for crash reporting
            applicationVariants.all {
                val variant = this
                variant.outputs
                    .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
                    .forEach { output ->
                        val outputFileName = "app-${variant.baseName}-${variant.versionName}.apk"
                        output.outputFileName = outputFileName
                    }
                
                if (project.tasks.findByName("minify${name.capitalize()}WithR8") != null) {
                    project.tasks.named("minify${name.capitalize()}WithR8") {
                        doLast {
                            val mappingFile = outputs.files.files.find { it.name == "mapping.txt" }
                            if (mappingFile != null && mappingFile.exists()) {
                                val newMappingFile = File(mappingFile.parent, "mapping-${variant.baseName}.txt")
                                mappingFile.copyTo(newMappingFile, overwrite = true)
                                println("Mapping file saved to: ${newMappingFile.absolutePath}")
                            }
                        }
                    }
                }
            }
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

dependencies {
   coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
