import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property int countdownSeconds: 60
    property int remaining: countdownSeconds
    property int selectedId: -1   // index into allActions, not into the displayed list

    // user data (loaded at startup)
    property string displayName: ""
    property string loginName: ""
    property string homeDir: ""
    property string avatarPath: ""
    readonly property string avatarUrl: avatarPath !== "" ? "file://" + avatarPath : ""

    // Command building blocks. Every action is a chain "a || b || c": the first command that
    // exists and succeeds wins, so the same chain works on systemd, elogind (OpenRC, runit, s6,
    // dinit) and on different distributions without any configuration.
    readonly property string findQdbus: "Q=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus); "
    readonly property string powerDevil: "org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/SuspendSession "
    readonly property string kdeShutdown: "dbus-send --session --print-reply --dest=org.kde.Shutdown /Shutdown org.kde.Shutdown."
    readonly property string logindCall: "dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager."

    function viaRoot(command) {
        return "sudo -n " + command + " || doas -n " + command
    }

    // all five actions in a fixed order
    readonly property var allActions: [
        { id: 0, name: "sleep", configKey: "showSleep", icon: "system-suspend",
          command: findQdbus
              + "loginctl suspend || $Q " + powerDevil + "suspendToRam"
              + " || systemctl suspend || " + logindCall + "Suspend boolean:true"
              + " || " + viaRoot("pm-suspend") + " || " + viaRoot("zzz") },
        { id: 1, name: "hibernate", configKey: "showHibernate", icon: "system-suspend-hibernate",
          command: findQdbus
              + "loginctl hibernate || $Q " + powerDevil + "suspendToDisk"
              + " || systemctl hibernate || " + logindCall + "Hibernate boolean:true"
              + " || " + viaRoot("pm-hibernate") + " || " + viaRoot("ZZZ") },
        { id: 2, name: "reboot", configKey: "showReboot", icon: "system-reboot",
          command: findQdbus
              + "$Q org.kde.Shutdown /Shutdown logoutAndReboot || " + kdeShutdown + "logoutAndReboot"
              + " || loginctl reboot || systemctl reboot || " + logindCall + "Reboot boolean:true"
              + " || " + viaRoot("reboot") },
        { id: 3, name: "shutdown", configKey: "showShutdown", icon: "system-shutdown",
          command: findQdbus
              + "$Q org.kde.Shutdown /Shutdown logoutAndShutdown || " + kdeShutdown + "logoutAndShutdown"
              + " || loginctl poweroff || systemctl poweroff || " + logindCall + "PowerOff boolean:true"
              + " || " + viaRoot("poweroff") },
        { id: 4, name: "logout", configKey: "showLogout", icon: "system-log-out",
          command: findQdbus
              + "$Q org.kde.Shutdown /Shutdown logout || " + kdeShutdown + "logout"
              + " || $Q org.kde.ksmserver /KSMServer logout 0 0 0"
              + " || loginctl terminate-session \"$XDG_SESSION_ID\"" }
    ]

    // the actions to show, in the configured order; if none were selected, all are shown
    readonly property var visibleActions: {
        var order = (Plasmoid.configuration.order || "").split(",")
        var sorted = []
        order.forEach(function (name) {
            allActions.forEach(function (action) {
                if (action.name === name && sorted.indexOf(action) < 0)
                    sorted.push(action)
            })
        })
        allActions.forEach(function (action) {
            if (sorted.indexOf(action) < 0)
                sorted.push(action)
        })
        var shown = sorted.filter(function (action) { return Plasmoid.configuration[action.configKey] })
        return shown.length > 0 ? shown : sorted
    }

    Translator { id: translator; language: Plasmoid.configuration.language }

    Plasmoid.icon: "system-shutdown"
    toolTipMainText: translator.t("app.name")
    toolTipSubText: selectedId >= 0
        ? translator.t("tooltip.countdown", translator.t("action." + allActions[selectedId].name), remaining)
        : ""

    function startConfirmation(id) {
        selectedId = id
        remaining = countdownSeconds
        expanded = false
        timer.restart()
    }

    function cancel() {
        timer.stop()
        selectedId = -1
        remaining = countdownSeconds
    }

    function execute() {
        var command = allActions[selectedId].command
        cancel()
        runner.run(command)
    }

    Timer {
        id: timer
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining--
            if (root.remaining <= 0)
                root.execute()
        }
    }

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => disconnectSource(sourceName)
        function run(command) { connectSource(command) }
    }

    // Output: full name|login name|home directory|avatar path.
    // The avatar is the most recently modified existing candidate: a picture set by the user is
    // normally newer than a default one shipped by the distribution.
    Plasma5Support.DataSource {
        id: userInfo
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var fields = (data["stdout"] || "").trim().split("|")
            if (fields.length >= 3) {
                root.loginName = fields[1]
                root.displayName = fields[0] !== "" ? fields[0] : fields[1]
                root.homeDir = fields[2]
                root.avatarPath = fields.length >= 4 ? fields[3] : ""
            }
            disconnectSource(sourceName)
        }
    }

    Component.onCompleted: userInfo.connectSource(
        "u=$(id -un); "
        + "printf '%s|%s|%s|' \"$(getent passwd \"$u\" | cut -d: -f5 | cut -d, -f1)\" \"$u\" \"$HOME\"; "
        + "set --; "
        + "for f in \"$HOME/.face.icon\" \"$HOME/.face\" \"/var/lib/AccountsService/icons/$u\" \"/usr/share/sddm/faces/$u.face.icon\"; do "
        + "[ -f \"$f\" ] && set -- \"$@\" \"$f\"; done; "
        + "[ $# -gt 0 ] && ls -tL -- \"$@\" | head -n 1")

    // ---- fullscreen, dimmed confirmation window ----
    Window {
        id: confirmWindow
        visibility: root.selectedId >= 0 ? Window.FullScreen : Window.Hidden
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "#d9000000"

        onVisibleChanged: {
            if (visible) {
                requestActivate()
                cancelButton.forceActiveFocus()
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.cancel()

            // swallows stray clicks so the window cannot be dismissed by clicking beside it
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing * 2

                // profile picture
                Item {
                    id: avatarArea
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 8

                    Image {
                        id: photo
                        anchors.fill: parent
                        source: root.avatarUrl
                        cache: false
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 512
                        sourceSize.height: 512
                        visible: false
                    }
                    Rectangle {
                        id: mask
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                        layer.enabled: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: photo
                        maskEnabled: true
                        maskSource: mask
                        visible: photo.status === Image.Ready
                    }
                    // placeholder: the initial of the user's name, not a theme icon
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        visible: photo.status !== Image.Ready

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            text: root.displayName.charAt(0).toUpperCase()
                            color: "white"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 4
                            font.bold: true
                        }
                    }
                }

                // name
                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.displayName
                    color: "white"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                    font.bold: true
                }

                // question
                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.selectedId >= 0
                        ? translator.t("confirm." + root.allActions[root.selectedId].name)
                        : ""
                    color: "white"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                }

                // buttons
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.largeSpacing

                    PlasmaComponents3.Button {
                        id: yesButton
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        text: translator.t("button.yes", root.remaining)
                        icon.name: "dialog-ok"
                        onClicked: root.execute()

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Item { Layout.fillWidth: true }
                            Kirigami.Icon {
                                source: yesButton.icon.name
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents3.Label { text: yesButton.text }
                            Item { Layout.fillWidth: true }
                        }
                    }
                    PlasmaComponents3.Button {
                        id: cancelButton
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        text: translator.t("button.cancel")
                        icon.name: "dialog-cancel"
                        focus: true
                        onClicked: root.cancel()

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Item { Layout.fillWidth: true }
                            Kirigami.Icon {
                                source: cancelButton.icon.name
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents3.Label { text: cancelButton.text }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ---- tray panel: the shown actions fill the panel in equal bands ----
    fullRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 16
        implicitHeight: Kirigami.Units.gridUnit * 2.8 * root.visibleActions.length

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 0

            Repeater {
                model: root.visibleActions
                delegate: PlasmaComponents3.ItemDelegate {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onClicked: root.startConfirmation(modelData.id)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Item { Layout.fillWidth: true }
                        Kirigami.Icon {
                            source: modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        PlasmaComponents3.Label {
                            text: translator.t("action." + modelData.name)
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
