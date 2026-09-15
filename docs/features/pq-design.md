# PQ Design migration

Implement the supplied UI/UX brief across Apple, Android and Windows in incremental commits. Source of truth: [PQ Design](../design/PRINTQUOTE_DESIGN_LANGUAGE.md). Preserve pricing/import/storage behavior. Build after each stage; visual and accessibility acceptance must be reported separately.

## Implementation evidence

- `02e1373`: researched design formula, tokens, platform themes and representative previews.
- `58b72d1`: adaptive navigation and dashboard hierarchy.
- `89fb63d`: quote panes, library disclosure, details, local search and inspector protections.
- Build checks passed at each stage. See [verification](../design/verification.md) for automated results and explicit remaining native acceptance.

Pricing/import algorithms and persisted workspace schema remain unchanged. Version 0.5.0 identifies this presentation migration; it does not certify all native accessibility or performance requirements.
