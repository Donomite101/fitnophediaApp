

plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Make :app evaluate first
    project.evaluationDependsOn(":app")

    // Redirect build dirs
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Fix duplicate firebase-iid / messaging
    configurations.all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }

    // Fix namespace error for on_audio_query_android
    if (project.name == "on_audio_query_android") {
        fun setNamespace(project: Project) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                setNamespace.invoke(android, "com.lucasjosino.on_audio_query")
            }
        }

        if (project.state.executed) {
            setNamespace(project)
        } else {
            project.afterEvaluate {
                setNamespace(project)
            }
        }
    }

    // Apply Java Toolchain to enforce Java 17
    plugins.withType<JavaPlugin> {
        extensions.configure<JavaPluginExtension> {
            toolchain {
                languageVersion.set(JavaLanguageVersion.of(17))
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }

    val configureAndroid = {
        if (project.name != "app" && project.extensions.findByName("android") != null) {
            project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
