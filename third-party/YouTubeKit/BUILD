load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

filegroup(
    name = "JavaScriptResources",
    srcs = glob(["Sources/YouTubeKit/Resources/*.js"]),
)

plist_fragment(
    name = "BundleInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>com.kittenello.bahogram.YouTubeKitResources</string>
    <key>CFBundleName</key>
    <string>YouTubeKitResources</string>
    """,
)

apple_resource_bundle(
    name = "YouTubeKitResources",
    infoplists = [":BundleInfoPlist"],
    resources = [":JavaScriptResources"],
)

swift_library(
    name = "YouTubeKit",
    module_name = "YouTubeKit",
    srcs = glob(["Sources/YouTubeKit/**/*.swift"]),
    data = [":YouTubeKitResources"],
    visibility = ["//visibility:public"],
)
