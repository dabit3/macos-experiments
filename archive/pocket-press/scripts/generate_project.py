#!/usr/bin/env python3
"""Regenerate the checked-in native Xcode project using only Python's stdlib."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def quoted(value):
    return '"' + value.replace('"', '\\"') + '"'


def generate():
    sources = sorted(ROOT.glob("Core/*.swift")) + sorted(ROOT.glob("PocketPress/*.swift"))
    resources = sorted(ROOT.glob("Resources/*.jpg")) + [ROOT / "Resources/Assets.xcassets"]
    files = sources + resources + [ROOT / "PocketPress/Info.plist"]
    objects = []

    def add(name, content):
        objects.append("\n".join(line.rstrip() for line in f"{uid(name)} = {{ {content} }};".splitlines()))

    for path in files:
        name = path.relative_to(ROOT).as_posix()
        filetype = {
            ".swift": "sourcecode.swift",
            ".jpg": "image.jpeg",
            ".plist": "text.plist.xml",
            ".xcassets": "folder.assetcatalog",
        }[path.suffix]
        add(name, f"isa = PBXFileReference; lastKnownFileType = {filetype}; path = {quoted(name)}; sourceTree = \"<group>\";")
        if path.suffix != ".plist":
            add("build:" + name, f"isa = PBXBuildFile; fileRef = {uid(name)};")
    add("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = PocketPress.app; sourceTree = BUILT_PRODUCTS_DIR;')
    children = ", ".join(uid(p.relative_to(ROOT).as_posix()) for p in files)
    add("root", f'isa = PBXGroup; children = ({children}, {uid("products")}); sourceTree = "<group>";')
    add("products", f'isa = PBXGroup; children = ({uid("product")}); name = Products; sourceTree = "<group>";')
    for name, paths, phase in [
        ("sources", sources, "PBXSourcesBuildPhase"),
        ("resources", resources, "PBXResourcesBuildPhase"),
        ("frameworks", [], "PBXFrameworksBuildPhase"),
    ]:
        builds = ", ".join(uid("build:" + p.relative_to(ROOT).as_posix()) for p in paths)
        add(name, f"isa = {phase}; buildActionMask = 2147483647; files = ({builds}); runOnlyForDeploymentPostprocessing = 0;")
    project_settings = (
        "SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; "
        "CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; "
        "SWIFT_STRICT_CONCURRENCY = complete; ENABLE_USER_SCRIPT_SANDBOXING = YES; "
    )
    target_settings = (
        "PRODUCT_BUNDLE_IDENTIFIER = com.pocketpress.native; PRODUCT_NAME = PocketPress; "
        'INFOPLIST_FILE = PocketPress/Info.plist; TARGETED_DEVICE_FAMILY = "1"; '
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; '
        "CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = NO; "
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; "
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; '
    )
    for scope, settings in [("project", project_settings), ("target", target_settings)]:
        for mode in ["Debug", "Release"]:
            optimization = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf;' if mode == "Debug" else 'SWIFT_COMPILATION_MODE = wholemodule; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
            add(f"{scope}:{mode}", f"isa = XCBuildConfiguration; buildSettings = {{ {settings} {optimization} }}; name = {mode};")
        configs = f'{uid(scope + ":Debug")}, {uid(scope + ":Release")}'
        add(f"{scope}:configs", f"isa = XCConfigurationList; buildConfigurations = ({configs}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
    add("target", f"""
        isa = PBXNativeTarget; buildConfigurationList = {uid("target:configs")};
        buildPhases = ({uid("sources")}, {uid("frameworks")}, {uid("resources")});
        buildRules = (); dependencies = (); name = PocketPress;
        productName = PocketPress; productReference = {uid("product")};
        productType = "com.apple.product-type.application";
    """)
    add("project", f"""
        isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }};
        buildConfigurationList = {uid("project:configs")};
        compatibilityVersion = "Xcode 14.0"; developmentRegion = en;
        hasScannedForEncodings = 0; knownRegions = (en, Base);
        mainGroup = {uid("root")}; productRefGroup = {uid("products")};
        projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});
    """)
    project = ROOT / "PocketPress.xcodeproj"
    project.mkdir(exist_ok=True)
    (project / "project.pbxproj").write_text(
        "// !$*UTF8*$!\n{\narchiveVersion = 1;\nclasses = {};\nobjectVersion = 56;\nobjects = {\n"
        + "\n".join(objects) + "\n};\nrootObject = " + uid("project") + ";\n}\n"
    )
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="PocketPress.app" BlueprintName="PocketPress" ReferencedContainer="container:PocketPress.xcodeproj"/>'
    (schemes / "PocketPress.xcscheme").write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
""")
    print("Generated PocketPress.xcodeproj")


if __name__ == "__main__":
    generate()
