# JSON Viewer

A small Android app for viewing and editing `.json` files, the JSON
counterpart of Markdown Viewer. It shows up as an **"Open with"** option for
JSON files in file managers, mail apps and so on.

## Features

- **View**: collapsible tree with syntax colors, a summary line (type, number of keys, size)
  - tap an object or array to expand or collapse it, tap a value to see it in full
  - long-press any node to copy its value, path (`$.users[0].name`) or key
  - search keys and values (matching nodes are highlighted and their parents expanded)
  - expand all / collapse all, or switch to formatted text
- **Edit**: plain-text editor with syntax highlighting, live validation (line and column
  of the error, tap to jump there), a symbol bar for `{ } [ ] " : ,` and Format / Minify
- **Split view**: editor and tree side by side (on a tablet) or stacked (on a phone), updating live
- Save back to the opened file, *Save as…*, *New*, *Open file*
- Asks before throwing away unsaved changes
- A− / A+ text size, light and dark theme

## How it works

| Part | File |
| --- | --- |
| Intent filters (`application/json`, `*.json`, share sheet) | `android/app/src/main/AndroidManifest.xml` |
| Reading intents, SAF open / save as, writing back | `android/app/src/main/kotlin/com/nicolas/json_viewer/MainActivity.kt` |
| Platform channel `json_viewer/file` (Dart side) | `lib/src/file_bridge.dart` |
| Screen, modes, save / discard logic | `lib/src/viewer_page.dart` |
| Tree view, search | `lib/src/json_tree_view.dart` |
| Editor, symbol bar, status line | `lib/src/json_editor.dart` |
| Parsing, errors, paths, formatting | `lib/src/json_tools.dart` |
| Syntax highlighting | `lib/src/json_highlighter.dart` |

The app has no third-party Dart packages. File access goes through the Android
Storage Access Framework directly, so a file opened via *Open file* or
*Save as* stays writable.

## Build

```sh
flutter test
flutter build apk --release --split-per-abi
```

The GitHub Actions workflow (`.github/workflows/build.yml`) runs analyze and tests,
builds the APKs and uploads them as an artifact.

The release build is signed with the debug key (Flutter default). Set up your own
signing config in `android/app/build.gradle.kts` before publishing.
