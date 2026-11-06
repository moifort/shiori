plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.apollo)
}

// Firebase is configured from google-services.json, which CI writes from a secret and which
// stays out of git. Without it the app still builds and runs in showcase mode.
if (file("google-services.json").exists()) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
}

android {
    namespace = "com.polyforms.shiori"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.polyforms.shiori.app"
        minSdk = 29
        targetSdk = 37
        versionCode = (project.findProperty("shiori.versionCode") as String?)?.toInt() ?: 1
        versionName = (project.findProperty("shiori.versionName") as String?) ?: "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField(
            "String",
            "SERVER_URL",
            "\"https://shiori-server-hvrhl6ox5q-ey.a.run.app\"",
        )
        buildConfigField("String", "SENTRY_DSN", "\"${System.getenv("SHIORI_SENTRY_DSN") ?: ""}\"")
        buildConfigField(
            "String",
            "GOOGLE_WEB_CLIENT_ID",
            "\"${System.getenv("SHIORI_GOOGLE_WEB_CLIENT_ID") ?: (project.findProperty("shiori.googleWebClientId") as String? ?: "")}\"",
        )
    }

    signingConfigs {
        create("upload") {
            val path = System.getenv("SHIORI_UPLOAD_KEYSTORE")
            if (path != null) {
                storeFile = file(path)
                storePassword = System.getenv("SHIORI_UPLOAD_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SHIORI_UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("SHIORI_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (System.getenv("SHIORI_UPLOAD_KEYSTORE") != null) {
                signingConfig = signingConfigs.getByName("upload")
            }
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    jvmToolchain(21)
}

apollo {
    service("shiori") {
        packageName.set("com.polyforms.shiori.graphql")
        // The schema and the operation documents are the iOS app's own: one set of queries,
        // read by both apps, so a query changed for iOS is changed for Android too.
        schemaFiles.from(file("../../shared/schema.graphql"))
        srcDir(file("../../ios/Shiori/Features"))
        generateKotlinModels.set(true)
        listOf(
            "AudibleAsin", "AuthorBiography", "AuthorKey", "AuthorName", "AwaitedEditionId",
            "BookId", "BookTitle", "CoverUrl", "DateTime", "Day", "DeviceToken", "Isbn13",
            "KindleAsin", "NarratorBiography", "NarratorKey", "NarratorName", "Nationality",
            "PersonName", "PortraitUrl", "Publisher", "ReadingNote", "RecommendationComment",
            "SeriesDescription", "SeriesId", "SeriesName", "Subgenre", "Synopsis", "TimeZone",
            "UserId", "WishId",
        ).forEach { mapScalarToKotlinString(it) }
        listOf("Count", "ListeningMinutes", "PageCount", "VolumeNumber", "Year")
            .forEach { mapScalarToKotlinInt(it) }
        listOf("Eur", "Percentage", "StarRating").forEach { mapScalarToKotlinDouble(it) }
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.window)
    implementation(libs.androidx.datastore)
    implementation(libs.androidx.browser)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play)
    implementation(libs.googleid)

    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.coroutines.play)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.apollo.runtime)
    implementation(libs.coil.compose)
    implementation(libs.coil.network)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.auth)
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.messaging)
    implementation(libs.billing)
    implementation(libs.sentry.android)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}
