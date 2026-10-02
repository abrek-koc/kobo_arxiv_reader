# Roadmap

These are ideas, not shipped features.

## iPhone link sharing

Add an explicitly enabled, short-lived local receiver to arXiv Reader.
An iOS Share Sheet Shortcut could send the current arXiv URL while phone and Kobo are on the same Wi-Fi.
A small browser form could serve as a fallback.

Implementation should include pairing, bounded requests, strict arXiv ID validation, duplicate handling, clear stop/status controls, and stopping the listener during suspend or reader transitions.
It should store a local inbox and let the user choose when to fetch papers.
No separate hosted service is planned. The current release has no receiver, inbox, or iOS Shortcut.

## Other possibilities

- User-configurable storage location and broader KOReader device support.
- Saved searches, subject preferences, and library filtering.
- Better HTML conversion and scientific-layout validation.
