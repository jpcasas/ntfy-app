# Notify

A native iOS client for [ntfy](https://ntfy.sh) — the simple pub-sub
notification service. Manage topics, browse and send messages, and receive
push notifications, all from a small SwiftUI app.

## Features

- **Topics** — save, browse, and delete the ntfy topics you care about.
- **Message history** — persisted locally on-device, so you don't lose
  history once it expires on the server. Reconnecting only fetches new
  messages instead of replaying everything.
- **Live updates** — subscribes to each topic's stream while you're viewing
  it, with a clear connecting / live / error status.
- **Pin & delete** — swipe to pin important messages (with a dedicated
  "Pinned" tab across all topics) or delete ones you don't need.
- **Send** — compose and publish messages with title and priority.
- **Localized** — UI available in Spanish, English, French, German, Italian,
  Portuguese (BR), Japanese, Simplified Chinese, Russian, and Arabic.
- Works against any ntfy server, public (`ntfy.sh`) or self-hosted, with
  optional username/password authentication.

## Requirements

- Xcode 16+
- iOS 17.0 or later — runs on iPhone and iPad (roughly iPhone XS/XR and
  newer, or any device that can update to iOS 17)
- A free or paid Apple ID to build and run on your own device

## Getting started

1. Open `Notify.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your own team under "Team" so Xcode
   can sign the app for your device.
3. Build and run (`⌘R`) on the Simulator, or on your iPhone connected over
   USB.
4. In the app's **Settings** tab, the server defaults to the public
   `https://ntfy.sh` — change it if you run your own ntfy server, and add
   username/password if that server requires authentication.
5. Add a topic in the **Topics** tab, then send a message from **Send** or
   subscribe to it from another ntfy client to see it show up live.

## Project structure

- `Notify/ContentView.swift` — the entire app: views, local stores
  (`TopicsStore`, `MessageStore`), and the ntfy networking calls. Kept as one
  file deliberately, since Xcode's file-system-synchronized project format
  doesn't require registering new files individually.
- `Notify/NotifyApp.swift` — app entry point.
- `Notify/Localizable.xcstrings` — the String Catalog with all UI
  translations.
- `Notify/Assets.xcassets` — app icon and accent color.

## How message persistence works

Messages are stored as JSON in the app's Application Support directory, keyed
by topic. When you open a topic, the app shows what's saved immediately, then
reconnects to the ntfy server using `since=<last saved message time>` instead
of replaying the full history — so it only fetches what's new.

## License

MIT — see [LICENSE](LICENSE).

## Author

JP Casas — [jpcasas@gmail.com](mailto:jpcasas@gmail.com)
