import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../../Singletons"
import "../common/BluetoothFormatting.js" as BluetoothFormatting

Item {
    id: controlCenter

    signal connectivityPanelRequested(string kind, bool open)
    signal focusModeChanged(bool enabled)
    signal nightLightModeChanged(bool enabled)
    signal requestNotification(string appName, string summary, string body)
    signal openNotificationCenterRequested()

    property var notificationModel: null
    readonly property var userConfig: UserConfig
    property var shellRootController: null
    property string currentPowerProfile: "balanced"

    Process {
        id: powerProfileGetProc
        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-power-profile.sh", "get"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text) {
                    const p = String(text).trim();
                    if (p.length > 0)
                        controlCenter.currentPowerProfile = p;
                }
            }
        }
    }

    function refreshPowerProfile() {
        if (!powerProfileGetProc.running)
            powerProfileGetProc.running = true;
    }

    function setPowerProfile(modeName) {
        controlCenter.currentPowerProfile = modeName;
        Quickshell.execDetached([(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-power-profile.sh", "set", modeName]);
    }

    function powerProfileLabel(p) {
        switch (p) {
        case "ultra":
        case "game":
            return "Game Mode";
        case "performance":
            return "Performance";
        case "power-saver":
        case "powersave":
        case "eco":
            return "Power Saver";
        case "balanced":
        default:
            return "Balanced";
        }
    }

    property bool showCondition: false
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    // ... rest of properties ...

    scale: showCondition ? 1.0 : (opacity > 0.05 ? 1.0 : 0.96)
    transformOrigin: Item.Top

    Behavior on scale {
        NumberAnimation {
            duration: showCondition ? 400 : 80
            easing.type: Easing.OutQuint
        }
    }
    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property int batteryCapacity: 0
    property bool isCharging: false
    property real volumeLevel: (typeof SysBackend !== "undefined" && SysBackend && SysBackend.currentVolume >= 0) ? SysBackend.currentVolume : -1
    property real brightnessLevel: -1
    property int sliderIntroDelay: 400
    property int currentWorkspace: 1
    property string currentTrack: ""
    property string currentArtist: ""

    property real localVolume: volumeLevel >= 0 ? volumeLevel : 0.5
    property real localBrightness: brightnessLevel >= 0 ? brightnessLevel : 0.5
    property real displayedVolume: localVolume
    property real displayedBrightness: localBrightness
    property real pendingVolume: localVolume
    property real pendingBrightness: localBrightness
    property real lastAppliedVolume: -1
    property real lastAppliedBrightness: -1
    property bool brightnessSetterRunning: false
    property bool volumeSetterRunning: false
    property bool sliderIntroPending: false
    property bool wifiPanelOpen: false
    property bool bluetoothPanelOpen: false
    property bool powerPanelOpen: false
    property bool powerViewActive: false
    property bool batteryDrawerOpen: false
    property bool batteryDrawerDragging: false
    property real batteryDrawerProgress: 0
    property bool batteryDrawerSettling: false
    readonly property bool batteryDrawerMoving: batteryDrawerDragging
        || batteryDrawerSettling
        || batteryDrawerProgressAnimation.running
    property bool batteryModeBusy: false
    property bool batteryModeStateRunning: false
    property bool batteryModeSetterRunning: false
    property bool batteryModeSliderDragging: false
    property bool batteryTlpAvailable: false
    property bool batteryTlpChecked: false
    property int batteryModeIndex: 1
    property int batteryModeAppliedIndex: 1
    property int batteryModePendingIndex: 1
    property real batteryModeDragOffset: 0
    property string batteryModeInfoMessage: ""
    property string batteryModeError: ""
    property string batteryModeLastCommandOutput: ""
    property int batteryModeRefreshPollsRemaining: 0
    property bool nightLightEnabled: false
    property bool nightLightBusy: false
    property int nightLightTemperature: 4500
    readonly property bool hyprlandNightLight: CompositorBackend.compositor === "hyprland"
    property bool focusEnabled: (typeof Theme !== "undefined" && Theme.dnd !== undefined) ? Theme.dnd : false
    property bool focusBusy: false

    property string wifiLocalInfoMessage: ""
    property string wifiLocalError: ""
    property string wifiPendingPasswordSsid: ""
    property string wifiPendingPasswordValue: ""

    property string bluetoothInfoMessage: ""
    property string bluetoothError: ""
    property string bluetoothPairAndConnectPath: ""
    property string bluetoothPendingSecretValue: ""
    readonly property var wifiController: WifiController
    readonly property var bluetoothPairingAgent: BluetoothPairingAgent
    readonly property var wifiNetworks: wifiController ? wifiController.networks : null

    readonly property real sliderKnobSize: 24
    readonly property color panelColor: Theme.isDark ? StyleTokens.panel : Theme.bg
    readonly property color moduleColor: Theme.isDark ? StyleTokens.module : "#ffffff"
    readonly property color moduleHover: Theme.isDark ? StyleTokens.moduleHover : Theme.bgHover
    readonly property color trackColor: Theme.isDark ? StyleTokens.track : Qt.rgba(0, 0, 0, 0.08)
    readonly property color textPrimary: Theme.isDark ? StyleTokens.textPrimary : "#111418"
    readonly property color textPrimaryBright: Theme.isDark ? StyleTokens.textPrimaryBright : "#111418"
    readonly property color textSecondary: Theme.isDark ? StyleTokens.textSecondary : "#44474f"
    readonly property color textMuted: Theme.isDark ? StyleTokens.textMuted : "#60646c"
    readonly property color cardAccent: Theme.accent
    readonly property color cardAccentPressed: Qt.darker(Theme.accent, 1.15)
    readonly property color cardFillActive: Theme.accent
    readonly property color cardFillHover: Theme.isDark ? StyleTokens.cardFillHover : Theme.bgHover
    readonly property color buttonFill: Theme.isDark ? StyleTokens.buttonFill : Qt.rgba(0, 0, 0, 0.06)
    readonly property color buttonFillHover: Theme.isDark ? StyleTokens.buttonFillHover : Qt.rgba(0, 0, 0, 0.10)
    readonly property color buttonFillPressed: Theme.isDark ? StyleTokens.buttonFillPressed : Qt.rgba(0, 0, 0, 0.16)
    readonly property string wifiGlyph: ""
    readonly property string bluetoothGlyph: ""
    readonly property string chargingIconGlyph: "\uf0e7"
    readonly property string brightnessIconGlyph: "\u{F00DF}"
    readonly property string volumeIconGlyph: "\u{F057E}"
    readonly property string nightLightGlyph: Theme.isDark ? "\uf186" : "\uf185"
    readonly property var batteryModeGlyphs: ["", "", ""]
    readonly property real batteryDrawerHandleHeight: 20
    readonly property real batteryDrawerContentGap: 8
    readonly property real batteryModeCardHeight: 80
    readonly property real roundToggleButtonSize: 58
    readonly property real roundToggleButtonGap: 18
    readonly property real controlCenterExtraHeight: 0
    readonly property real controlCenterMaximumExtraHeight: 0
    readonly property bool bluetoothAvailable: !!bluetoothAdapter
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDeviceValues: bluetoothAdapter ? bluetoothAdapter.devices.values : []
    readonly property bool wifiSupported: wifiController ? wifiController.supported : false
    readonly property bool wifiReadOnly: wifiController ? wifiController.readOnly : true
    readonly property bool wifiAvailable: wifiController ? wifiController.available : false
    readonly property bool wifiEnabled: wifiController ? wifiController.enabled : false
    readonly property bool wifiBusy: wifiController ? wifiController.busy : false
    readonly property bool wifiListRunning: wifiController ? wifiController.scanning : false
    readonly property string wifiCurrentSsid: wifiController ? wifiController.currentSsid : ""
    readonly property string wifiInfoMessage: wifiLocalInfoMessage.length > 0
        ? wifiLocalInfoMessage
        : (wifiController ? wifiController.infoMessage : "")
    readonly property string wifiError: wifiLocalError.length > 0
        ? wifiLocalError
        : (wifiController ? wifiController.errorMessage : "")
    readonly property string wifiUnsupportedReason: wifiController ? wifiController.unsupportedReason : ""
    readonly property string wifiAvailabilityMessage: {
        if (wifiUnsupportedReason.length > 0) return wifiUnsupportedReason;
        if (wifiSupported && !wifiAvailable) return "No Wi-Fi device is available.";
        return "";
    }
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothBusy: bluetoothAdapter
        ? bluetoothAdapter.state === BluetoothAdapterState.Enabling
            || bluetoothAdapter.state === BluetoothAdapterState.Disabling
        : false
    readonly property bool bluetoothPairingActive: bluetoothPairingAgent ? bluetoothPairingAgent.requestActive : false
    readonly property bool bluetoothPairingRequiresInput: bluetoothPairingAgent ? bluetoothPairingAgent.requestRequiresInput : false
    readonly property bool bluetoothPairingNumericInput: bluetoothPairingAgent ? bluetoothPairingAgent.requestNumericInput : false
    readonly property bool bluetoothPairingRequiresConfirmation: bluetoothPairingAgent ? bluetoothPairingAgent.requestRequiresConfirmation : false
    readonly property string bluetoothPairingTitle: bluetoothPairingAgent ? bluetoothPairingAgent.promptTitle : ""
    readonly property string bluetoothPairingMessage: bluetoothPairingAgent ? bluetoothPairingAgent.promptMessage : ""
    readonly property string bluetoothPairingDisplayedCode: bluetoothPairingAgent ? bluetoothPairingAgent.displayedCode : ""
    readonly property bool hasConnectivityPrompt: wifiPendingPasswordSsid.length > 0 || bluetoothPairingActive
    readonly property bool anyConnectivityPanelOpen: wifiPanelOpen || bluetoothPanelOpen
    readonly property string wifiStatusText: wifiController ? wifiController.statusText : "Unavailable"
    readonly property string bluetoothStatusText: buildBluetoothStatusText()
    readonly property string bluetoothAvailabilityMessage: bluetoothAvailable ? "" : "No Bluetooth adapter is available."
    readonly property string batteryModeStatusText: buildBatteryModeStatusText()
    readonly property bool tlpControlsEnabled: trimString(userConfig.tlpPermissionMode) !== "skip"

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function trimString(value) {
        if (value === undefined || value === null) return "";
        return String(value).trim();
    }

    function batteryModeLabel(index) {
        if (index <= 0) return "Power Saver";
        if (index >= 2) return "Performance";
        return "Balanced";
    }

    function batteryModeCommand(index) {
        if (index <= 0) return "power-saver";
        if (index >= 2) return "performance";
        return "balanced";
    }

    function batteryModeIndexForCommand(command) {
        const normalized = trimString(command).toLowerCase();
        if (normalized === "power-saver" || normalized === "bat") return 0;
        if (normalized === "performance" || normalized === "ac") return 2;
        return 1;
    }

    function setBatteryModeVisualIndex(index, animate) {
        const nextIndex = Math.max(0, Math.min(2, index));
        batteryModeIndex = nextIndex;
    }

    function setBatteryDrawerOpen(open) {
        const nextOpen = !!open;
        batteryDrawerOpen = nextOpen;
        batteryDrawerSettling = true;
        batteryDrawerProgress = nextOpen ? 1 : 0;
        batteryDrawerSettleTimer.restart();
        if (nextOpen && tlpControlsEnabled && !batteryTlpChecked)
            refreshBatteryModeState();
    }

    function toggleBatteryDrawer() {
        setBatteryDrawerOpen(!batteryDrawerOpen);
    }

    function refreshBatteryModeState() {
        if (batteryModeStateRunning)
            return;

        batteryModeStateRunning = true;
        SystemServices.requestTlpState();
    }

    function applyBatteryModeState(available, profile, output, errorString) {
        batteryModeStateRunning = false;
        batteryTlpChecked = true;
        batteryTlpAvailable = !!available;

        if (!batteryTlpAvailable) {
            batteryModeBusy = false;
            batteryModeError = trimString(errorString).length > 0 ? errorString : "TLP is not installed.";
            setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
            return;
        }

        if (batteryModeError === "TLP is not installed.")
            batteryModeError = "";

        let resolvedProfile = trimString(profile);
        if (resolvedProfile.length === 0) {
            const profileMatch = String(output || "").match(/TLP profile\s*=\s*([a-z-]+)/i);
            if (profileMatch)
                resolvedProfile = profileMatch[1];
        }

        if (resolvedProfile.length > 0) {
            const nextIndex = batteryModeIndexForCommand(resolvedProfile);
            batteryModeAppliedIndex = nextIndex;
            setBatteryModeVisualIndex(nextIndex, true);

            if (batteryModeRefreshPollsRemaining > 0 && nextIndex === batteryModePendingIndex) {
                batteryModeRefreshPollsRemaining = 0;
                batteryModeRefreshTimer.stop();
                batteryModeError = "";
                batteryModeInfoMessage = batteryModeLabel(nextIndex) + " active.";
            }
        }
    }

    function buildBatteryModeStatusText() {
        if (batteryModeBusy) return "Applying " + batteryModeLabel(batteryModePendingIndex);
        if (trimString(userConfig.tlpPermissionMode) === "skip") return "TLP disabled";
        if (!batteryTlpChecked) return "Checking TLP";
        if (!batteryTlpAvailable) return "TLP is not installed";
        return batteryModeLabel(batteryModeIndex);
    }

    function rollbackBatteryMode(message) {
        batteryModeBusy = false;
        batteryModeError = message;
        batteryModeInfoMessage = "";
        batteryModeDragOffset = 0;
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
    }

    function classifyBatteryModeFailure(exitCode) {
        const details = trimString(batteryModeLastCommandOutput).toLowerCase();

        if (details.indexOf("sorry, try again") >= 0 || details.indexOf("incorrect password attempt") >= 0)
            return "The configured sudo password did not work.";
        if (details.indexOf("pkexec") >= 0 && details.indexOf("not installed") >= 0)
            return "Install pkexec or set tlpSudoPassword in userconfig.json.";
        if (details.indexOf("sudo is not installed") >= 0)
            return "sudo is not installed.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("password") >= 0) {
            if (trimString(userConfig.tlpPermissionMode) === "ask")
                return "Install pkexec or set tlpSudoPassword in userconfig.json.";
            return "sudo needs a password; set tlpSudoPassword in userconfig.json.";
        }
        if (details.indexOf("sudo:") >= 0 && details.indexOf("no new privileges") >= 0)
            return "sudo is blocked by the current process security flags.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("a terminal is required") >= 0)
            return "sudo needs a real terminal, but the panel could not open one.";
        if (details.indexOf("missing root privilege") >= 0)
            return "TLP needs admin permission.";
        if (details.indexOf("command not found") >= 0 || details.indexOf("not found") >= 0) {
            if (details.indexOf("tlp") >= 0)
                return "TLP is not installed.";
        }

        if (exitCode === 127)
            return "TLP is not installed.";
        if (exitCode === 126)
            return "Install pkexec or set tlpSudoPassword in userconfig.json.";
        return "TLP could not apply that mode.";
    }

    function queueBatteryModeStateRefresh(polls) {
        batteryModeRefreshPollsRemaining = Math.max(0, polls);
        if (batteryModeRefreshPollsRemaining > 0)
            batteryModeRefreshTimer.restart();
        else
            batteryModeRefreshTimer.stop();
    }

    function selectBatteryMode(index) {
        if (batteryModeBusy) {
            if (batteryModeSetterRunning)
                SystemServices.cancelTlpApply();
            batteryModeBusy = false;
            batteryModeSetterRunning = false;
        }

        queueBatteryModeStateRefresh(0);

        const nextIndex = Math.max(0, Math.min(2, index));

        if (trimString(userConfig.tlpPermissionMode) === "skip") {
            rollbackBatteryMode("TLP mode switching is disabled in userconfig.json.");
            return;
        }

        if (!batteryTlpChecked) {
            refreshBatteryModeState();
            rollbackBatteryMode("Checking TLP. Try again in a moment.");
            return;
        }

        if (!batteryTlpAvailable) {
            rollbackBatteryMode("TLP is not installed.");
            return;
        }

        if (nextIndex === batteryModeAppliedIndex) {
            batteryModeError = "";
            batteryModeInfoMessage = batteryModeLabel(nextIndex) + " active.";
            setBatteryModeVisualIndex(nextIndex, true);
            return;
        }

        batteryModePendingIndex = nextIndex;
        batteryModeBusy = true;
        batteryModeSetterRunning = true;
        batteryModeError = "";
        batteryModeInfoMessage = "Applying " + batteryModeLabel(nextIndex) + "...";
        setBatteryModeVisualIndex(nextIndex, true);
        batteryModeLastCommandOutput = "";
        const permissionMode = trimString(userConfig.tlpPermissionMode);
        const sudoPassword = permissionMode === "password"
            ? trimString(userConfig.tlpSudoPassword)
            : "";
        SystemServices.setTlpMode(batteryModeCommand(nextIndex), sudoPassword, permissionMode === "ask");
    }

    function finishBatteryModeApply(success, exitCode, output, errorString) {
        batteryModeSetterRunning = false;
        batteryModeBusy = false;
        batteryModeLastCommandOutput = trimString(output);
        if (batteryModeLastCommandOutput.length === 0)
            batteryModeLastCommandOutput = trimString(errorString);

        if (!success) {
            rollbackBatteryMode(classifyBatteryModeFailure(exitCode));
            return;
        }

        batteryModeAppliedIndex = batteryModePendingIndex;
        batteryModeError = "";
        batteryModeInfoMessage = batteryModeLabel(batteryModeAppliedIndex) + " active.";
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
        refreshBatteryModeState();
    }

    function toggleNightLight() {
        if (nightLightBusy)
            return;

        nightLightBusy = true;
        if (nightLightEnabled) {
            nightLightDisableProcess.running = true;
        } else {
            nightLightEnableProcess.running = true;
        }
    }

    function toggleFocus() {
        if (focusBusy)
            return;

        const nextVal = !controlCenter.focusEnabled;
        controlCenter.focusEnabled = nextVal;
        if (typeof Theme !== "undefined" && Theme.dnd !== undefined)
            Theme.dnd = nextVal;
        if (typeof NotificationService !== "undefined" && NotificationService.dnd !== undefined)
            NotificationService.dnd = nextVal;
        if (controlCenter.shellRootController && controlCenter.shellRootController.focusEnabled !== undefined)
            controlCenter.shellRootController.focusEnabled = nextVal;
        controlCenter.focusModeChanged(nextVal);
        Quickshell.execDetached(["sh", "-c",
            (nextVal ? "touch /tmp/carbon-dnd.on; command -v swaync-client >/dev/null 2>&1 && swaync-client -dn || true" : "rm -f /tmp/carbon-dnd.on; command -v swaync-client >/dev/null 2>&1 && swaync-client -df || true")]);
    }

    function clearWifiPrompt() {
        wifiPendingPasswordSsid = "";
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
    }

    function clearWifiMessages() {
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
        if (wifiController)
            wifiController.clearMessages();
    }

    function clearBluetoothMessages() {
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function submitBluetoothPairingSecret() {
        if (!bluetoothPairingAgent || !bluetoothPairingRequiresInput)
            return;

        const secret = trimString(bluetoothPendingSecretValue);
        if (!secret) {
            bluetoothError = bluetoothPairingNumericInput
                ? "Enter the 6-digit passkey first."
                : "Enter the PIN first.";
            return;
        }

        if (bluetoothPairingNumericInput && !/^\d{1,6}$/.test(secret)) {
            bluetoothError = "Passkeys must be 1 to 6 digits.";
            return;
        }

        bluetoothError = "";
        bluetoothPairingAgent.submitSecret(secret);
        bluetoothPendingSecretValue = "";
    }

    function confirmBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;

        bluetoothError = "";
        bluetoothPairingAgent.confirmRequest();
    }

    function cancelBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;

        bluetoothPairingAgent.cancelRequest();
        bluetoothPendingSecretValue = "";
    }

    function isConnectivityPanelOpen(kind) {
        if (kind === "wifi") return wifiPanelOpen;
        if (kind === "bluetooth") return bluetoothPanelOpen;
        if (kind === "power") return powerPanelOpen;
        return false;
    }

    function setConnectivityPanelOpen(kind, open, emitSignal) {
        if (emitSignal === undefined)
            emitSignal = true;

        const nextOpen = !!open;
        let changed = false;

        if (kind === "wifi") {
            changed = wifiPanelOpen !== nextOpen;
            wifiPanelOpen = nextOpen;

            if (nextOpen) {
                if (showCondition) {
                    requestWifiStateRefresh();
                    if (wifiSupported && wifiEnabled)
                        requestWifiListRefresh(true);
                }
            } else {
                clearWifiPrompt();
                clearWifiMessages();
            }
        } else if (kind === "bluetooth") {
            changed = bluetoothPanelOpen !== nextOpen;
            bluetoothPanelOpen = nextOpen;

            if (nextOpen) {
                if (bluetoothAdapter && bluetoothEnabled && !bluetoothAdapter.discovering) {
                    bluetoothAdapter.discovering = true;
                    bluetoothInfoMessage = "Scanning for nearby devices...";
                    bluetoothScanStopTimer.restart();
                }
            } else {
                if (bluetoothPairingActive)
                    cancelBluetoothPairing();
                if (bluetoothAdapter && bluetoothAdapter.discovering)
                    bluetoothAdapter.discovering = false;
                bluetoothScanStopTimer.stop();
                bluetoothConnectAfterPairTimer.stop();
                bluetoothConnectionTimeoutTimer.stop();
                bluetoothPairAndConnectPath = "";
                bluetoothPendingSecretValue = "";
                clearBluetoothMessages();
            }
        } 
        else if (kind === "power") {
            changed = powerPanelOpen !== nextOpen;
            powerPanelOpen = nextOpen;
        }
        else {
            return;
        }

        if (changed && emitSignal)
            connectivityPanelRequested(kind, nextOpen);
    }

    function toggleConnectivityOverlay(kind) {
        setConnectivityPanelOpen(kind, !isConnectivityPanelOpen(kind));
    }

    function triggerShutdown() {
        if (!shutdownProcess.running)
            shutdownProcess.running = true;
    }
    function triggerRestart() {
        if (!restartProcess.running)
            restartProcess.running = true;
    }
    function triggerSleep() {
        if (!sleepProcess.running)
            sleepProcess.running = true;
    }
    function triggerLock() {
        if (!lockProcess.running)
            lockProcess.running = true;
    }

    function closeConnectivityPanels(emitSignals) {
        if (emitSignals === undefined)
            emitSignals = true;

        setConnectivityPanelOpen("wifi", false, emitSignals);
        setConnectivityPanelOpen("bluetooth", false, emitSignals);
        clearWifiPrompt();
        clearWifiMessages();
        clearBluetoothMessages();
    }

    function requestWifiStateRefresh() {
        if (!showCondition || !wifiController) return;
        wifiController.refreshState();
    }

    function requestWifiListRefresh(rescan) {
        if (!showCondition || !wifiController) return;
        if (!wifiSupported || !wifiAvailable || !wifiEnabled) return;
        wifiController.refreshNetworks(!!rescan);
    }

    function toggleWifiEnabled() {
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.setEnabled(!wifiEnabled);
    }

    function disconnectWifi() {
        if (!wifiSupported || !wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.disconnectCurrent();
    }

    function connectWifiNetwork(network) {
        if (!network) return;
        if (!wifiSupported) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "Wi-Fi control is unavailable.";
            return;
        }
        if (!wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }
        if (!wifiEnabled) {
            wifiLocalError = "Turn on Wi-Fi first.";
            return;
        }
        if (network.connected) return;

        const ssid = trimString(network.ssid);
        const networkType = trimString(network.type);
        const secure = !!network.secure;
        const savedConnection = !!network.savedConnection;

        if (!ssid) {
            wifiLocalError = "Hidden networks are not supported in this panel yet.";
            return;
        }

        if (!savedConnection && networkType === "wep") {
            wifiLocalError = "WEP networks aren't supported by this panel.";
            return;
        }

        if (!savedConnection && networkType === "8021x") {
            wifiLocalError = "802.1X networks need to be provisioned first.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();

        if (savedConnection) {
            if (wifiController)
                wifiController.connectToNetwork(ssid);
            return;
        }

        if (!secure) {
            if (wifiController)
                wifiController.connectToNetwork(ssid);
            return;
        }

        wifiPendingPasswordSsid = ssid;
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "Enter the password for " + ssid + ".";
    }

    function submitWifiPassword() {
        const ssid = trimString(wifiPendingPasswordSsid);
        if (!ssid) return;

        if (trimString(wifiPendingPasswordValue).length === 0) {
            wifiLocalError = "Enter a password first.";
            return;
        }

        const password = wifiPendingPasswordValue;
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.connectToNetwork(ssid, password);
    }

    function applyBrightnessSnapshot(value) {
        if (value >= 0)
            syncBrightnessFromLevel(value);
    }

    function applyVolumeSnapshot(value) {
        if (value >= 0)
            syncVolumeFromLevel(value);
    }

    function flushBrightness(force) {
        const nextValue = clamp01(pendingBrightness);
        if (!force && Math.abs(nextValue - lastAppliedBrightness) < 0.01) return;
        if (brightnessSetterRunning) {
            brightnessApplyTimer.restart();
            return;
        }

        lastAppliedBrightness = nextValue;
        brightnessSetterRunning = true;
        SystemServices.setBrightness(nextValue);
    }

    function queueBrightness(value) {
        localBrightness = clamp01(value);
        if (showCondition && !sliderIntroPending) displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        brightnessApplyTimer.restart();
    }

    function flushVolume(force) {
        const nextValue = clamp01(pendingVolume);
        if (!force && Math.abs(nextValue - lastAppliedVolume) < 0.01) return;
        if (volumeSetterRunning) {
            volumeApplyTimer.restart();
            return;
        }

        lastAppliedVolume = nextValue;
        volumeSetterRunning = true;
        SystemServices.setVolume(nextValue);
    }

    function queueVolume(value) {
        localVolume = clamp01(value);
        displayedVolume = localVolume;
        pendingVolume = localVolume;
        volumeApplyTimer.restart();
    }

    function syncBrightnessFromLevel(level) {
        if (level < 0) return;
        localBrightness = clamp01(level);
        displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        lastAppliedBrightness = localBrightness;
    }

    function syncVolumeFromLevel(level) {
        if (level < 0) return;
        localVolume = clamp01(level);
        displayedVolume = localVolume;
        pendingVolume = localVolume;
        lastAppliedVolume = localVolume;
    }

    function syncLevelsFromProps() {
        syncBrightnessFromLevel(brightnessLevel);
        syncVolumeFromLevel(volumeLevel);
    }

    function bluetoothDeviceName(device) {
        if (!device) return "Unknown device";
        return BluetoothFormatting.displayName(
            device.name,
            device.deviceName,
            device.address,
            device.icon
        );
    }

    function bluetoothDeviceHasFriendlyName(device) {
        if (!device) return false;
        return BluetoothFormatting.friendlyName(
            device.name,
            device.deviceName,
            device.address
        ).length > 0;
    }

    function bluetoothDeviceAddress(device) {
        return device ? BluetoothFormatting.addressLabel(device.address) : "";
    }

    function bluetoothDeviceStateText(device) {
        if (!device) return "";
        if (device.pairing) return "Pairing";

        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting";
        case BluetoothDeviceState.Connected:
            return "Connected";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting";
        default:
            break;
        }

        if (device.paired || device.bonded) return "Paired";
        return "Available";
    }

    function bluetoothDeviceSubtitle(device) {
        const parts = [];
        const stateLabel = bluetoothDeviceStateText(device);
        if (stateLabel.length > 0) parts.push(stateLabel);
        if (device && device.batteryAvailable) parts.push(bluetoothBatteryPercent(device) + "%");
        if (device && !bluetoothDeviceHasFriendlyName(device)) {
            const address = bluetoothDeviceAddress(device);
            if (address.length > 0) parts.push(address);
        }
        return parts.join(" • ");
    }

    function bluetoothBatteryPercent(device) {
        if (!device || !device.batteryAvailable)
            return -1;

        const rawValue = Math.max(0, Number(device.battery) || 0);
        return Math.max(0, Math.min(100, Math.round(rawValue <= 1 ? rawValue * 100 : rawValue)));
    }

    function bluetoothDeviceMatchesSection(device, section) {
        if (!device) return false;

        const paired = device.paired || device.bonded;
        if (section === "connected") return device.connected;
        if (section === "paired") return !device.connected && paired;
        if (section === "available") return !paired;
        return false;
    }

    function buildBluetoothStatusText() {
        if (!bluetoothAvailable) return "Unavailable";
        if (!bluetoothEnabled) return "Off";

        const devices = bluetoothDeviceValues || [];
        const connectedNames = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.connected)
                connectedNames.push(bluetoothDeviceName(device));
        }

        if (connectedNames.length === 1) return connectedNames[0];
        if (connectedNames.length > 1) return connectedNames[0] + " +" + (connectedNames.length - 1);
        if (bluetoothAdapter.discovering) return "Scanning";
        return bluetoothBusy ? "Working..." : "On";
    }

    function toggleBluetoothEnabled() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }

        bluetoothError = "";
        bluetoothInfoMessage = "";
        bluetoothPairAndConnectPath = "";

        if (bluetoothAdapter.discovering)
            bluetoothAdapter.discovering = false;

        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }

    function toggleBluetoothScan() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        if (!bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";
        if (bluetoothAdapter.discovering) {
            bluetoothAdapter.discovering = false;
            bluetoothInfoMessage = "";
            bluetoothScanStopTimer.stop();
        } else {
            bluetoothAdapter.discovering = true;
            bluetoothInfoMessage = "Scanning for nearby devices...";
            bluetoothScanStopTimer.restart();
        }
    }

    function handleBluetoothDevicePressed(device) {
        if (!device) return;
        if (!bluetoothAdapter || !bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";

        if (device.connected) {
            bluetoothInfoMessage = "Disconnecting from " + bluetoothDeviceName(device) + "...";
            bluetoothMessageClearTimer.restart();
            device.disconnect();
            return;
        }

        if (device.paired || device.bonded) {
            bluetoothPairAndConnectPath = device.dbusPath;
            bluetoothInfoMessage = "Connecting to " + bluetoothDeviceName(device) + "...";
            device.trusted = true;
            bluetoothConnectionTimeoutTimer.restart();
            device.connect();
            return;
        }

        bluetoothPairAndConnectPath = device.dbusPath;
        bluetoothInfoMessage = "Pairing " + bluetoothDeviceName(device) + "...";
        bluetoothConnectionTimeoutTimer.restart();
        device.pair();
    }

    function bluetoothDeviceForPath(path) {
        const devices = bluetoothDeviceValues || [];
        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.dbusPath === path)
                return device;
        }
        return null;
    }

    function finishBluetoothConnection(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;

        if (device.paired || device.bonded)
            device.trusted = true;

        bluetoothConnectAfterPairTimer.stop();
        bluetoothConnectionTimeoutTimer.stop();
        bluetoothPairAndConnectPath = "";
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function continueBluetoothPairAndConnect(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;
        if (device.pairing)
            return;

        if (!(device.paired || device.bonded)) {
            bluetoothConnectAfterPairTimer.stop();
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
            bluetoothInfoMessage = "";
            if (!bluetoothPairingActive)
                bluetoothError = "Pairing failed or was canceled.";
            return;
        }

        device.trusted = true;
        if (device.connected) {
            finishBluetoothConnection(device);
            return;
        }

        bluetoothInfoMessage = "Connecting to " + bluetoothDeviceName(device) + "...";
        bluetoothConnectAfterPairTimer.restart();
    }

    function handleBluetoothConnectionStateChanged(device) {
        if (!device || bluetoothPairAndConnectPath !== device.dbusPath)
            return;

        if (device.connected) {
            if (device.pairing)
                return;
            finishBluetoothConnection(device);
            return;
        }

        if (!device.pairing
                && (device.paired || device.bonded)
                && device.state === BluetoothDeviceState.Disconnected
                && !bluetoothConnectAfterPairTimer.running) {
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
            bluetoothInfoMessage = "";
            bluetoothError = "Paired successfully, but the connection failed. Make sure the device is still ready to connect.";
        }
    }

    function forgetBluetoothDevice(device) {
        if (!device) return;
        const name = bluetoothDeviceName(device);
        if (bluetoothPairAndConnectPath === device.dbusPath) {
            bluetoothConnectAfterPairTimer.stop();
            bluetoothConnectionTimeoutTimer.stop();
            bluetoothPairAndConnectPath = "";
        }
        device.forget();
        bluetoothError = "";
        bluetoothInfoMessage = "Forgot " + name + ".";
        bluetoothMessageClearTimer.restart();
    }

    anchors.fill: parent
    anchors.margins: 12
    opacity: showCondition ? 1 : 0
    visible: opacity > 0

    onBrightnessLevelChanged: syncBrightnessFromLevel(brightnessLevel)
    onVolumeLevelChanged: syncVolumeFromLevel(volumeLevel)
    onShowConditionChanged: {
        if (showCondition) {
            syncLevelsFromProps();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            refreshBatteryModeState();
            controlCenter.refreshPowerProfile();
            requestWifiStateRefresh();
            if (wifiPanelOpen && wifiSupported && wifiEnabled)
                requestWifiListRefresh(true);
        } else {
            sliderIntroTimer.stop();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            closeConnectivityPanels();
        }
    }

    Component.onCompleted: {
        syncLevelsFromProps();
        displayedBrightness = localBrightness;
        displayedVolume = localVolume;
        SystemServices.requestBrightness();
        SystemServices.requestVolume();
        controlCenter.refreshPowerProfile();
        controlCenter.focusEnabled = Theme.dnd;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 240 : 60
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on displayedBrightness {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !brightnessCard.pressed

        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    Behavior on displayedVolume {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !volumeCard.pressed

        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    Behavior on batteryDrawerProgress {
        enabled: !controlCenter.batteryDrawerDragging

        NumberAnimation {
            id: batteryDrawerProgressAnimation
            duration: 240
            easing.type: Easing.OutCubic
        }
    }


    Process {
        id: nightLightEnableProcess
        command: [
            "sh",
            "-c",
            controlCenter.hyprlandNightLight
                ? "temp=\"$1\"\n"
                    + "if ! command -v hyprsunset >/dev/null 2>&1; then exit 127; fi\n"
                    + "if hyprctl hyprsunset temperature \"$temp\" >/dev/null 2>&1; then exit 0; fi\n"
                    + "if ! command -v pgrep >/dev/null 2>&1 || ! pgrep -x hyprsunset >/dev/null 2>&1; then\n"
                    + "  if command -v setsid >/dev/null 2>&1; then\n"
                    + "    setsid hyprsunset >/dev/null 2>&1 < /dev/null &\n"
                    + "  else\n"
                    + "    nohup hyprsunset >/dev/null 2>&1 < /dev/null &\n"
                    + "  fi\n"
                    + "fi\n"
                    + "i=0\n"
                    + "while [ \"$i\" -lt 24 ]; do\n"
                    + "  if hyprctl hyprsunset temperature \"$temp\" >/dev/null 2>&1; then exit 0; fi\n"
                    + "  i=$((i + 1))\n"
                    + "  sleep 0.04\n"
                    + "done\n"
                    + "exit 1"
                : "temp=\"$1\"\n"
                    + "if ! command -v gammastep >/dev/null 2>&1; then exit 127; fi\n"
                    + "gammastep -m wayland -P -O \"$temp\" >/dev/null 2>&1",
            "tide-night-light",
            controlCenter.nightLightTemperature.toString()
        ]
        running: false

        onExited: function(exitCode) {
            if (exitCode === 0) {
                controlCenter.nightLightBusy = false;
                controlCenter.nightLightEnabled = true;
                controlCenter.nightLightModeChanged(true);
                controlCenter.requestNotification("Night Light", "Night Light enabled", controlCenter.nightLightTemperature + "K");
                return;
            }

            controlCenter.nightLightBusy = false;
            controlCenter.nightLightEnabled = false;
            controlCenter.nightLightModeChanged(false);
            controlCenter.requestNotification("Night Light", "Night Light unavailable",
                controlCenter.hyprlandNightLight
                    ? "Install hyprsunset to use Night Light."
                    : "Install gammastep to use Night Light.");
        }
    }

    Process {
        id: nightLightDisableProcess
        command: [
            "sh",
            "-c",
            controlCenter.hyprlandNightLight
                ? "hyprctl hyprsunset identity >/dev/null 2>&1 || true"
                : "if ! command -v gammastep >/dev/null 2>&1; then exit 127; fi\n"
                    + "gammastep -m wayland -x >/dev/null 2>&1 || true"
        ]
        running: false

        onExited: function(exitCode) {
            controlCenter.nightLightBusy = false;
            controlCenter.nightLightEnabled = false;
            controlCenter.nightLightModeChanged(false);
            if (exitCode === 127)
                controlCenter.requestNotification("Night Light", "Night Light unavailable",
                    controlCenter.hyprlandNightLight
                        ? "Install hyprsunset to use Night Light."
                        : "Install gammastep to use Night Light.");
            else
                controlCenter.requestNotification("Night Light", "Night Light disabled", "");
        }
    }

    Process {
        id: focusEnableProcess
        command: ["swaync-client", "-dn"]
        running: false

        onExited: function(exitCode) {
            controlCenter.focusBusy = false;
            controlCenter.focusEnabled = exitCode === 0;
            controlCenter.focusModeChanged(controlCenter.focusEnabled);
            if (exitCode === 0)
                controlCenter.requestNotification("Focus", "Focus enabled", "Notifications paused");
        }
    }

    Process {
        id: focusDisableProcess
        command: ["swaync-client", "-df"]
        running: false

        onExited: function(exitCode) {
            controlCenter.focusBusy = false;
            controlCenter.focusEnabled = false;
            controlCenter.focusModeChanged(false);
            if (exitCode === 0)
                controlCenter.requestNotification("Focus", "Focus disabled", "");
        }
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Shutdown failed",
                    "Could not power off via systemctl.");
        }
    }
    Process {
        id: restartProcess
        command: ["systemctl", "reboot"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Restart failed",
                    "Could not reboot via systemctl.");
        }
    }
    Process {
        id: sleepProcess
        command: ["systemctl", "suspend"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                controlCenter.requestNotification("Power", "Sleep failed",
                    "Could not suspend via systemctl.");
        }
    }
    Process {
        id: lockProcess
        command: [
            "sh",
            "-c",
            "if command -v hyprlock >/dev/null 2>&1; then hyprlock; "
                + "elif command -v swaylock >/dev/null 2>&1; then swaylock; "
                + "elif command -v i3lock >/dev/null 2>&1; then i3lock; "
                + "elif command -v loginctl >/dev/null 2>&1; then loginctl lock-session; "
                + "else exit 127; fi"
        ]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 127)
                controlCenter.requestNotification("Power", "Lock unavailable",
                    "Install hyprlock, swaylock, or i3lock to enable screen locking.");
        }
    }

    Connections {
        target: SystemServices

        function onTlpStateReady(available, profile, output, errorString) {
            controlCenter.applyBatteryModeState(available, profile, output, errorString);
        }

        function onTlpSetFinished(success, exitCode, output, errorString) {
            controlCenter.finishBatteryModeApply(success, exitCode, output, errorString);
        }

        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "")
                controlCenter.applyBrightnessSnapshot(value);
        }

        function onBrightnessSetFinished(value, success, errorString) {
            controlCenter.brightnessSetterRunning = false;
            if (success)
                controlCenter.applyBrightnessSnapshot(value);
            if (success && Math.abs(controlCenter.pendingBrightness - controlCenter.lastAppliedBrightness) >= 0.01)
                brightnessApplyTimer.restart();
        }

        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString === "")
                controlCenter.applyVolumeSnapshot(value);
        }

        function onVolumeSetFinished(value, success, errorString) {
            controlCenter.volumeSetterRunning = false;
            if (success)
                controlCenter.applyVolumeSnapshot(value);
            if (success && Math.abs(controlCenter.pendingVolume - controlCenter.lastAppliedVolume) >= 0.01)
                volumeApplyTimer.restart();
        }
    }

    Timer {
        id: brightnessApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushBrightness(false)
    }

    Timer {
        id: volumeApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushVolume(false)
    }

    Timer {
        id: sliderIntroTimer
        interval: controlCenter.sliderIntroDelay
        repeat: false

        onTriggered: {
            controlCenter.sliderIntroPending = false;
            controlCenter.displayedBrightness = controlCenter.localBrightness;
            controlCenter.displayedVolume = controlCenter.localVolume;
        }
    }

    Timer {
        id: batteryModeRefreshTimer
        interval: 1500
        repeat: true
        onTriggered: {
            if (controlCenter.batteryModeRefreshPollsRemaining <= 0) {
                stop();
                return;
            }

            controlCenter.batteryModeRefreshPollsRemaining -= 1;
            controlCenter.refreshBatteryModeState();

            if (controlCenter.batteryModeRefreshPollsRemaining <= 0)
                stop();
        }
    }

    Timer {
        id: bluetoothScanStopTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothAdapter && controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothAdapter.discovering = false;
            controlCenter.bluetoothInfoMessage = "";
        }
    }

    Timer {
        id: bluetoothConnectAfterPairTimer
        interval: 350
        repeat: false
        onTriggered: {
            const device = controlCenter.bluetoothDeviceForPath(controlCenter.bluetoothPairAndConnectPath);
            if (!device)
                return;
            if (device.connected) {
                controlCenter.finishBluetoothConnection(device);
                return;
            }
            device.connect();
        }
    }

    Timer {
        id: bluetoothConnectionTimeoutTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothPairAndConnectPath.length === 0)
                return;
            bluetoothConnectAfterPairTimer.stop();
            controlCenter.bluetoothPairAndConnectPath = "";
            controlCenter.bluetoothInfoMessage = "";
            controlCenter.bluetoothError = "Bluetooth pairing or connection timed out. Put the device back in pairing mode and try again.";
        }
    }

    Timer {
        id: bluetoothMessageClearTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothPairAndConnectPath.length === 0)
                controlCenter.bluetoothInfoMessage = "";
        }
    }

    Timer {
        id: batteryDrawerSettleTimer
        interval: 300
        repeat: false
        onTriggered: controlCenter.batteryDrawerSettling = false
    }

    Connections {
        target: Theme

        function onDndChanged() {
            controlCenter.focusEnabled = Theme.dnd;
        }
    }

    Connections {
        target: wifiController

        function onEnabledChanged() {
            if (!controlCenter.wifiEnabled)
                controlCenter.clearWifiPrompt();
        }
    }

    Connections {
        target: bluetoothAdapter

        function onEnabledChanged() {
            if (!controlCenter.bluetoothAdapter.enabled) {
                controlCenter.bluetoothPairAndConnectPath = "";
                controlCenter.bluetoothInfoMessage = "";
                controlCenter.bluetoothError = "";
                bluetoothScanStopTimer.stop();
                bluetoothConnectAfterPairTimer.stop();
                bluetoothConnectionTimeoutTimer.stop();
            }
        }

        function onDiscoveringChanged() {
            if (!controlCenter.bluetoothAdapter.discovering)
                bluetoothScanStopTimer.stop();
        }
    }

    // Keep device state observers outside the filtered UI rows. A device moves
    // from "available" to "paired" during first-time pairing, which destroys
    // its old row before a row-local PairedChanged handler can reliably finish
    // the trust-and-connect sequence.
    Repeater {
        model: controlCenter.bluetoothDeviceValues

        delegate: Item {
            width: 0
            height: 0
            visible: false

            property var bluetoothDevice: modelData

            Connections {
                target: bluetoothDevice
                ignoreUnknownSignals: true

                function onPairedChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onBondedChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onPairingChanged() {
                    controlCenter.continueBluetoothPairAndConnect(bluetoothDevice);
                }

                function onConnectedChanged() {
                    controlCenter.handleBluetoothConnectionStateChanged(bluetoothDevice);
                }

                function onStateChanged() {
                    controlCenter.handleBluetoothConnectionStateChanged(bluetoothDevice);
                }
            }
        }
    }

    Connections {
        target: bluetoothPairingAgent

        function onRequestChanged() {
            controlCenter.bluetoothPendingSecretValue = "";
            if (controlCenter.bluetoothPairingActive) {
                controlCenter.bluetoothError = "";
                controlCenter.setConnectivityPanelOpen("bluetooth", true);
            }
        }

        function onRegistrationErrorChanged() {
            if (!controlCenter.bluetoothPairingAgent)
                return;

            if (!controlCenter.bluetoothPairingAgent.registered
                    && controlCenter.bluetoothPairingAgent.registrationError.length > 0
                    && controlCenter.bluetoothPanelOpen) {
                controlCenter.bluetoothError = controlCenter.bluetoothPairingAgent.registrationError;
            }
        }
    }

    Column {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 12
        visible: !controlCenter.powerViewActive
        spacing: 10

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // ── 1. Top Notification Banner Pill ───────────────────────────
        Rectangle {
            id: notifCard
            width: parent.width
            height: 46
            radius: 18
            color: Theme.isDark ? "#1e2229" : "#eef1f7"
            border.width: 1
            border.color: Theme.isDark ? "#282d37" : "#d8dce6"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: notifOpenBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Bell icon container
                Rectangle {
                    width: 32
                    height: 32
                    radius: 10
                    color: Theme.isDark ? "#2a2f3a" : "#dde2ed"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        color: (controlCenter.notificationModel && controlCenter.notificationModel.count > 0) ? controlCenter.cardAccent : controlCenter.textSecondary
                        font.pixelSize: 15
                        font.family: controlCenter.iconFontFamily
                    }
                }

                // Title + Subtitle
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 42
                    spacing: 2

                    Text {
                        width: parent.width
                        text: (controlCenter.notificationModel && controlCenter.notificationModel.count > 0)
                            ? (controlCenter.notificationModel.get(0).summary || (controlCenter.notificationModel.count + " new notification" + (controlCenter.notificationModel.count > 1 ? "s" : "")))
                            : "No notifications"
                        font.family: controlCenter.textFontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: controlCenter.textPrimary
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: (controlCenter.notificationModel && controlCenter.notificationModel.count > 0)
                            ? (controlCenter.notificationModel.get(0).appName || controlCenter.notificationModel.get(0).body || "Tap Open to view")
                            : "All caught up"
                        font.family: controlCenter.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: controlCenter.textMuted
                        elide: Text.ElideRight
                    }
                }
            }

            // "Open" action button pill
            Rectangle {
                id: notifOpenBtn
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                height: 28
                radius: 14
                color: notifOpenMouse.containsMouse ? (Theme.isDark ? "#383f4e" : "#ccd2df") : (Theme.isDark ? "#2a2f3a" : "#dde2ed")
                border.width: 1
                border.color: Theme.isDark ? "#3c4352" : "#cfd5e2"

                Text {
                    anchors.centerIn: parent
                    text: "Open"
                    font.family: controlCenter.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: controlCenter.textPrimary
                }

                MouseArea {
                    id: notifOpenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        controlCenter.openNotificationCenterRequested()
                        if (controlCenter.shellRootController && controlCenter.shellRootController.showNotificationCenter) {
                            controlCenter.shellRootController.showNotificationCenter()
                        }
                    }
                }
            }
        }

        // ── 2. Primary Quick Toggles Row (Wi-Fi & Bluetooth) ───────────
        Row {
            width: parent.width
            height: 54
            spacing: 10

            // Capsule 1: Wi-Fi
            Rectangle {
                id: wifiCapsule
                width: (parent.width - 10) / 2
                height: 54
                radius: 20
                color: controlCenter.wifiEnabled ? controlCenter.cardAccent : (wifiMouse.containsMouse ? (Theme.isDark ? "#282d37" : "#e4e8f0") : (Theme.isDark ? "#1e2229" : "#eef1f7"))
                border.width: 1
                border.color: controlCenter.wifiEnabled ? controlCenter.cardAccent : (Theme.isDark ? "#2a2f3a" : "#d8dce6")

                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: wifiChevronArea.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: controlCenter.wifiGlyph
                        color: controlCenter.wifiEnabled ? "#0d2b1d" : controlCenter.textPrimary
                        font.pixelSize: 18
                        font.family: controlCenter.iconFontFamily
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Wi-Fi"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: controlCenter.wifiEnabled ? "#0d2b1d" : controlCenter.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: controlCenter.wifiEnabled ? (controlCenter.wifiCurrentSsid.length > 0 ? controlCenter.wifiCurrentSsid : "On") : "Off"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: controlCenter.wifiEnabled ? "#1b4d37" : controlCenter.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                // Click body to toggle Wi-Fi
                MouseArea {
                    id: wifiMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: wifiChevronArea.left
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: controlCenter.wifiSupported && controlCenter.wifiAvailable && !controlCenter.wifiBusy
                    onClicked: controlCenter.toggleWifiEnabled()
                }

                // Chevron area for Wi-Fi details overlay
                Item {
                    id: wifiChevronArea
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 34

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 19
                        font.family: controlCenter.textFontFamily
                        font.weight: Font.Bold
                        color: controlCenter.wifiEnabled ? "#0d2b1d" : controlCenter.textSecondary
                    }

                    MouseArea {
                        id: wifiChevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.toggleConnectivityOverlay("wifi")
                    }
                }
            }

            // Capsule 2: Bluetooth
            Rectangle {
                id: btCapsule
                width: (parent.width - 10) / 2
                height: 54
                radius: 20
                color: controlCenter.bluetoothEnabled ? controlCenter.cardAccent : (btMouse.containsMouse ? (Theme.isDark ? "#282d37" : "#e4e8f0") : (Theme.isDark ? "#1e2229" : "#eef1f7"))
                border.width: 1
                border.color: controlCenter.bluetoothEnabled ? controlCenter.cardAccent : (Theme.isDark ? "#2a2f3a" : "#d8dce6")

                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: btChevronArea.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: controlCenter.bluetoothGlyph
                        color: controlCenter.bluetoothEnabled ? "#0d2b1d" : controlCenter.textPrimary
                        font.pixelSize: 18
                        font.family: controlCenter.iconFontFamily
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Bluetooth"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: controlCenter.bluetoothEnabled ? "#0d2b1d" : controlCenter.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: controlCenter.bluetoothEnabled ? (controlCenter.bluetoothStatusText.length > 0 ? controlCenter.bluetoothStatusText : "On") : "Off"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: controlCenter.bluetoothEnabled ? "#1b4d37" : controlCenter.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                // Click body to toggle Bluetooth
                MouseArea {
                    id: btMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: btChevronArea.left
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: controlCenter.bluetoothAvailable && !controlCenter.bluetoothBusy
                    onClicked: controlCenter.toggleBluetoothEnabled()
                }

                // Chevron area for Bluetooth details overlay
                Item {
                    id: btChevronArea
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 34

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 19
                        font.family: controlCenter.textFontFamily
                        font.weight: Font.Bold
                        color: controlCenter.bluetoothEnabled ? "#0d2b1d" : controlCenter.textSecondary
                    }

                    MouseArea {
                        id: btChevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.toggleConnectivityOverlay("bluetooth")
                    }
                }
            }
        }

        // ── 3. Secondary Quick Toggles Row (DND & Night Light) ─────────
        Row {
            width: parent.width
            height: 54
            spacing: 10

            // Capsule 3: Do not disturb
            Rectangle {
                id: dndCapsule
                width: (parent.width - 10) / 2
                height: 54
                radius: 20
                color: controlCenter.focusEnabled ? controlCenter.cardAccent : (dndMouse.containsMouse ? (Theme.isDark ? "#282d37" : "#e4e8f0") : (Theme.isDark ? "#1e2229" : "#eef1f7"))
                border.width: 1
                border.color: controlCenter.focusEnabled ? controlCenter.cardAccent : (Theme.isDark ? "#2a2f3a" : "#d8dce6")

                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰂛"
                        color: controlCenter.focusEnabled ? "#0d2b1d" : controlCenter.textPrimary
                        font.pixelSize: 18
                        font.family: controlCenter.iconFontFamily
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Do not disturb"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: controlCenter.focusEnabled ? "#0d2b1d" : controlCenter.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: controlCenter.focusEnabled ? "On" : "Off"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: controlCenter.focusEnabled ? "#1b4d37" : controlCenter.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !controlCenter.focusBusy
                    onClicked: controlCenter.toggleFocus()
                }
            }

            // Capsule 4: Night light
            Rectangle {
                id: nlCapsule
                width: (parent.width - 10) / 2
                height: 54
                radius: 20
                color: controlCenter.nightLightEnabled ? controlCenter.cardAccent : (nlMouse.containsMouse ? (Theme.isDark ? "#282d37" : "#e4e8f0") : (Theme.isDark ? "#1e2229" : "#eef1f7"))
                border.width: 1
                border.color: controlCenter.nightLightEnabled ? controlCenter.cardAccent : (Theme.isDark ? "#2a2f3a" : "#d8dce6")

                Behavior on color { ColorAnimation { duration: 140 } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰖔"
                        color: controlCenter.nightLightEnabled ? "#0d2b1d" : controlCenter.textPrimary
                        font.pixelSize: 18
                        font.family: controlCenter.iconFontFamily
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Night light"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: controlCenter.nightLightEnabled ? "#0d2b1d" : controlCenter.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: controlCenter.nightLightEnabled ? "On" : "Off"
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: controlCenter.nightLightEnabled ? "#1b4d37" : controlCenter.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: nlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !controlCenter.nightLightBusy
                    onClicked: controlCenter.toggleNightLight()
                }
            }
        }

        // ── 4. Compact Controls Row (Sliders, Battery & Actions) ───────
        Row {
            width: parent.width
            height: 44
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            // 4a. Volume Slider
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    id: volIconBtn
                    anchors.verticalCenter: parent.verticalCenter
                    text: controlCenter.volumeLevel <= 0.001 ? "󰝟" : (controlCenter.volumeLevel < 0.5 ? "󰕿" : "󰕾")
                    font.family: controlCenter.iconFontFamily
                    font.pixelSize: 15
                    color: controlCenter.textPrimary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (controlCenter.displayedVolume > 0) {
                                controlCenter.queueVolume(0)
                                controlCenter.flushVolume(true)
                            } else {
                                controlCenter.queueVolume(0.5)
                                controlCenter.flushVolume(true)
                            }
                        }
                    }
                }

                Item {
                    id: volTrack
                    width: 68
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        color: Theme.isDark ? "#282d37" : "#dde1ea"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        width: Math.max(0, Math.min(parent.width, Math.round(parent.width * controlCenter.displayedVolume)))
                        color: controlCenter.cardAccent
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * controlCenter.displayedVolume - width / 2)))
                        width: 12
                        height: 12
                        radius: 6
                        color: controlCenter.cardAccent
                    }

                    MouseArea {
                        id: volumeCard
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                var v = Math.max(0, Math.min(1, mouse.x / width))
                                controlCenter.queueVolume(v)
                            }
                        }
                        onPressed: (mouse) => {
                            var v = Math.max(0, Math.min(1, mouse.x / width))
                            controlCenter.queueVolume(v)
                        }
                        onReleased: controlCenter.flushVolume(true)
                        onWheel: (wheel) => {
                            var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            controlCenter.queueVolume(Math.max(0, Math.min(1, controlCenter.displayedVolume + delta)))
                            controlCenter.flushVolume(true)
                        }
                    }
                }
            }

            // 4b. Brightness Slider
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰃠"
                    font.family: controlCenter.iconFontFamily
                    font.pixelSize: 15
                    color: controlCenter.textPrimary
                }

                Item {
                    id: briTrack
                    width: 68
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        color: Theme.isDark ? "#282d37" : "#dde1ea"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        width: Math.max(0, Math.min(parent.width, Math.round(parent.width * controlCenter.displayedBrightness)))
                        color: controlCenter.cardAccent
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, Math.round(parent.width * controlCenter.displayedBrightness - width / 2)))
                        width: 12
                        height: 12
                        radius: 6
                        color: controlCenter.cardAccent
                    }

                    MouseArea {
                        id: brightnessCard
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                var b = Math.max(0.05, Math.min(1, mouse.x / width))
                                controlCenter.queueBrightness(b)
                            }
                        }
                        onPressed: (mouse) => {
                            var b = Math.max(0.05, Math.min(1, mouse.x / width))
                            controlCenter.queueBrightness(b)
                        }
                        onReleased: controlCenter.flushBrightness(true)
                        onWheel: (wheel) => {
                            var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            controlCenter.queueBrightness(Math.max(0.05, Math.min(1, controlCenter.displayedBrightness + delta)))
                            controlCenter.flushBrightness(true)
                        }
                    }
                }
            }

            // 4c. Battery Telemetry
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: controlCenter.isCharging ? "󰂄" : (controlCenter.batteryCapacity > 85 ? "󰁹" : (controlCenter.batteryCapacity > 50 ? "󰁿" : (controlCenter.batteryCapacity > 20 ? "󰁼" : "󰁺")))
                    font.family: controlCenter.iconFontFamily
                    font.pixelSize: 16
                    color: controlCenter.batteryCapacity <= 20 ? StyleTokens.danger : (controlCenter.isCharging ? StyleTokens.success : controlCenter.textPrimary)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: controlCenter.batteryCapacity + " %"
                        font.family: controlCenter.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: controlCenter.textPrimary
                    }

                    Text {
                        text: controlCenter.isCharging ? "Charging" : "Not charging"
                        font.family: controlCenter.textFontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: controlCenter.textMuted
                    }
                }
            }

            // 4d. Circular Quick Action Buttons (Lock, Dark/Light Mode, Reboot, Shutdown)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Lock
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: lockBtnMouse.containsMouse ? (Theme.isDark ? "#383f4e" : "#ccd2df") : (Theme.isDark ? "#22262e" : "#e0e4ed")
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: controlCenter.iconFontFamily
                        font.pixelSize: 13
                        color: controlCenter.textPrimary
                    }

                    MouseArea {
                        id: lockBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.triggerLock()
                    }
                }

                // Dark / Light Mode Toggle
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: themeBtnMouse.containsMouse ? (Theme.isDark ? "#383f4e" : "#ccd2df") : (Theme.isDark ? "#22262e" : "#e0e4ed")
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: Theme.isDark ? "󰖨" : "󰖔"
                        font.family: controlCenter.iconFontFamily
                        font.pixelSize: 13
                        color: controlCenter.textPrimary
                    }

                    MouseArea {
                        id: themeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var nextMode = Theme.isDark ? "light" : "dark"
                            Quickshell.execDetached(["python3", (Quickshell.env("HOME") || "") + "/.config/carbon/scripts/theme-mk.py", "--mode", nextMode])
                        }
                    }
                }

                // Reboot
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: rebootBtnMouse.containsMouse ? (Theme.isDark ? "#383f4e" : "#ccd2df") : (Theme.isDark ? "#22262e" : "#e0e4ed")
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: controlCenter.iconFontFamily
                        font.pixelSize: 13
                        color: controlCenter.textPrimary
                    }

                    MouseArea {
                        id: rebootBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.triggerRestart()
                    }
                }

                // Power Off
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: powerBtnMouse.containsMouse ? StyleTokens.danger : (Theme.isDark ? "#22262e" : "#e0e4ed")
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        font.family: controlCenter.iconFontFamily
                        font.pixelSize: 13
                        color: powerBtnMouse.containsMouse ? "#ffffff" : controlCenter.textPrimary
                    }

                    MouseArea {
                        id: powerBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: controlCenter.triggerShutdown()
                    }
                }
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: controlCenter.powerViewActive

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Repeater {
                    model: [
                        { glyph: "\uf023", action: "triggerLock" },
                        { glyph: "\uf186", action: "triggerSleep" },
                        { glyph: "\uf021", action: "triggerRestart" },
                        { glyph: "\uf011", action: "triggerShutdown" }
                    ]

                    delegate: Item {
                        width: 50
                        height: 50

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: pwrBtnMouse.containsMouse ? "#24ffffff" : "#10ffffff"
                            border.width: 1
                            border.color: "#18ffffff"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                color: StyleTokens.textPrimary
                                font.pixelSize: 22
                                font.family: controlCenter.iconFontFamily
                            }

                            MouseArea {
                                id: pwrBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (controlCenter[modelData.action])
                                        controlCenter[modelData.action]();
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: [
                        { id: "power-saver", label: "Saver", glyph: "󰌪" },
                        { id: "balanced", label: "Balanced", glyph: "󰾅" },
                        { id: "performance", label: "Perf", glyph: "" },
                        { id: "ultra", label: "Game", glyph: "󰊴" }
                    ]

                    delegate: Rectangle {
                        readonly property bool isActive: (controlCenter.currentPowerProfile === modelData.id)
                            || (modelData.id === "ultra" && (controlCenter.currentPowerProfile === "game" || controlCenter.currentPowerProfile === "ultra"))
                            || (modelData.id === "power-saver" && (controlCenter.currentPowerProfile === "powersave" || controlCenter.currentPowerProfile === "eco"))
                        width: 70
                        height: 30
                        radius: 9
                        color: isActive ? StyleTokens.accent : (pwrModeMouse.containsMouse ? "#20ffffff" : "#0dffffff")
                        border.width: 1
                        border.color: isActive ? StyleTokens.accent : "#1affffff"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: modelData.glyph
                                font.pixelSize: 12
                                font.family: controlCenter.iconFontFamily
                                color: isActive ? StyleTokens.white : StyleTokens.textPrimary
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 10
                                font.family: controlCenter.textFontFamily
                                font.weight: Font.DemiBold
                                color: isActive ? StyleTokens.white : StyleTokens.textPrimary
                            }
                        }

                        MouseArea {
                            id: pwrModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlCenter.setPowerProfile(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
