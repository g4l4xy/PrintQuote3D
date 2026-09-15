# PQ Design · Glass

PQGlassMaterial variants: navigation, toolbar, floating, inspector, modal. Native Apple regular glass on supported OS versions, gated without changing deployment targets. Use standard regular/thick material fallback on older versions. Reduce Transparency/high contrast yields solid panel plus border. Android tonal Material surfaces; Windows layered neutral surfaces with an opaque fallback. No live blur of scrolling tables. Never describe Compose paint as native Mica. Model-viewer controls are candidates; do not invent unavailable model actions.
