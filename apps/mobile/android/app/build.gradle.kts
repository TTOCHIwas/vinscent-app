import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

fun dartDefine(key: String, defaultValue: String = ""): String {
    val directValue = project.findProperty(key) as String?
    if (!directValue.isNullOrBlank()) {
        return directValue
    }

    val dartDefines = project.findProperty("dart-defines") as String?
    if (dartDefines.isNullOrBlank()) {
        return defaultValue
    }

    return dartDefines
        .split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded))
            }.getOrNull()
        }
        .firstOrNull { it.startsWith("$key=") }
        ?.substringAfter("=")
        ?: defaultValue
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? {
    return releaseSigningProperties
        .getProperty(propertyName)
        ?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentName)?.takeIf(String::isNotBlank)
}

val releaseStoreFilePath =
    releaseSigningValue("storeFile", "DANJJAN_UPLOAD_STORE_FILE")
val releaseStorePassword =
    releaseSigningValue("storePassword", "DANJJAN_UPLOAD_STORE_PASSWORD")
val releaseKeyAlias =
    releaseSigningValue("keyAlias", "DANJJAN_UPLOAD_KEY_ALIAS")
val releaseKeyPassword =
    releaseSigningValue("keyPassword", "DANJJAN_UPLOAD_KEY_PASSWORD")
val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)

val releaseSigningConfigurationError = when {
    listOf(
        releaseStoreFilePath,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).any { it.isNullOrBlank() } ->
        "Release signing is not configured. Add android/key.properties or the DANJJAN_UPLOAD_* environment variables."
    releaseStoreFile?.isFile != true ->
        "The configured Android release keystore does not exist."
    else -> null
}

android {
    namespace = "com.vinscent.vinscent"
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
        applicationId = "com.vinscent.vinscent"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoNativeAppKey"] =
            dartDefine("KAKAO_NATIVE_APP_KEY")
    }

    signingConfigs {
        if (releaseSigningConfigurationError == null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigurationError == null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        releaseSigningConfigurationError?.let { message ->
            throw GradleException(message)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    testImplementation("junit:junit:4.13.2")
}
