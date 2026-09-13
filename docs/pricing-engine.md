# Pricing engine and tool systems

The original Decimal pricing fixture remains $33.31 production cost and $55.52 customer price at 40% margin. See README for rounding and pricing order.

Optional `PricingInput.toolJob` enables per-tool costing. When absent, legacy aggregate material costing is unchanged. When present, assignments replace aggregate material grams/prices; each row stores tool, feeder slot (optional), material ID/name/family/color, role, grams, price/kg, active hours and activation/reload count. Prices are quote snapshots.

Shared nozzles use system material-switch seconds and purge grams per reload. Independent nozzles use each tool's activation seconds and purge plus wipe grams. Change duration is added to entered base print hours for machine, average electricity and maintenance costs. Enter base print hours excluding these changes in assignment mode. In aggregate mode enter complete slicer time.

Per-tool active hours drive optional incremental heater energy, maintenance and nozzle replacement-cost/life wear. Abrasive assignments apply that tool's wear multiplier. IDEX, dual-extruder and fixed-multi-nozzle configurations additionally charge explicitly entered parked-heater watts during unused base print hours. Toolchangers do not assume parked heating. All incremental power settings must exclude power already represented by average printer draw.

No architecture adds an arbitrary multiplier. Identical physical assumptions can produce equal costs (for example IDEX and fixed-nozzle with identical parked power and activation settings). Different actual mechanisms are represented by distinct architecture and editable parameters. Simultaneous use is validated against available toolheads; it does not automatically divide wall-clock duration.

New tools have conservative unknown capabilities, zero added costs, and review flags. Compatibility warnings are advisory, not claims of manufacturer certification. Material families are editable identifiers. Manual labor remains aggregate.

Changing the printer in a tool quote updates its tool-system snapshot; incompatible assignments then produce validation errors rather than being silently reassigned. Existing stored quotes are not recalculated during library updates.
