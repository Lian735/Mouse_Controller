# Mouse Controller

Mouse Controller is a macOS menu-bar companion that lets you drive the pointer, scrolling, and shortcuts with a game controller. It listens to standard GameController inputs and maps sticks and buttons to mouse actions and keyboard/system shortcuts so you can navigate the desktop from the couch.

> ⚠️ Note from the app UI: Mouse Controller is not yet optimized for playing games. It is designed for desktop navigation and quick actions.

## Highlights

- **Controller-driven pointer** with adjustable speed, acceleration, and deadzone.
- **Scroll with the second stick** (vertical + optional horizontal scroll).
- **Custom shortcuts**: map controller buttons (including D‑pad and stick directions) to mouse clicks or keyboard/system shortcuts.
- **Stick swapping**: choose which stick controls the pointer vs. scrolling.
- **Haptic feedback** when adding shortcuts (supported controllers only).
- **Launch at login** option.

## Requirements

- macOS with the GameController framework available (macOS 11+ recommended).
- A compatible controller (extended or micro gamepad supported by macOS).
- Accessibility permission so the app can control the mouse and send input.

## Installation

The author’s installation walkthrough is available here:

- 🎥 **Installation tutorial**: https://www.youtube.com/watch?v=veaml3lK3_8

If you are building from source, use the steps in the next section.

## Build & Run (from source)

1. Open `Mouse Controller.xcodeproj` in Xcode.
2. Select the **Mouse Controller** target.
3. Build and run the app on macOS.
4. When macOS prompts for Accessibility permission, allow it:
   - **System Settings → Privacy & Security → Accessibility** → enable **Mouse Controller**.

## First‑Run Setup

1. **Connect a controller** (Bluetooth or USB). The app will display the controller name in the General tab.
2. **Enable Mouse Controller** using the toggle at the top of the General tab.
3. Adjust pointer and scroll settings:
   - Cursor speed, acceleration, and deadzone
   - Scroll speed, vertical/horizontal scroll, and inversion
4. (Optional) **Swap sticks** if you want the right stick to control the pointer.

## Shortcuts

The **Shortcuts** tab lets you map controller inputs to actions.

- Click **Add Shortcut** and press a controller button or stick direction.
- Assign the action:
  - **Mouse**: left/right/middle click
  - **Keyboard/System**: combinations with modifiers or special keys (e.g., Mission Control, volume, media keys)
- Use **Delete All Shortcuts** to reset mappings.

Default mappings are provided for:

- **Button A → Left Click**
- **Button B → Right Click**

## Tips & Troubleshooting

- If nothing happens when moving sticks, confirm **Accessibility** permission is enabled.
- If scrolling feels too fast or too slow, tune **Scroll speed** and **Deadzone**.
- Custom shortcuts temporarily disable pointer/scroll on the mapped stick while they’re active to prevent conflicts.

## Project Structure

Key areas to explore if you’re extending the app:

- `Mouse Controller/ControllerMouseService.swift` — controller input polling, pointer movement, scrolling, and haptics.
- `Mouse Controller/SettingsView.swift` — UI for settings and shortcut management.
- `Mouse Controller/Shortcuts.swift` — shortcut models, serialization, and key mapping.
- `Mouse Controller/AppSettings.swift` — persisted preferences.

## License

No license file is currently included in this repository. Add a LICENSE file if you plan to redistribute.
