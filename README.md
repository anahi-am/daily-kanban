# Daily Kanban

I built this app because I kept losing tasks in my head. Quick thoughts of things I needed to do would surface at random times and dissolve just as fast. But when trying to use productivity apps, I would get overwhelmed: too many features, accounts, data concerns...
I just wanted to capture a thought by importance level.

So I made one:
Something completely offline, private and distraction-free.

A Flutter Kanban board style app to see your daily priorities at a glance.

## UX Philosophy

Daily Kanban was built around the idea that organization tools should minimize friction. Every interaction was designed to reduce cognitive load and be attractive to use.

Rather than following every conventional productivity app pattern, the interface favors simple, lightweight interactions that feel natural and effortless. By reducing visual noise and unnecessary complexity, the app encourages flow and keeps attention on the tasks.

One example is the primary action button. Instead of the traditional floating "+" button, the app uses an outlined circular button. This subtle choice feels less intrusive while naturally inviting the creation of a new task, reinforcing the app's calm, fluid visual language.

## Features

- **5-card kanban**: Achievements, Light, Important, Urgent, Done
- **Drag & drop**: Move tasks between cards.
- **Dual themes**: Toggle between warm (dusty rose → lavender) and cool (soft teal → periwinkle) gradients, persisted to device.
- **Task editor**: Add/edit tasks with notes, subtasks, and importance level.
- **Midnight rollover**: Completed tasks move to Achievements; incomplete tasks persist.
- **100% local**: All data is stored on-device via SharedPreferences, no server or account needed.
- **Native share**: Export tasks to any app via the system share sheet.
- **Custom icon**: Personalized launcher icon.

## How to Use

- **Add tasks**: Tap the circular button at the top to add a new task.
- **Organize**: Drag tasks between cards as priorities shift.
- **Edit & delete**: Tap a task to open it; use ✓ to save or 🗑️ to delete.
- **Subtasks**: Press the outline circle to add subtasks, then tap the checkbox to mark done.
- **Share**: Export any task via your phone's native share sheet.
- **Toggle theme**: Tap the palette icon to switch between warm (dusty rose) and cool (soft teal) themes.
- **See your wins**: Completed tasks move to Achievements at midnight, so you can see what you have accomplished.
- **Persist across days**: Incomplete tasks stay in their cards. Ready to continue tomorrow, no pressure.

## Build

```sh
flutter build apk --release --target-platform android-arm64
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`
