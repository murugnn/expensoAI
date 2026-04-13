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

subprojects {
    val configureNamespaceAction = {
        if ((project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("android-library"))) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val namespaceMethod = android.javaClass.getMethod("getNamespace")
                    val namespace = namespaceMethod.invoke(android)
                    
                    if (namespace == null) {
                        val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                        
                        // Try to parse package from AndroidManifest.xml
                        var newNamespace = "com.example.${project.name.replace("-", "_")}"
                        
                        val manifestFile = project.file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            try {
                                val manifestContent = manifestFile.readText()
                                val packageRegex = Regex("package=\"([^\"]+)\"")
                                val match = packageRegex.find(manifestContent)
                                if (match != null) {
                                    newNamespace = match.groupValues[1]
                                    println("Found package '$newNamespace' in Manifest for '${project.name}'")
                                }
                            } catch (e: Exception) {
                                println("Failed to read manifest for ${project.name}: $e")
                            }
                        }
                        
                        println("Auto-assigning namespace '$newNamespace' to project '${project.name}'")
                        setNamespaceMethod.invoke(android, newNamespace)
                    }
                } catch (e: Exception) {
                    println("Failed to auto-assign namespace for ${project.name}: $e")
                }
            }
        }
    }

    if (project.state.executed) {
        configureNamespaceAction()
    } else {
        project.afterEvaluate {
            configureNamespaceAction()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
