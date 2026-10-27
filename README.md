# Power Menu (Kapcsolófedél)

[English](README.md) | [Magyar](README.hu.md)

A KDE Plasma 6 system tray widget with **Sleep, Hibernate, Restart, Shut down and Log out**. Every action asks for confirmation on a dimmed fullscreen screen that shows your profile picture and name, with a countdown on the **Yes** button. If you forget to click, the action happens when the countdown reaches zero (or you cancel it).

It does not depend on systemd: the commands are tried one after the other, so the same widget is meant to work on systemd and on elogind based systems (OpenRC, runit, s6, dinit) and on different distributions.

> **Status:** developed and tested on Artix Linux (OpenRC) with KDE Plasma 6 only. Other distributions and init systems are supported by design but have not been tested.

## Features

- Tray panel with the five actions, centered
- Confirmation on a dimmed fullscreen overlay: profile picture, name, question, **Yes (60 s)** / **Cancel**; clicking beside the buttons does not dismiss it, `Esc` cancels
- The countdown is also shown in the tray icon's tooltip
- Settings page: choose which actions are shown (at least one must stay selected), reorder them with a drag handle, choose the language
- Translations are plain JSON files; a new language needs no build step
- Works as a real system tray item, so the tray settings decide when it is shown

## Requirements

- KDE Plasma 6
- `dbus-send` (part of the `dbus` package, present on practically every desktop system)
- Optional: `qdbus6` / `qdbus-qt6` / `qdbus`
- A logind compatible session service (systemd-logind or elogind) is recommended. Without it, shutting down and restarting only work if `sudo` or `doas` runs them without asking for a password.

## Installation

```sh
git clone https://github.com/summoner001/KDE-Power-Menu-Plasmoid.git
cd KDE-Power-Menu-Plasmoid
kpackagetool6 --type Plasma/Applet --install .
```

Then restart Plasma: log out and in again, or run `plasmashell --replace &`.

If you do not use git, download the ZIP from GitHub (**Code → Download ZIP**), extract it and run the `kpackagetool6` command in that folder.

### Show it in the system tray

1. Right click the system tray → **Configure System Tray…** → **Entries**.
2. Find **Power Menu** and set when it should be shown (for example *Shown when relevant*, *Always shown*, *Only show in popup*).

If the widget is missing from the list or set to *Disabled*, enable it there. This is a setting of the tray, not of the widget.

### Update

```sh
cd KDE-Power-Menu-Plasmoid
git pull
kquitapp6 plasmashell
kpackagetool6 --type Plasma/Applet --upgrade .
kstart plasmashell
```

Stopping Plasma first is recommended: replacing the files while Plasma runs can make the system tray forget the widget.

### Uninstall

```sh
kpackagetool6 --type Plasma/Applet --remove io.github.summoner001.powermenu
```

## Settings

Right click the tray icon → **Configure Power Menu…**

- **Item list:** tick the actions to show; drag the handle on the left to change the order. The last ticked item cannot be unticked.
- **Language:** *Automatic* follows the system language; every language file found in `contents/locale/` is listed by its own name.

Press **Apply** to save.

The profile picture is taken from the most recently modified file among `~/.face.icon`, `~/.face`, `/var/lib/AccountsService/icons/<user>` and `/usr/share/sddm/faces/<user>.face.icon`. If none exists, a circle with the first letter of your name is shown.

## Adding a language

1. Copy `contents/locale/en-US.json` to `contents/locale/<language>-<REGION>.json`, for example `de-DE.json`.
2. Set `"language.name"` to the name of the language in that language (for example `"Deutsch"`) and translate the values. Do not change the keys.
3. `%s` is a placeholder and is replaced in order by the widget (for example the remaining seconds). Keep it in the translated text.

The widget picks the file for the system language (`de-DE`, then any `de-*.json`), or the language chosen in the settings. A missing key falls back to English. The new language shows up in the settings without rebuilding anything.

## How the actions are executed

Each action is a chain of commands; the first one that exists and succeeds is used. For example, for shutting down: KDE's own `org.kde.Shutdown` service, then `loginctl`, `systemctl`, a direct call to `org.freedesktop.login1` over D-Bus, and finally `sudo -n` / `doas -n` with the plain command. Sleep and hibernate use the same idea (`loginctl`, KDE PowerDevil, `systemctl`, logind over D-Bus, `pm-suspend`, `zzz`).

Hibernation only works if the system itself is set up for it (large enough swap and a `resume=` kernel parameter with the matching initramfs hook).

## Repository layout

```
LICENSE
README.md
README.hu.md
metadata.json
contents/
├── config/   settings model and stored values
├── locale/   translations (JSON)
└── ui/       the widget and the settings page
```

`contents/ui/Translator.qml` and `contents/config/Translator.qml` must stay identical: the settings model can only see types in its own folder.

## Troubleshooting

- **Nothing happens after installing:** restart Plasma (see above).
- **The widget is not in the tray:** check **Configure System Tray… → Entries**.
- **A label shows a key such as `action.sleep`:** the language file could not be read; check that `contents/locale/en-US.json` exists and is valid JSON.
- **QML errors:** start Plasma from a terminal with `plasmashell --replace` and read the output.

Bug reports and pull requests are welcome in the [issue tracker](https://github.com/summoner001/KDE-Power-Menu-Plasmoid/issues).

## License

GNU General Public License v2.0, see [LICENSE](LICENSE).
