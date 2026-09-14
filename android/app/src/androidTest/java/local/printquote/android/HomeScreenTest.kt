package local.printquote.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test

class HomeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private fun ready() {
        compose.waitUntil(60_000) {
            var done=false
            compose.runOnUiThread {
                val vm=androidx.lifecycle.ViewModelProvider(compose.activity)[local.printquote.android.viewmodel.WorkspaceViewModel::class.java]
                check(vm.error==null) { vm.error!! }
                done=vm.library!=null && !vm.busy
            }
            done
        }
    }
    private fun go(title:String) {
        compose.onNodeWithText("Menu").performClick()
        compose.onAllNodesWithText(title).onLast().performScrollTo().performClick()
    }
    @Test fun createsReopensAndPersistsQuote() {
        ready()
        compose.onNodeWithText("Create estimate").performClick()
        compose.onNodeWithText("Project name").performTextReplacement("Android workflow test")
        compose.onNodeWithText("Customer").performTextReplacement("Emulator customer")
        compose.onNodeWithText("Price breakdown").performClick()
        compose.onAllNodes(hasText("55.52",substring=true)).onFirst().assertExists()
        compose.onAllNodesWithText("Save quote").onFirst().performClick()
        compose.waitUntil(20_000) {compose.onAllNodesWithText("Search quotes, customer or status").fetchSemanticsNodes().isNotEmpty()}
        compose.activityRule.scenario.recreate()
        ready();go("Quotes")
        compose.onNode(hasText("Android workflow test",substring=true)).performClick()
        compose.onNodeWithText("Project name").assertTextContains("Android workflow test")
        compose.onNodeWithText("Customer").assertTextContains("Emulator customer")
    }
    @Test fun searchesCompleteLibrariesAndEditsSettings() {
        ready();go("Printers")
        compose.onNodeWithText("1007 of 1007").assertExists()
        compose.onNodeWithText("Search manufacturer, model or nozzle").performTextInput("Prusa XL")
        compose.onAllNodes(hasText("Prusa XL",substring=true) and hasClickAction() and !hasSetTextAction()).onFirst().assertExists()
        go("Materials");compose.onNodeWithText("Browse catalog").performClick()
        compose.onNodeWithText("2089 catalog products").assertExists()
        compose.onNodeWithText("Search brand, product or material family").performTextInput("Bambu")
        compose.onAllNodes(hasText("Bambu",substring=true) and hasClickAction() and !hasSetTextAction()).onFirst().performClick()
        compose.waitUntil(30_000) {compose.onAllNodesWithText("Catalog material").fetchSemanticsNodes().isNotEmpty()}
        compose.onNodeWithText("Your price per kg").performTextInput("24.75")
        compose.onNodeWithText("Save to My materials").performScrollTo().performClick()
        compose.waitUntil(20_000) {compose.onAllNodesWithText("Edit material").fetchSemanticsNodes().isNotEmpty()}
        compose.onNodeWithText("Back").performClick()
        compose.onNodeWithText("Discard").performClick()
        go("Settings")
        compose.onNodeWithText("Business Name").performTextReplacement("Android workshop")
        compose.onNodeWithText("Save").performClick()
        compose.waitUntil(20_000) {compose.onAllNodesWithText("Create estimate").fetchSemanticsNodes().isNotEmpty()}
        compose.onNodeWithText("Android workshop").assertExists()
    }
}
