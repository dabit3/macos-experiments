# Duo Lab

A small, offline SwiftUI playground for experimenting with adaptive layouts. Includes an adaptive sidebar, a responsive tile grid, persistent tap/tile counts, an autosaving notes editor, and live window/size-class diagnostics.

## Current verification

The starter targets iOS 17+ and uses standard SwiftUI APIs. **iPhone Duo support has not been validated.** Actual display-transition testing requires Xcode 27.1 beta and its iOS 27.1 runtime on macOS 26.6 or later. A regular iPhone or iPad simulator does not substitute for that test.

The simulator build passes with the already-installed Xcode 27.0 command-line toolchain (27A266a). The current VM runs macOS 26.5.2, below that Xcode's declared minimum too; this successful build does not establish a supported Xcode host configuration. Xcode 26.6 reports its iOS platform unavailable despite the installed SDK/runtime. The earlier attempt to upgrade macOS failed to queue the update/restart, followed by loss of VM connectivity. Use a compatible base image to finish the Duo setup.

## Build and run

Requires macOS, full Xcode 16+ with a compatible iOS Simulator runtime, Homebrew, XcodeGen (2.46.0 used here), and jq. No app dependencies, backend, account, or signing credentials are needed for Simulator.

```sh
cd ios-duo-lab
brew install xcodegen jq
./run.sh
```

The script generates the Xcode project, builds, installs, and launches the app. It prints the actual simulator name. By default, it picks an available iPhone matching the selected SDK's major version, preferring Duo if installed, then a booted iPhone.

To select a specific iPhone or iPad:

```sh
xcrun simctl list devices available
./run.sh YOUR_SIMULATOR_UDID
```

Alternatively, open `DuoLab.xcodeproj`, select a Simulator destination, and Run. `project.yml` is the source of truth; regenerate the checked-in project with `xcodegen generate` after changing it.

On this session's VM, explicitly select the working command-line toolchain:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0-RC.app/Contents/Developer
./run.sh
```

The script uses `xcrun xcodebuild` so `DEVELOPER_DIR` is respected even when `PATH` contains another Xcode's binaries.
It opens the selected Xcode's Simulator app when present, otherwise the Simulator registered with macOS. This VM's Xcode 27.0 installation contains only the command-line toolchain, so the GUI comes from the other installed Xcode.

### Checks without launching Simulator

```sh
swift format lint --strict --recursive Sources
bash -n run.sh
xcodegen generate
xcrun xcodebuild -project DuoLab.xcodeproj -scheme DuoLab \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

The Xcode build performs Swift type checking. There is no separate unit-test target for this UI scaffold.

## Finish the iPhone Duo environment

1. Provision a VM running macOS 26.6 or later.
2. Download Xcode 27.1 beta from [Apple Developer downloads](https://developer.apple.com/download/), using authorized Apple Developer access. The archive requires authentication; never check it or credentials into this repository.
3. Install alongside existing Xcode and select it with `DEVELOPER_DIR` or `xcode-select`. Complete first-launch setup and install the iOS 27.1 runtime in Xcode.
4. Confirm `xcrun xcodebuild -version`, `xcrun simctl list runtimes`, and `xcrun simctl list devicetypes` show the expected Xcode, runtime, and iPhone Duo device type.
5. Create/select an actual Duo simulator, and pass its UDID to `./run.sh`.

For example, if the new installation is `/Applications/Xcode-27.1.app`:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
xcrun xcodebuild -version
xcrun simctl list devices available
./run.sh YOUR_DUO_SIMULATOR_UDID
```

See [Apple's Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes) for current simulator limitations.

## Experiments

- **Workspace:** increment the counter, change the number of tiles, and rotate or resize. Reset requires confirmation and preserves notes.
- **Notes:** enter text, switch experiments, and relaunch. Notes and workspace controls use local `AppStorage`.
- **Diagnostics:** inspect the whole window, detail pane, safe area, Dynamic Type, and size classes.

For a future recorded Duo check, switch between its displays while editing notes and while viewing the workspace, then verify layout, navigation, and saved state. Also exercise landscape, large Dynamic Type, keyboard appearance, and relaunch. Size classes are not used as a fold-state detector.
