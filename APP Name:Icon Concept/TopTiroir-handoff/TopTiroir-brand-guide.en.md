# TopTiroir Brand & Concept Guide

[English](TopTiroir-brand-guide.en.md) · [한국어](TopTiroir-브랜드-가이드.md)

Finalized: 2026-11-23 · For: a macOS app that makes use of the notch and menu bar (personal use)

## 1. Name
| Item | Details |
|---|---|
| App name | **TopTiroir** |
| Pronunciation | "top tee-RWAHR" |
| Origin | Top (English, the very top) + tiroir (French, "drawer") |
| Meaning | A drawer attached to the top of the screen (notch and menu bar). Doubles with the English idiom "top drawer" (first-rate) |
| Code / folder name | `toptiroir` (bundle ID example: `com.<yourname>.toptiroir`) |
| Spelling rule | Only the first T and the second T are capitals: TopTiroir (not Toptiroir or Top Tiroir) |
| Note | When said aloud the spelling is hard to guess, so spell it out. Trademark and App Store name conflicts **must be checked separately** |

## 2. App concept (planning summary)
- **Problem**: the MacBook notch stands out, and it leaves too little room for menu bar icons.
- **Must have**: hide the notch by painting both sides black (with wider resolution support), launch at login.
- **Should have**: click the notch and a notes/to-do window drops down like a drawer / an extra menu bar row under the notch (two rows) with configurable icon positions.
- **Nice to have**: favorites for apps, folders, files, and URLs, grouped in folders (like bookmark folders).
- **Out of scope**: features that use screen space outside the menu bar area.
- Note: macOS doesn't let apps move the real menu bar. A two-row menu bar would most likely mean the app draws its own bar under the notch, and it's the hardest feature. (It was built in v0.10–0.11 and later removed from 1.0.)

### Proposed sub-feature names (not final, all on the drawer theme)
| Feature | Proposed name | Meaning |
|---|---|---|
| Notch hiding | Blackout | Black around the notch |
| Notch notes/to-do window | Note Drawer | Notes kept in a drawer |
| Two-row menu bar | Second Shelf | The second shelf of a chest of drawers |
| Favorites groups | Compartments | Dividers inside a drawer |

## 3. App icon — "the open drawer"
- Black top band = the menu bar with the notch hidden, an orange drawer front, a **black handle shaped like the notch**, and a white note inside the drawer (the notes feature).
- 64 px and up use `app-icon.svg`; **32 px and below use `app-icon-small.svg`** (note lines and inner shadow removed, drawer and handle enlarged).
- The macOS shape (rounded square, 824×824 inside a 1024 canvas, corner radius 185) is already included.

## 4. Menu bar icon — "notch silhouette"
- A horizontal line whose middle bulges downward. A **template image** (uses only black + transparency; macOS turns it white automatically in dark mode).
- Size: 18×18 pt. Files `MenuBarIconTemplate.png` (18 px), `@2x` (36 px), `@3x` (54 px), and the source SVG.
- In Xcode: create an image set in Assets, add the files, and set **Render As → Template Image** in the inspector. In code: `image.isTemplate = true`.
- macOS treats an image whose file name ends with `Template` as a template image.

## 5. Colors
| Use | Color |
|---|---|
| Notch, top band, handle black | `#0B0C10` |
| Drawer orange (top → bottom gradient) | `#F7B23B` → `#E08E12` (solid: `#F5A623`) |
| Background navy (top → bottom) | `#232A3D` → `#34405F` |
| Drawer interior | `#11141C` |
| Note / note lines | `#FFFFFF` / `#B9C2D6` |

## 6. Files
```
TopTiroir-handoff/
├─ TopTiroir-브랜드-가이드.md     ← this guide (Korean original)
├─ TopTiroir-brand-guide.en.md   ← this guide (English)
├─ app-icon/
│  ├─ app-icon.svg              ← source (64 px and up)
│  ├─ app-icon-small.svg        ← source (32 px and below)
│  ├─ app-icon-16~1024.png      ← PNGs by size
│  ├─ AppIcon.icns              ← macOS app icon
│  └─ AppIcon.iconset/          ← size set for Xcode / iconutil
└─ menubar/
   ├─ MenuBarIconTemplate.svg
   └─ MenuBarIconTemplate.png / @2x / @3x
```
- To rebuild the `.icns` on a Mac (Mac Terminal, in the app-icon folder):
  ```
  iconutil -c icns AppIcon.iconset
  ```
- Not yet made: a logo (lettering for the name). Can be done separately if needed.
