import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: page

    property bool cfg_showSleep
    property bool cfg_showHibernate
    property bool cfg_showReboot
    property bool cfg_showShutdown
    property bool cfg_showLogout
    property string cfg_order
    property string cfg_language

    property bool cfg_showSleepDefault: true
    property bool cfg_showHibernateDefault: true
    property bool cfg_showRebootDefault: true
    property bool cfg_showShutdownDefault: true
    property bool cfg_showLogoutDefault: true
    property string cfg_orderDefault: "sleep,hibernate,reboot,shutdown,logout"
    property string cfg_languageDefault: ""

    readonly property var actionNames: ["sleep", "hibernate", "reboot", "shutdown", "logout"]

    // every language file found in contents/locale: [{ code: "hu-HU", name: "Magyar" }, ...]
    property var installedLanguages: []
    readonly property var languageOptions:
        [{ code: "", name: translator.t("settings.language.auto") }].concat(installedLanguages)

    readonly property int selectedCount:
        (cfg_showSleep ? 1 : 0) + (cfg_showHibernate ? 1 : 0)
        + (cfg_showReboot ? 1 : 0) + (cfg_showShutdown ? 1 : 0)
        + (cfg_showLogout ? 1 : 0)

    function isShown(name) {
        switch (name) {
        case "sleep": return cfg_showSleep
        case "hibernate": return cfg_showHibernate
        case "reboot": return cfg_showReboot
        case "shutdown": return cfg_showShutdown
        case "logout": return cfg_showLogout
        }
        return false
    }

    function setShown(name, value) {
        switch (name) {
        case "sleep": cfg_showSleep = value; break
        case "hibernate": cfg_showHibernate = value; break
        case "reboot": cfg_showReboot = value; break
        case "shutdown": cfg_showShutdown = value; break
        case "logout": cfg_showLogout = value; break
        }
    }

    function currentOrder() {
        var result = []
        for (var i = 0; i < listModel.count; i++)
            result.push(listModel.get(i).actionName)
        return result.join(",")
    }

    function loadOrder(text) {
        var wanted = []
        text.split(",").forEach(function (name) {
            if (actionNames.indexOf(name) >= 0 && wanted.indexOf(name) < 0)
                wanted.push(name)
        })
        actionNames.forEach(function (name) {
            if (wanted.indexOf(name) < 0)
                wanted.push(name)
        })
        if (wanted.join(",") === currentOrder())
            return
        listModel.clear()
        wanted.forEach(function (name) {
            listModel.append({ actionName: name })
        })
    }

    function saveOrder() {
        cfg_order = currentOrder()
    }

    function languageIndex() {
        for (var i = 0; i < languageOptions.length; i++) {
            if (languageOptions[i].code === cfg_language)
                return i
        }
        return 0
    }

    // used when a language file has no "language.name": the name Qt knows for that locale
    function fallbackLanguageName(code) {
        var name = Qt.locale(code).nativeLanguageName
        return name ? name.charAt(0).toUpperCase() + name.slice(1) : code
    }

    function scanLanguages() {
        var dir = decodeURIComponent(String(Qt.resolvedUrl("../locale")).replace(/^file:\/\//, ""))
        dir = dir.replace(/'/g, "'\\''")
        languageScanner.connectSource(
            "d='" + dir + "'; for f in \"$d\"/*.json; do [ -f \"$f\" ] || continue; "
            + "printf '@@FILE@@%s\\n' \"$(basename \"$f\" .json)\"; cat \"$f\"; printf '\\n'; done")
    }

    onCfg_orderChanged: loadOrder(cfg_order)
    Component.onCompleted: {
        loadOrder(cfg_order !== "" ? cfg_order : cfg_orderDefault)
        scanLanguages()
    }

    Plasma5Support.DataSource {
        id: languageScanner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var found = []
            var chunks = (data["stdout"] || "").split("@@FILE@@")
            for (var i = 1; i < chunks.length; i++) {
                var newline = chunks[i].indexOf("\n")
                var code = chunks[i].substring(0, newline).trim()
                var name = ""
                try {
                    name = JSON.parse(chunks[i].substring(newline + 1))["language.name"] || ""
                } catch (e) {
                }
                found.push({ code: code, name: name !== "" ? name : page.fallbackLanguageName(code) })
            }
            found.sort(function (a, b) { return a.name.localeCompare(b.name) })
            page.installedLanguages = found
            disconnectSource(sourceName)
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        ListModel { id: listModel }
        Translator { id: translator; language: page.cfg_language }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: translator.t("settings.heading")
        }

        ListView {
            id: list
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.preferredHeight: contentHeight
            interactive: false
            model: listModel

            delegate: Item {
                id: row
                width: list.width
                height: item.height

                QQC2.ItemDelegate {
                    id: item
                    width: parent.width

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.ListItemDragHandle {
                            listItem: item
                            listView: list
                            onMoveRequested: (oldIndex, newIndex) => {
                                listModel.move(oldIndex, newIndex, 1)
                                page.saveOrder()
                            }
                        }

                        // the last checked item cannot be unchecked
                        QQC2.CheckBox {
                            id: checkBox
                            Layout.fillWidth: true
                            text: translator.t("action." + model.actionName)
                            enabled: !(checked && page.selectedCount <= 1)
                            onToggled: page.setShown(model.actionName, checked)
                        }

                        Binding {
                            target: checkBox
                            property: "checked"
                            value: page.isShown(model.actionName)
                        }
                    }
                }
            }
        }

        // language: "Automatic" plus every locale file found in contents/locale
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                text: translator.t("settings.language")
            }

            QQC2.ComboBox {
                id: languageBox
                model: page.languageOptions
                textRole: "name"
                valueRole: "code"
                onActivated: page.cfg_language = currentValue
            }

            Binding {
                target: languageBox
                property: "currentIndex"
                value: page.languageIndex()
            }
        }
    }
}
