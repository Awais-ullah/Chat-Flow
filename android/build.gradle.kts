allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://storage.zego.im/maven") }
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Intercept project evaluation and remove legacy jcenter declarations
    project.buildscript.configurations.all {
        resolutionStrategy.eachDependency {
            // Force resolution without relying on jcenter repositories
        }
    }
}

// Strip jcenter from subprojects before they execute their build scripts
gradle.beforeProject {
    buildscript.repositories.removeIf { it.name.contains("jcenter", ignoreCase = true) }
    repositories.removeIf { it.name.contains("jcenter", ignoreCase = true) }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}