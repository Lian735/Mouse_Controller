# Mouse Controller

Mouse Controller is a macOS menu-bar companion that lets you drive the pointer, scrolling, and shortcuts with a game controller. It listens to standard GameController inputs and maps sticks and buttons to mouse actions and keyboard/system shortcuts so you can navigate the desktop from the couch.

> ⚠️ Note from the app UI: Mouse Controller is not yet optimized for playing games. It is designed for desktop navigation and quick actions.

## Highlights

- **Controller-driven pointer** with adjustable speed, acceleration, and deadzone.
- **Scroll with the second stick** (vertical + optional horizontal scroll).
- **Custom shortcuts**: map controller buttons (including D‑pad and stick directions) to mouse clicks or keyboard/system shortcuts.

## Requirements

- macOS 26(Tahoe)+
- A compatible controller (extended or micro gamepad supported by macOS).
- Accessibility permission so the app can control the mouse and send input.

## Installation

The author’s installation walkthrough is available here:

- 🎥 **Installation tutorial**: https://www.youtube.com/watch?v=veaml3lK3_8

## How to Install

1. Go to the (releases)[https://github.com/Lian735/Mouse_Controller/releases]
2. Download the latest .dmg file
3. Drag the App into the Applications folder
4. Open "Mouse Controller" from the Applications folder
5. A warning will show up
6. Go to System Settings -> Privacy & Security -> Scroll down until you see ""Mouse Controller" was blocked to protect your Mac." -> Click on "Open Anyway"
   It should work now!

   If it doesn't work or you have questions, join this Discord Server: https://discord.gg/u63YhXD3pC 

## First‑Run Setup

1. **Connect a controller** (Bluetooth or USB). The app will display the controller name in the Menu.
2. **Enable Mouse Controller** using the toggle at the top of the General tab, it should be enabled automatically.
3. Adjust pointer and scroll settings:
   - Cursor speed, acceleration, and deadzone (put deadzone to 0 if you want the best experience)
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
- Custom shortcuts temporarily disable pointer/scroll on the mapped stick while they’re active to prevent conflicts. If you remove them tho, pointing/scrolling works again.
