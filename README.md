# JSON Viewer

A small Android app for viewing and editing `.json` files, the JSON
counterpart of Markdown Viewer. It shows up as an **"Open with"** option for
JSON files in file managers, mail apps and so on.

<p>
  <img src="docs/screenshots/01-phone-readable-light.png" width="200" alt="Readable view">
  <img src="docs/screenshots/04-phone-form-light.png" width="200" alt="Form editor">
  <img src="docs/screenshots/06-phone-text-editor-light.png" width="200" alt="Text editor">
  <img src="docs/screenshots/07-phone-readable-dark.png" width="200" alt="Readable view, dark">
</p>
<p>
  <img src="docs/screenshots/10-landscape-split-dark.png" width="600" alt="Split view">
</p>

Screenshots are taken automatically on an Android emulator by `.github/workflows/screenshots.yml`.

## Features

- **Readable view** (default): the JSON rendered like a document instead of code
  - objects become sections with headings (`studyProgram` → "Study program"), fields become label/value rows
  - lists of similar objects become tables, other lists of objects become cards (titled by `title`, `name`, …),
    short value lists become chips
  - no quotes or brackets: booleans as ✓/✗, colors (`#4F7CAC`) with a swatch, ISO dates formatted, `null` as —
  - sections collapse on tap; long-press anything to copy value, path or key
- **Raw text**: the file exactly as stored, syntax-highlighted and selectable; *Formatted* shows
  minified files indented without changing them
- Switch between readable / tree / raw with the buttons at the top of the view
- **Tree view**: collapsible tree with syntax colors, a summary line (type, number of keys, size)
  - tap an object or array to expand or collapse it, tap a value to see it in full
  - long-press any node to copy its value, path (`$.users[0].name`) or key
  - search keys and values (matching nodes are highlighted and their parents expanded)
  - expand all / collapse all
- **Edit → Form** (default): build or extend JSON without typing syntax
  - every field has an input that fits its type: text, number, a Yes/No switch, "empty" for `null`
  - **Add field** (name + type: Text, Number, Yes/No, Group, List, Empty, or *Paste JSON* from the clipboard)
  - **Add item** in lists; for lists of objects the new item gets the same fields as the previous one
  - per field/item menu: rename, change type, duplicate, move up/down, delete; undo/redo
  - keeps the file's indentation style (spaces, tabs or minified)
- **Edit → Text**: plain-text editor with syntax highlighting, live validation (line and column
  of the error, tap to jump there), a symbol bar for `{ } [ ] " : ,` and Format / Minify
- **Split view**: editor and tree side by side (on a tablet) or stacked (on a phone), updating live;
  scrolling one pane scrolls the other to the same relative position (can be turned off in the menu).
  Tapping a value in the rendered pane selects it in the text
- Save back to the opened file, *Save as…*, *New*, *Open file*, *Paste JSON* (new document from the clipboard)
- Asks before throwing away unsaved changes
- A− / A+ text size, light and dark theme

## How it works

| Part | File |
| --- | --- |
| Intent filters (`application/json`, `*.json`, share sheet) | `android/app/src/main/AndroidManifest.xml` |
| Reading intents, SAF open / save as, writing back | `android/app/src/main/kotlin/com/nicolas/json_viewer/MainActivity.kt` |
| Platform channel `json_viewer/file` (Dart side) | `lib/src/file_bridge.dart` |
| Screen, modes, save / discard logic | `lib/src/viewer_page.dart` |
| Readable (rendered) view | `lib/src/readable_view.dart` |
| Tree view, search | `lib/src/json_tree_view.dart` |
| Form editor and its dialogs | `lib/src/form_editor.dart` |
| Structured edits (add, rename, move, convert, keep indentation) | `lib/src/json_edit.dart` |
| Path → text position (jump from view to editor) | `lib/src/json_locator.dart` |
| Editor, symbol bar, status line | `lib/src/json_editor.dart` |
| Parsing, errors, paths, formatting | `lib/src/json_tools.dart` |
| Syntax highlighting | `lib/src/json_highlighter.dart` |

The app has no third-party Dart packages. File access goes through the Android
Storage Access Framework directly, so a file opened via *Open file* or
*Save as* stays writable.

## Icon

The launcher icon is defined once in `tool/icon/icon.svg`:

- adaptive icon (API 26+, including the themed/monochrome variant):
  `res/drawable/ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`, `res/mipmap-anydpi-v26/ic_launcher.xml`
- PNGs for older Android versions and the Play Store icon (`store/icon-512.png`):
  `node tool/icon/render.js` (needs Playwright)

## Build

```sh
flutter test
flutter build apk --release --split-per-abi
```

GitHub Actions:

- `build.yml`: analyze, tests, split APKs and an App Bundle (`.aab`) as artifacts
- `screenshots.yml`: starts an Android emulator, opens `tool/screenshots/sample.json` via a
  real VIEW intent and uploads screenshots (phone light/dark, editor, search, split view,
  landscape) as the `screenshots` artifact

### Release signing

Without secrets the release build is signed with the debug key. To sign with your
upload key, add these repository secrets (*Settings → Secrets and variables → Actions*):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Locally, create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`,
`keyAlias`, `keyPassword`.
