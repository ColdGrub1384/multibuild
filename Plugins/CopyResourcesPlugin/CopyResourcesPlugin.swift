import Foundation
import PackagePlugin

@main
struct CopyResourcesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        let inputToolchain = target.directory.appending("ios-cmake/ios.toolchain.cmake")
        let output = context.pluginWorkDirectory.appending("ios.toolchain.cmake")
        return [
            .buildCommand(displayName: "Copy Resources",
                          executable: try context.tool(named: "CopyResources").path,
                          arguments: [inputToolchain, output],
                          environment: [:],
                          inputFiles: [inputToolchain],
                          outputFiles: [output])
        ]
    }
}
