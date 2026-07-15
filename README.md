# DailyKanban

A simple, lightweight daily task organizer. Local and easy to use.

A Flutter kanban board for daily task prioritization.

## Features

- **5-column kanban** — Backlog, Light, Important, Urgent, Done
- **Drag & drop** — move tasks between columns
- **Dual themes** — toggle between cool (green/blue) and warm (yellow/pink) gradients, persisted to device
- **Task editor** — add/edit tasks with notes, subtasks, and importance level
- **Midnight rollover** — unfinished tasks automatically reset to Backlog
- **100% local** — all data stored on-device via SharedPreferences, no server or account needed
- **Native share** — export tasks to any app via the system share sheet
- **Custom icon** — personalized launcher icon

## Build

```sh
flutter build apk --release --target-platform android-arm64
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`
