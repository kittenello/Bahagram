load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BGSimpleSettings",
    module_name = "BGSimpleSettings",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
