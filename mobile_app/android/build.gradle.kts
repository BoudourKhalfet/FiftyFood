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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: some Flutter plugin Android libraries (e.g. uni_links 0.5.1)
// don't declare a `namespace` in their published build files which causes
// recent Android Gradle Plugin versions to fail. Set a namespace for any
// library subproject named 'uni_links' so the build succeeds.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (project.name.contains("uni_links")) {
                namespace = "dev.fiftyfood.uni_links"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
