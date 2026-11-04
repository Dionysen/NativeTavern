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

// flutter_live2d pins CMake 3.10.2, which is no longer shipped by the Android SDK.
// Rewrite any plugin that still requests it to the installed 3.22.1 toolchain.
fun Project.rewritePinnedCmake3102() {
    val androidExt = extensions.findByName("android") ?: return
    try {
        val externalNativeBuild =
            androidExt.javaClass.methods
                .firstOrNull { it.name == "getExternalNativeBuild" && it.parameterCount == 0 }
                ?.invoke(androidExt)
                ?: return
        val cmake =
            externalNativeBuild.javaClass.methods
                .firstOrNull { it.name == "getCmake" && it.parameterCount == 0 }
                ?.invoke(externalNativeBuild)
                ?: return
        val versionMethod =
            cmake.javaClass.methods.firstOrNull { it.name == "getVersion" && it.parameterCount == 0 }
                ?: return
        val currentVersion = versionMethod.invoke(cmake) as? String
        if (currentVersion == "3.10.2") {
            cmake.javaClass.methods
                .firstOrNull { it.name == "setVersion" && it.parameterCount == 1 }
                ?.invoke(cmake, "3.22.1")
        }
    } catch (_: Exception) {
        // Plugin may not expose the AGP DSL used above; leave its config unchanged.
    }
}

subprojects {
    if (state.executed) {
        rewritePinnedCmake3102()
    } else {
        afterEvaluate { rewritePinnedCmake3102() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
