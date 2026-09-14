Coinly UI/UX review and improvements

The biggest visual gap was consistency and hierarchy. Bright card borders, colored shadows, several gradient treatments, and spaced-out small labels competed with the balances. Inactive navigation labels disappeared, making the six destinations harder to identify.

Cashew's [promotional screens](https://cashewapp.web.app/) and [palette implementation](https://github.com/jameskokoska/Cashew/blob/main/budget/lib/colors.dart) provided the design reference: gently tinted surfaces, recognizable groups, and clear separation between primary information and supporting details. This is an original implementation in Coinly; no Cashew code or assets were imported.

| Area | Implemented improvement |
| --- | --- |
| Shared styling | Flat Material cards, quieter shared shadows, tighter small-text spacing, and tabular figures using the normal app font. Existing accent and theme settings remain available. |
| Home | Added an overview heading; standardized dashboard surfaces and borders; made account section labels easier to scan. |
| Balance | One tonal focal card with a larger balance, explicit calendar affordance, and quieter income/expense groups. Large values scale to fit, and metric groups stack on narrow screens or with large text. |
| Navigation | All six labels remain visible. Added tooltips and selection semantics, retained destination indices, and simplified selection animation. Safe-area padding protects the bottom controls. |
| Transactions | Removed per-row drop shadows, softened borders, and tightened row spacing. Editing, selection, long press, and swipe behavior are retained. |
| Assistant | Clear cloud/on-device status, consistent tonal intro, adaptive action layout, larger suggestion targets, bounded conversation width, and clearer send-button states. Existing prompts, voice input, drafts, and actions remain wired to the same handlers. |
| Budget editing | Replaced the duplicate Edit/Manage controls (which opened the same route) with one labeled Edit budget action next to the month selector. The tooltip explains that it changes the total and category limits. The selected month and refresh-on-return behavior are preserved. |
| Month picker | Theme-aware surfaces and a separate year-navigation row prevent header overflow with large text. |

Performance considerations

This pass adds no dependencies, downloadable fonts, image assets, blur filters, or background work. It preserves the workspace's existing bundled typography. Repeated transaction-row shadows and extra navigation icon transitions were removed. The six assistant actions use a small Wrap instead of a nested shrink-wrapped grid. Existing lazy conversation lists, cached tab screens, TickerMode isolation, and repaint boundaries are preserved. New navigation and balance motion respect the system's reduced-animation setting. These are implementation choices that reduce rendering work; they are not a measured frame-rate claim.

Validation

- All 272 Flutter tests passed, including eight added UI checks.
- App source and the new UI test file passed Flutter analysis with no issues. Full-repository analysis still reports pre-existing warnings/info in scratch.dart and other test imports.
- An Android debug APK built successfully for the initial UI pass. The rebuild including the final budget-control change was stopped after Gradle stalled during a file-copy read; that final APK is not verified.
- Checked 320dp layouts, 1.5× text size, month selection, all navigation callbacks, assistant expense prefill, the composer with a keyboard inset, and the single budget edit action with refresh on return.
- Visually inspected light/dark assistant and overview-component renders plus the budget screen in build/ui-review. These use synthetic data and test-harness platform fonts; the overview render is a component preview rather than a complete HomePage capture.

Existing financial calculations, persistence, providers, service calls, and account settings were not modified. Changes remain in the working tree alongside the user's pre-existing work. Hardware profiling and a complete device walkthrough remain outside this validation.
