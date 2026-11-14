<p align="center">
 <picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/icons/logo_eink.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/icons/logo_eink.png">
  <img width=120px height=120px src="assets/icons/logo_eink.png" alt="Tsumiru e-ink logo"/>
 </picture>
</p>

<h1 align="center">Tsumiru-Eink</h1>

> **⚠️ Dedicated e-ink fork.** Tsumiru-Eink is a fork of Tsumiru, optimized
> for e-ink readers (Meebook M103, Onyx Boox, Hisense, Bigme, …): a monochrome
> paper-white theme, no animations / transparency / shadows, paged reading, and
> native EPD full refresh on supported devices.

<p align="center">A manga reader for your Suwayomi server, tuned for e-ink devices</p>

> *Tsumiru* (積みる) takes the 積, "pile up", from *tsundoku* (積ん読), the Japanese habit of buying books faster than you can read them. It swaps the "read" for *miru*, "to look".

## About

Tsumiru is a client for Suwayomi-Server, so you'll need a server running first. Your library and reading progress are stored on the server, and Tsumiru reads them on Android, iOS, Linux, Windows, macOS or the web.

## Features

- **Offline reading.** Download chapters to your device and read them without a connection. When the server is unreachable, Tsumiru opens the copies on your device.
- **Webtoon reader.** Chapters scroll into each other, and pinch-to-zoom keeps working mid-scroll.
- **Guided setup.** The first launch looks for your server on the local network and connects to it.
- **Incognito mode.** Read without adding to your history. Library categories can be hidden too.
- **Themes.** 13 built-in themes, a custom accent colour and a pure black mode for OLED screens.
- **Server login.** Supports the server's `simple_login` and `ui_login` modes and keeps credentials in the device's secure storage.
- **Library tools.** Sort by last read, latest chapter or chapter count, filter by status and bookmarks, and download chapter ranges in bulk.

## Translations

Tsumiru is translated on Hosted Weblate. Pick your language there to fix or add translations.

## Contributing

Pull requests are welcome. For larger changes, open an issue first so we can talk it through. Build steps are in the [contributing guide](CONTRIBUTING.md).

## Related projects

- Suwayomi-Server: the server Tsumiru connects to. It runs the sources and extensions and stores your library.
- Suwayomi-Server-docker: the official Docker image, the quickest way to run the server on a home server or NAS.

## Contributors

Thank you to everyone who has contributed to Tsumiru and to Tachidesk-Sorayomi before it.

## Disclaimer

Tsumiru hosts no content and has no affiliation with any content provider. It shows what your own Suwayomi server provides.

## Credits and license

Tsumiru started as a fork of Tachidesk-Sorayomi and depends on Suwayomi-Server. Thanks to everyone who built and maintains both.

The app typeface is Inter by Rasmus Andersson, bundled (Regular, Medium, SemiBold) under the SIL Open Font License 1.1. See [assets/fonts/inter/OFL.txt](assets/fonts/inter/OFL.txt). It is also registered with the app's licence list at startup, like the Font Awesome licence.

Licensed under the [Mozilla Public License 2.0](LICENSE). Source files keep their MPL-2.0 headers.
