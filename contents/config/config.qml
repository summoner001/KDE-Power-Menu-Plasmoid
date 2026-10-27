import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    id: configModel

    property var translator: Translator {}

    ConfigCategory {
        name: configModel.translator.t("settings.category")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
