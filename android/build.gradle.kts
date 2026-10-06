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
// flutter_google_places_sdk_android 0.2.2 預設的 Places SDK 5.x 已移除它用到的 Place 欄位，
// 編譯不過；修好的 0.3.0 又跟主套件的版本約束衝突。先釘在還保留這些欄位的 4.x。
subprojects {
    if (project.name == "flutter_google_places_sdk_android") {
        project.extensions.extraProperties.set("google_places_version", "4.4.1")
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
