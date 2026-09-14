package local.printquote.android.data

import local.printquote.android.model.Printer
import org.json.JSONObject

class PrinterRepository(private val readSharedFile: () -> String) {
    fun load(): List<Printer> = parse(readSharedFile())

    companion object {
        const val FILE = "manufacturer_printers_v2.json"

        fun parse(json: String): List<Printer> {
            val root = JSONObject(json)
            require(root.getInt("schemaVersion") == 2) { "Unsupported profile schema" }
            val profiles = root.getJSONArray("profiles")
            return List(profiles.length()) { index ->
                val profile = profiles.getJSONObject(index)
                Printer(
                    manufacturer = profile.getString("vendor"),
                    model = profile.getString("model"),
                    toolheads = profile.getInt("physicalToolheadCount"),
                )
            }
        }
    }
}
