load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "BGSettingsUI",
    module_name = "BGSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//Bahogram/BGSimpleSettings:BGSimpleSettings",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
