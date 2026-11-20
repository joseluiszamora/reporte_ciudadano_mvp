import com.android.build.api.variant.LibraryAndroidComponentsExtension

plugins {
    id("com.android.library") apply false
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
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Compile FlutterFire against the supported platform already used by the
    // project toolchain. App minSdk and targetSdk remain owned by Flutter.
    if (name == "firebase_core" || name == "firebase_auth") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<LibraryAndroidComponentsExtension> {
                finalizeDsl { library ->
                    if ((library.compileSdk ?: 0) < 35) library.compileSdk = 35
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
