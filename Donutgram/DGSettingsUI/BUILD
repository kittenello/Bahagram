load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "DGSettingsUI",
    module_name = "DGSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//Donutgram/DGSimpleSettings:DGSimpleSettings",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
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
