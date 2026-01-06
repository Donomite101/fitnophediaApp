
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
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
