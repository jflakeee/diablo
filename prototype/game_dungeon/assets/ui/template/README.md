# Temporary UI template assets

These images are unmodified selections from two Kenney CC0 packages. They are
used behind stable resource IDs while the project-owned local UI generator is
developed.

| Runtime file | Source package | Archive entry |
|---|---|---|
| `button_primary.png` | UI Pack: RPG Expansion | `PNG/buttonLong_brown.png` |
| `button_primary_pressed.png` | UI Pack: RPG Expansion | `PNG/buttonLong_brown_pressed.png` |
| `button_secondary.png` | UI Pack: RPG Expansion | `PNG/buttonLong_grey.png` |
| `button_secondary_pressed.png` | UI Pack: RPG Expansion | `PNG/buttonLong_grey_pressed.png` |
| `panel_brown.png` | UI Pack: RPG Expansion | `PNG/panel_brown.png` |
| `panel_border_double.png` | Fantasy UI Borders | `PNG/Double/Transparent center/panel-transparent-center-000.png` |

Source records, original archives, hashes, and licenses live in
`third_party_sources/`. Do not reference Kenney filenames from gameplay code;
use `ui/template_theme.gd` so the assets can be replaced without UI code changes.
