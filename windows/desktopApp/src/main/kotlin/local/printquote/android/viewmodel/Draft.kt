package local.printquote.android.viewmodel
import androidx.compose.runtime.*
import org.json.JSONObject
class Draft(val json:JSONObject) {
 var revision by mutableIntStateOf(0)
 fun change(action:()->Unit) { action(); revision++ }
}
