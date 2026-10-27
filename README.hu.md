# Kapcsolófedél (Power Menu)

[English](README.md) | [Magyar](README.hu.md)

KDE Plasma 6 rendszertálca-widget **alvás, hibernálás, újraindítás, leállítás és kijelentkezés** műveletekkel. Mindegyik művelet előtt egy elsötétített, teljes képernyős ablak kér megerősítést, rajta a felhasználó profilképével és nevével, az **Igen** gombon visszaszámlálással. Ha elfelejtesz kattintani, a művelet a számláló lejártakor végrehajtódik (vagy megszakíthatod).

Nem függ a systemd-től: a parancsokat egymás után próbálja, ezért ugyanaz a widget systemd és elogind alapú rendszereken (OpenRC, runit, s6, dinit) és különböző disztribúciókon is működhet.

> **Állapot:** csak Artix Linuxon (OpenRC), KDE Plasma 6 alatt fejlesztettem és próbáltam ki. Más disztribúciókat és init rendszereket a felépítése támogat, de nem teszteltem őket.

## Tulajdonságok

- Tálcapanel az öt művelettel, középre rendezve
- Megerősítés elsötétített, teljes képernyős ablakon: profilkép, név, kérdés, **Igen (60 mp)** / **Mégse**; a gombok melletti kattintás nem zárja be, az `Esc` megszakítja
- A visszaszámlálás a tálcaikon tooltipjében is látszik
- Beállítások oldal: kiválasztható, mely műveletek jelenjenek meg (legalább egynek maradnia kell), fogantyúval átrendezhetők, a nyelv megválasztható
- A fordítások egyszerű JSON fájlok, új nyelvhez nem kell semmit építeni
- Valódi rendszertálca-elem, ezért a tálca beállításai döntenek arról, mikor jelenjen meg

## Követelmények

- KDE Plasma 6
- `dbus-send` (a `dbus` csomag része, gyakorlatilag minden asztali rendszeren megvan)
- Opcionális: `qdbus6` / `qdbus-qt6` / `qdbus`
- Logind-kompatibilis munkamenet-szolgáltatás (systemd-logind vagy elogind) ajánlott. Nélküle a leállítás és az újraindítás csak akkor működik, ha a `sudo` vagy a `doas` jelszó nélkül futtatja őket.

## Telepítés

```sh
git clone https://github.com/summoner001/KDE-Power-Menu-Plasmoid.git
cd KDE-Power-Menu-Plasmoid
kpackagetool6 --type Plasma/Applet --install .
```

Utána indítsd újra a Plasmát: jelentkezz ki és be, vagy futtasd: `plasmashell --replace &`.

Ha nem használsz gitet, töltsd le a ZIP-et a GitHubról (**Code → Download ZIP**), csomagold ki, és abban a mappában futtasd a `kpackagetool6` parancsot.

### Megjelenítés a rendszertálcában

1. Jobb klikk a rendszertálcán → **Rendszertálca beállítása…** → **Elemek**.
2. Keresd meg a **Kapcsolófedél** (Power Menu) bejegyzést, és állítsd be, mikor jelenjen meg (például *Megjelenítés, ha releváns*, *Mindig jelenjen meg*, *Csak felugróban jelenjen meg*).

Ha a widget nincs a listában, vagy *Letiltva* állapotú, itt kapcsold be. Ez a tálca beállítása, nem a widgeté.

### Frissítés

```sh
cd KDE-Power-Menu-Plasmoid
git pull
kquitapp6 plasmashell
kpackagetool6 --type Plasma/Applet --upgrade .
kstart plasmashell
```

Érdemes előbb leállítani a Plasmát: ha a fájlok a Plasma futása közben íródnak át, a rendszertálca elfelejtheti a widgetet.

### Eltávolítás

```sh
kpackagetool6 --type Plasma/Applet --remove io.github.summoner001.powermenu
```

## Beállítások

Jobb klikk a tálcaikonon → **Kapcsolófedél beállítása…**

- **Elemlista:** pipáld ki a megjelenítendő műveleteket, a bal oldali fogantyúval húzva változtathatod a sorrendet. Az utolsó kipipált elemet nem lehet kikapcsolni.
- **Nyelv:** az *Automatikus* a rendszer nyelvét követi, a `contents/locale/` mappában talált minden nyelvi fájl a saját nevén szerepel a listában.

A mentéshez nyomd meg az **Alkalmaz** gombot.

A profilkép a `~/.face.icon`, `~/.face`, `/var/lib/AccountsService/icons/<felhasználó>` és `/usr/share/sddm/faces/<felhasználó>.face.icon` fájlok közül a legutóbb módosítottból jön. Ha egyik sem létezik, a neved első betűje látszik egy színes körben.

## Új nyelv hozzáadása

1. Másold le a `contents/locale/en-US.json` fájlt `contents/locale/<nyelv>-<RÉGIÓ>.json` néven, például `de-DE.json`.
2. A `"language.name"` értéke legyen a nyelv neve azon a nyelven (például `"Deutsch"`), a többi értéket fordítsd le. A kulcsokat ne változtasd.
3. A `%s` helyőrző, ennek helyére a widget sorban behelyettesít egy értéket (például a hátralévő másodperceket). Hagyd benne a fordított szövegben.

A widget a rendszer nyelvének megfelelő fájlt választja (`de-DE`, majd bármelyik `de-*.json`), vagy a beállításokban kiválasztott nyelvet. A hiányzó kulcs angolul jelenik meg. Az új nyelv build nélkül megjelenik a beállításokban.

## Hogyan hajtódnak végre a műveletek

Minden művelet egy parancsláncot használ, az első létező és sikeres parancs nyer. A leállításnál például: a KDE saját `org.kde.Shutdown` szolgáltatása, majd a `loginctl`, a `systemctl`, közvetlen D-Bus hívás az `org.freedesktop.login1`-nek, végül a `sudo -n` / `doas -n` az alap paranccsal. Az alvás és a hibernálás ugyanígy épül fel (`loginctl`, KDE PowerDevil, `systemctl`, logind D-Buson, `pm-suspend`, `zzz`).

A hibernálás csak akkor működik, ha maga a rendszer is fel van készítve rá (elég nagy swap és `resume=` kernelparaméter a hozzá tartozó initramfs hook-kal).

## A repó felépítése

```
LICENSE
README.md
README.hu.md
metadata.json
contents/
├── config/   beállítási modell és tárolt értékek
├── locale/   fordítások (JSON)
└── ui/       a widget és a beállítások oldala
```

A `contents/ui/Translator.qml` és a `contents/config/Translator.qml` fájlnak azonosnak kell maradnia: a beállítási modell csak a saját mappájában lévő típusokat látja.

## Hibaelhárítás

- **Telepítés után nem történik semmi:** indítsd újra a Plasmát (lásd fent).
- **A widget nincs a tálcában:** nézd meg a **Rendszertálca beállítása… → Elemek** listát.
- **Egy felirat kulcsként jelenik meg (például `action.sleep`):** a nyelvi fájl nem olvasható, ellenőrizd, hogy a `contents/locale/en-US.json` létezik és érvényes JSON.
- **QML hibák:** indítsd a Plasmát terminálból a `plasmashell --replace` paranccsal, és olvasd el a kimenetet.

Hibabejelentést és pull requestet szívesen fogadok a [hibakövetőben](https://github.com/summoner001/KDE-Power-Menu-Plasmoid/issues).

## Licenc

GNU General Public License v2.0, lásd a [LICENSE](LICENSE) fájlt.
