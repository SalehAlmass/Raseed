import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))
subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is BaseExtension) {
                if (android.namespace == null) {
                    android.namespace = "com.raseed.${project.name.replace("-", "_")}"
                }

                // Fix for AGP 8.0+ regarding "package" attribute in AndroidManifest.xml
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
