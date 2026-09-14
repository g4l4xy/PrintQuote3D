package local.printquote.android.model

/** Minimal projection of the existing normalized profile, not a new schema. */
data class Printer(val manufacturer: String, val model: String, val toolheads: Int) {
    init { require(toolheads in 1..12) { "Physical toolheads must be between 1 and 12" } }
}
