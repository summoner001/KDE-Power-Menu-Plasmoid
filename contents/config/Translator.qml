import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

// Loads the strings of the best matching file in contents/locale.
// Lookup order: the chosen language (e.g. hu-HU) or, if empty, the system locale;
// then the same language (hu.json or hu-*.json); then en-US.json.
// en-US.json is always loaded as a base, so a missing key falls back to English.
Item {
    id: translator

    visible: false
    width: 0
    height: 0

    // language file to use, e.g. "hu-HU"; empty means "follow the system locale"
    property string language: ""
    property bool loaded: false
    property bool started: false
    property var strings: ({})

    // t("button.yes", 57): every %s is replaced by the next argument, in order
    function t(key) {
        if (!loaded)
            return ""
        var text = strings[key]
        if (text === undefined)
            return key
        for (var i = 1; i < arguments.length; i++) {
            var value = String(arguments[i])
            text = text.replace("%s", function () { return value })
        }
        return text
    }

    function parse(text) {
        try {
            return JSON.parse(text)
        } catch (e) {
            return {}
        }
    }

    function load() {
        var raw = language !== "" ? language : Qt.locale().name
        var tag = raw.replace("_", "-").replace(/[^A-Za-z0-9-]/g, "")
        var dir = decodeURIComponent(String(Qt.resolvedUrl("../locale")).replace(/^file:\/\//, ""))
        dir = dir.replace(/'/g, "'\\''")
        reader.connectSource(
            "d='" + dir + "'; t='" + tag + "'; l=${t%%-*}; "
            + "cat \"$d/en-US.json\"; printf '\\n@@@@\\n'; "
            + "for f in \"$d/$t.json\" \"$d/$l.json\" \"$d\"/$l-*.json; do "
            + "if [ -f \"$f\" ]; then cat \"$f\"; break; fi; done")
    }

    onLanguageChanged: {
        if (started)
            load()
    }

    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var parts = (data["stdout"] || "").split("\n@@@@\n")
            var base = translator.parse(parts[0])
            var chosen = parts.length > 1 ? translator.parse(parts[1]) : {}
            var merged = {}
            var key
            for (key in base)
                merged[key] = base[key]
            for (key in chosen)
                merged[key] = chosen[key]
            translator.strings = merged
            translator.loaded = true
            disconnectSource(sourceName)
        }
    }

    Component.onCompleted: {
        started = true
        load()
    }
}
