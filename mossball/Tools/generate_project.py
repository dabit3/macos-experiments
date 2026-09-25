#!/usr/bin/env python3
"""Rebuild the standalone Xcode project using only Python's standard library."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Mossball.xcodeproj"
PROJECT.mkdir(exist_ok=True)
SCHEMES = PROJECT / "xcshareddata" / "xcschemes"
SCHEMES.mkdir(parents=True, exist_ok=True)


def identifier(number: int) -> str:
    return f"{number:024X}"


objects: list[str] = []


def entry(number: int, body: str) -> str:
    key = identifier(number)
    objects.append(f"\t\t{key} = {{ {body} }};")
    return key


app_files = sorted((ROOT / "Mossball").glob("*.swift"))
test_files = sorted((ROOT / "MossballTests").glob("*.swift"))
app_refs: list[str] = []
test_refs: list[str] = []
app_sources: list[str] = []
test_sources: list[str] = []
for index, file in enumerate(app_files + test_files):
    ref = entry(100 + index, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file.relative_to(ROOT)}"; sourceTree = "<group>";')
    build = entry(200 + index, f"isa = PBXBuildFile; fileRef = {ref};")
    if file in app_files:
        app_refs.append(ref)
        app_sources.append(build)
    else:
        test_refs.append(ref)
        test_sources.append(build)

assets = entry(300, 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Mossball/Assets.xcassets; sourceTree = "<group>";')
asset_build = entry(301, f"isa = PBXBuildFile; fileRef = {assets};")
launch = entry(302, 'isa = PBXFileReference; lastKnownFileType = file.storyboard; path = Mossball/LaunchScreen.storyboard; sourceTree = "<group>";')
launch_build = entry(303, f"isa = PBXBuildFile; fileRef = {launch};")
app_product = entry(10, 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Mossball.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = entry(11, 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MossballTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = entry(12, f'isa = PBXGroup; name = Products; children = ({app_product}, {test_product}); sourceTree = "<group>";')
entry(2, f'isa = PBXGroup; children = ({", ".join(app_refs + test_refs + [assets, launch, products])}); sourceTree = "<group>";')
app_phase = entry(20, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(app_sources)}); runOnlyForDeploymentPostprocessing = 0;')
test_phase = entry(21, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(test_sources)}); runOnlyForDeploymentPostprocessing = 0;')
resources = entry(22, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({asset_build}, {launch_build}); runOnlyForDeploymentPostprocessing = 0;')
app_frameworks = entry(23, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
test_frameworks = entry(24, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
proxy = entry(25, f'isa = PBXContainerItemProxy; containerPortal = {identifier(1)}; proxyType = 1; remoteGlobalIDString = {identifier(3)}; remoteInfo = Mossball;')
dependency = entry(26, f'isa = PBXTargetDependency; target = {identifier(3)}; targetProxy = {proxy};')

common = """
CLANG_ENABLE_MODULES = YES;
SWIFT_VERSION = 5.0;
IPHONEOS_DEPLOYMENT_TARGET = 17.0;
SDKROOT = iphoneos;
TARGETED_DEVICE_FAMILY = 1;
CODE_SIGN_STYLE = Automatic;
"""
for index, name in enumerate(["Debug", "Release"]):
    debug = name == "Debug"
    entry(40 + index, f"""isa = XCBuildConfiguration; name = {name}; buildSettings = {{
        {common}
        SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if debug else "-O"};
        SWIFT_COMPILATION_MODE = {"singlefile" if debug else "wholemodule"};
        DEBUG_INFORMATION_FORMAT = {"dwarf" if debug else '"dwarf-with-dsym"'};
        ENABLE_TESTABILITY = {"YES" if debug else "NO"};
        SWIFT_ACTIVE_COMPILATION_CONDITIONS = {"DEBUG" if debug else '""'};
        GCC_OPTIMIZATION_LEVEL = {"0" if debug else "s"};
    }};""")
    entry(42 + index, f"""isa = XCBuildConfiguration; name = {name}; buildSettings = {{
        PRODUCT_NAME = Mossball;
        PRODUCT_BUNDLE_IDENTIFIER = com.nader.mossball;
        INFOPLIST_FILE = Mossball/Info.plist;
        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        MARKETING_VERSION = 1.0;
        CURRENT_PROJECT_VERSION = 1;
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
        SUPPORTS_MACCATALYST = NO;
        SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
        SWIFT_EMIT_LOC_STRINGS = YES;
    }};""")
    entry(44 + index, f"""isa = XCBuildConfiguration; name = {name}; buildSettings = {{
        PRODUCT_NAME = MossballTests;
        PRODUCT_BUNDLE_IDENTIFIER = com.nader.mossball.tests;
        GENERATE_INFOPLIST_FILE = YES;
        TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Mossball.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Mossball";
        BUNDLE_LOADER = "$(TEST_HOST)";
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
    }};""")

for number, configs in [(30, [40, 41]), (31, [42, 43]), (32, [44, 45])]:
    entry(number, f'isa = XCConfigurationList; buildConfigurations = ({", ".join(identifier(config) for config in configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
entry(3, f'isa = PBXNativeTarget; buildConfigurationList = {identifier(31)}; buildPhases = ({app_phase}, {app_frameworks}, {resources}); buildRules = (); dependencies = (); name = Mossball; productName = Mossball; productReference = {app_product}; productType = "com.apple.product-type.application";')
entry(4, f'isa = PBXNativeTarget; buildConfigurationList = {identifier(32)}; buildPhases = ({test_phase}, {test_frameworks}); buildRules = (); dependencies = ({dependency}); name = MossballTests; productName = MossballTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
entry(1, f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {identifier(30)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {identifier(2)}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({identifier(3)}, {identifier(4)});')
(PROJECT / "project.pbxproj").write_text(
    "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n"
    + "\n".join(objects)
    + f"\n\t}};\n\trootObject = {identifier(1)};\n}}\n"
)


def reference(target: int, name: str, product: str) -> str:
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier(target)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Mossball.xcodeproj"/>'


(SCHEMES / "Mossball.xcscheme").write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference(3, "Mossball", "Mossball.app")}</BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO">{reference(4, "MossballTests", "MossballTests.xctest")}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{reference(3, "Mossball", "Mossball.app")}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{reference(3, "Mossball", "Mossball.app")}</BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
""")
print(f"Generated {PROJECT}")
