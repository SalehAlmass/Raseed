import com.android.build.gradle.BaseExtension
import java.io.File

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
    
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is BaseExtension) {
                if (android.namespace == null) {
                    android.namespace = "com.raseed.${project.name.replace("-", "_")}"
                }
                
                // Fix for AGP 8.0+ regarding "package" attribute in AndroidManifest.xml
                // This strips the package attribute from the manifest of subprojects (plugins)
                // during the build process to avoid conflicts with the namespace property.
                project.tasks.matching { it.name.contains("Manifest") }.configureEach {
                    doFirst {
                        val manifestFile = project.file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            val content = manifestFile.readText()
                            if (content.contains("package=\"")) {
                                val updatedContent = content.replace(Regex("package=\"[^\"]*\""), "")
                                manifestFile.writeText(updatedContent)
                            }
                        }
                    }
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
