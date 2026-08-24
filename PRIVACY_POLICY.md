# Privacy Policy — Dally

**Last updated:** 24 August 2026
**Applies to:** Dally for Android (`com.grs.dally`)

## The short version

Dally collects nothing, sends nothing, and needs no account.

Everything the app remembers — your theme, your settings, your saved games,
your stats and your play history — is stored only on your device, in Dally's
own private app storage. None of it is transmitted anywhere, because Dally has
no way to transmit anything.

## What Dally collects about you

**Nothing.** There is no analytics SDK, no crash reporting, no advertising
identifier, no telemetry, and no account system. We do not know how many people
use Dally, which games they play, or whether they are enjoying themselves.

## What Dally stores on your device

All of it stays in Dally's private app storage, readable only by Dally:

| What | Why |
|---|---|
| Theme and app settings | So the app looks and behaves the way you left it |
| Per-game style choices | So your chosen chess pieces, dice, coin, etc. persist |
| Saved games in progress | So you can resume a board later |
| Personal bests and statistics | So the Stats screen can show your records |
| Play history | The most recent 200 finished sessions, for the Activity screen |
| Player names you type | E.g. in Dots & Boxes or Mafia — stored only for that session's setup |

This data never leaves the device. Uninstalling Dally deletes all of it.

## Permissions

The released Dally app declares **no Android permissions at all** — including
no internet permission. It cannot make a network request even if it wanted to.

For transparency: the `INTERNET` permission appears in Dally's *debug* and
*profile* build files. That is a Flutter development default, used only so a
developer's computer can talk to a test build over USB during development. It
is not present in the release build published to users.

## No network requests

Dally makes no network calls of any kind. Fonts, game icons, chess rules, word
lists and every generated puzzle are bundled into the app or produced on your
device. Nothing is fetched at runtime.

## Children

Dally is suitable for all ages. Because it collects no data whatsoever, it
collects no data from children either.

## Third parties

Dally shares data with no one, because it has no data to share. There are no
advertising networks, no analytics providers, and no cloud services involved.

Dally is built with open-source software, including the Flutter framework and
the `dartchess` library for chess rules. These are compiled into the app; they
are not services, and they do not receive any information about you.

## Your control over your data

- **Reset stats and history:** available in the app's settings.
- **Delete everything:** uninstall Dally. Android removes all of its local
  storage with it.

There is nothing to request, export or delete from a server, because no server
holds anything about you.

## Changes to this policy

If this policy ever changes, the updated version will ship with the app and the
date at the top will change. If a future version of Dally ever needed a network
connection, that would be stated here plainly and in the app before it happened.

## Contact

Questions about this policy: **gautamsingh1997@gmail.com**
