# PQ Design · Platform Adaptation

| Concept | Apple | Android | Windows |
|---|---|---|---|
| Navigation | NavigationSplitView, compact native destinations | Material bar/rail/drawer by window width | Labeled sidebar, compact collapse |
| Tool layer | Native Liquid Glass where available | Tonal Material surface | Fluent-inspired layered neutral surface |
| Data | Opaque grouped form/list/table | Opaque Material surface | Dense opaque rows/table |
| Typography | System semantic fonts | Material type/fontScale | Segoe UI/system fallback |
| Icons | SF Symbols | Material icons | System/semantic desktop glyphs |
| Primary action | Native bordered/prominent button | Filled Material button | Compact desktop button |
| Details | Secondary pane/sheet | Adaptive pane/full-screen detail | Right pane/dialog |
| Context | Native context menu | Overflow/long-press | Right-click context menu |
| Focus | Native focus indication | Material focus/state layers | Keyboard-visible focus and hover |
| Motion | Native, environment Reduce Motion | Native animation scale | Reduced-effects setting/system fallback |
| Glass reduction | Environment Reduce Transparency/contrast | Opaque tonal surfaces | Opaque tonal surfaces |
| Theme | System/Light/Dark | System/Light/Dark | System/Light/Dark |
| Touch | 44pt targets | 48dp targets | Pointer density; accessible labels |

Shared semantic roles do not require identical native widgets. Preserve mouse/keyboard efficiency on desktop and touch affordances on mobile. Native Mica is not currently supplied by the Compose Desktop host; the neutral layered treatment is explicit and intentional.
