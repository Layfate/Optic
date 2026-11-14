# Optic visual refresh

The user requested a friendly, comfortable, modern, minimalist interface with clearer fonts, then supplied the Optic logo in `C:/Users/corti/Downloads/optic logo/Glossy Purple Optic Analytics Logo.png`.

## Approach
Use a soft dark native Studio interface with lavender accents derived from the supplied logo. This is the builder's choice while the optional theme question remains unanswered. A light alternative would require a separate palette throughout; automatic Studio matching would add theme state beyond this visual pass. Keep the local native architecture and existing actions.

## Design
- Preserve the original logo as an asset and use it in the header and toolbar; no redraw or bitmap alterations. Register the image through Roblox's asset uploader so it renders in Studio.
- Builder Sans Regular/Medium/Bold for UI, Roboto Mono for reports. Body 14–15 px, supporting labels at least 13 px, section headings 18–20 px, metric values 28 px. Use sentence case, strong contrast, shorter copy and explicit unavailable states.
- Charcoal background, quietly separated surfaces, subtle borders, rounded corners, lavender primary action. Use hover/press/focus feedback without continuous animation.
- Compact brand header and a context badge; 38 px actions; quieter segmented navigation with one highlighted active page. Retain all five tabs and all existing callbacks.
- Overview: four metric tiles in one row at comfortable widths, two columns in narrow docks; a calmer chart with scale/reference context; a concise next-step guide. No hard-coded sample values.
- Findings: easier severity badges and source paths, stronger recommendation hierarchy, readable evidence/explanation, functional search/filter/open controls, counts that do not overlap at narrow widths.
- CPU: clear recording status and target control; compact ranked results with real inclusive time and an explanatory note.
- Memory: a readable total/baseline comparison, plain growth context and aligned category rows.
- Reports: readable export controls, copyable monospaced text, unchanged UTF-8 paging and frozen snapshot semantics.
- Default width 800 px, height 740 px; continue to work at 426 px width and the requested 480 × 440 minimum. Long views scroll; no labels may hide behind another element.

## Verification
Use the existing behavioral/build suite, plus native Studio rendering checks at default and narrow widths, checking text bounds, responsive cards, all tabs, logo loading and action flows. Test the redesigned view in the existing scratch place, never the user's game. Rebuild and reinstall the clean plugin after acceptance, remove any temporary bridge, and save a screenshot.
