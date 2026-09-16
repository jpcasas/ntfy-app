# Privacy Policy

**Effective date: September 16, 2026**

Notify ("the app") is a client for [ntfy](https://ntfy.sh), an independent
open-source notification service. This policy explains what data the app
handles and how.

## Summary

**We do not collect, store, or have access to any of your data.** Notify has
no backend server of its own. Everything you enter stays on your device,
except for the messages you explicitly choose to send or subscribe to, which
go directly to the ntfy server you configure.

## What the app stores, and where

The following information is saved locally on your device only, using
standard iOS storage (`UserDefaults` and the app's local file storage). It is
never transmitted to us, and we have no way to access it:

- The ntfy server address you configure (defaults to the public `ntfy.sh`)
- The username and password you optionally enter for that server
- The list of topics you add
- The history of messages you send or receive, so it survives even after it
  expires on the server

## What the app sends over the network, and to whom

The only network requests the app makes are directly to the ntfy server
address you configure, to:

- Publish a message when you use the Send tab
- Subscribe to a topic's live stream and history when you open it in the
  Topics tab

If you use the public `ntfy.sh` service, that request goes to ntfy.sh's
servers, governed by [ntfy's own privacy policy](https://ntfy.sh/). If you
point the app at your own self-hosted server, the request goes only there.
The app itself never routes your data through any third-party server.

Basic authentication credentials (username/password), if you set them, are
sent only to the server address you specified, using standard HTTP Basic
Authentication over HTTPS.

## Analytics, tracking, and third parties

Notify contains no analytics, no crash reporting, no advertising SDKs, and no
third-party trackers of any kind.

## Data deletion

Since all data lives on your device, you can delete it at any time by:

- Deleting a topic (also removes its saved message history) from within the
  app
- Deleting the app itself, which removes all locally stored data

## Children's privacy

Notify does not knowingly collect any information from anyone, including
children, since it collects no information at all.

## Changes to this policy

If this policy changes, the updated version will be published at this same
location with a new effective date.

## Contact

Questions about this policy can be sent to
[jpcasas@gmail.com](mailto:jpcasas@gmail.com).
