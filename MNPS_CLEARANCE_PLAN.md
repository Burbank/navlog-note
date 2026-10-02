# QUICKLOG — MNPS clearance field and title toasts

Export this file to:

`/Users/DuniaMBP/Library/Mobile Documents/com~apple~CloudDocs/CURSOR_PROJECT_REPOS/Quicklog`

Status: agreed plan. Not built yet. First implementation is the PWA on localhost / Home Screen only — no GitHub Pages publish and no version bump until approved.

Repo: GitHub `Burbank/navlog-note`  
Source of truth for the live PWA: `origin/main` → `index.html`  
Do **not** use branch `cursor/public-support-pages-8857` (that PR replaces the PWA with a landing page).  
Planned work branch: `cursor/mnps-clnc-8857`  
Native SwiftUI iPad app: out of this first pass.

---

## What the chief pilot asked for

Pilots need a place to add the **MNPS clearance number**. They do not have to type the full clearance, but they may.

The departure OFP text and the MNPS text are **separated**:

- Departure copy stays RVSM / clearance / fuel.
- MNPS checks + clearance number get their own copy button.

Toast messages that used the spare space in column 3 must move onto the **QUICKLOG** title, because that spare space is going away.

Screenshot map:

- **A** — right-hand column under RVSM (main layout work)
- **B** — QUICKLOG title (toast overlay)

---

## Layout (column 3, area A)

```
[ Before RVSM entry — L / R / SBY only ]
[ COPY DEPT TEXT ]
[ MNPS RTE CHECKS  N/A | PERFORMED ]
[ MNPS CLNC  (dynamic placeholder) ]
[ COPY MNPS TEXT ]
```

- Move the existing MNPS RTE CHECKS toggle out of the RVSM card into a new MNPS block below COPY DEPT TEXT.
- COPY DEPT TEXT sits immediately under the altimeter RVSM fields.
- COPY ARR TEXT stays in row 3 (unchanged).
- Drop the extra `min-height: 3.35rem` padding on `.card-copy-dept`. That gap only existed because DEPT sat in empty space above ARR.

---

## MNPS CLNC field

- Control: `#mnpsClnc`
- Label: **MNPS CLNC**
- Use a `<textarea>` (not a one-line input). No short maxlength, so a number or a full clearance both fit.

### Toggle and placeholder

| MNPS RTE CHECKS | Meaning | Field | Placeholder | COPY MNPS TEXT |
|---|---|---|---|---|
| **N/A** | Not an Atlantic crossing | Disabled / not applicable | `N/A` | Muted. Tap → toast `MNPS not applicable`. No clipboard, no FLIGHT. |
| **PERFORMED** | Oceanic crossing | Enabled | `CLNC number, ref OM-A 8.3.2.6(c)(2)` | Live. Copies MNPS text and opens FLIGHT. |

- Typed text is kept if the pilot toggles back to N/A, so it reappears on PERFORMED.
- Persist `#mnpsClnc` in `FIELD_IDS` / `localStorage` key `flight-plan-form-v3`.
- CLEAR empties the field.
- Existing AMS ↔ MIA `syncMnpsForRoute()` still flips the toggle; placeholder and disabled state follow.

### Grow while typing

A one-line box would hide a long sentence behind the caret. The field grows so the pilot can read the whole clearance while typing (notes/chat pattern — no popup editor).

- At rest (blur, or only a short number): one row, same height as L / R / SBY.
- While focused / as they type: wrap to the column width and grow height to fit (`scrollHeight`).
- Cap at about **4 lines** (~5.5rem). Longer text scrolls inside the field so COPY ARR and the log table are not pushed off the iPad landscape shell (`body` is `overflow: hidden`).
- COPY MNPS TEXT stays immediately under the field and moves down as it grows.
- On blur: if the text is longer than one line, keep **2 visible lines** so column 3 stays compact. Focus again to expand and edit.
- Recalc height on input, on PERFORMED / N/A, after load / CLEAR, and after orientation changes.
- Enter in this field inserts a newline. Tab still advances to the next departure-topic field.

---

## Copy behavior

Today COPY DEPT appends this when the toggle is PERFORMED:

```
MNPS RTE CHECKS.   PERFORMED.
```

That line **leaves** departure text.

### COPY DEPT TEXT

- Ends at the RVSM line (`Before RVSM entry L: … R: … SBY: …`).
- Incomplete-dept checks stay RVSM-only. MNPS CLNC is not required for DEPT.

### COPY MNPS TEXT (`#btnCopyMnps`)

Same pattern as DEPT / ARR:

1. Undo snapshot
2. Write clipboard
3. Flash `Copied!`
4. Open FLIGHT via `aviobook.ng.efb://`

Proposed clipboard when PERFORMED:

```
MNPS RTE CHECKS.   PERFORMED.

MNPS CLNC: <whatever was typed>
```

If the number / clearance is left blank, only the PERFORMED line is copied.

---

## Toasts on the QUICKLOG title (area B)

Today `#toast` is a bottom-center pill (`position: fixed; bottom: 20px`). That space is gone once column 3 is filled.

- Put the toast inside `.card-quicklog-title` as a short overlay.
- Title card: `position: relative`.
- Toast: absolutely covering that card, ~1.6s, then fade.
- Keep `showToast()` so Cleared / Copied / incomplete / update messages all use the title.
- Keep `aria-live`.
- Stay below the install overlay (`z-index: 90`).

---

## Where the first build runs

This Cloud Agent **cannot** write into the Mac iCloud folder:

`/Users/DuniaMBP/Library/Mobile Documents/com~apple~CloudDocs/CURSOR_PROJECT_REPOS/Quicklog`

That path is on the Mac. The cloud VM only has `/workspace` (the GitHub checkout). No self-hosted worker is connected.

Ways to run locally in that folder:

1. Open the Quicklog folder in Cursor on the Mac and continue there (or start `cursor worker start` on the Mac).
2. Build in the cloud workspace, then pull branch `cursor/mnps-clnc-8857` into the iCloud checkout.
3. Treat the iCloud folder as a checkout of `Burbank/navlog-note`, not a second source of truth.

First test: localhost, then Add to Home Screen on the iPad.  
Do **not** merge to `main` / Pages.  
Do **not** bump `APP_VERSION`, `APP_BUILD`, or the `sw.js` cache name until approved.

---

## Build checklist

- [ ] Create `cursor/mnps-clnc-8857` from `origin/main`
- [ ] Split MNPS out of the RVSM card; move COPY DEPT TEXT under L / R / SBY
- [ ] Add MNPS CLNC textarea + COPY MNPS TEXT
- [ ] Dynamic placeholder and disable/mute when N/A
- [ ] Auto-grow while typing (wrap, 4-line cap, 2-line collapse on blur)
- [ ] Remove MNPS from `buildOutput()`; add `buildMnpsOutput` + `copyMnps` + FLIGHT URL
- [ ] Persist `mnpsClnc`, reset on CLEAR, Tab into the field when PERFORMED
- [ ] Reposition `#toast` over `.card-quicklog-title`
- [ ] Localhost / Home Screen preview only

---

## Verify before calling it done

- N/A: placeholder `N/A`, field locked, COPY MNPS muted.
- PERFORMED: new placeholder, type a number, COPY MNPS pastes the two-line block and opens FLIGHT.
- Longer free-text clearance also copies; while typing, the field grows so the whole sentence is visible (cap ~4 lines, then inner scroll).
- COPY DEPT no longer includes MNPS.
- Toasts appear on **QUICKLOG**, not at the footer.
- Landscape iPad: column 3 still fits without colliding with COPY ARR or the log table. Also check bright theme and a narrower width.
