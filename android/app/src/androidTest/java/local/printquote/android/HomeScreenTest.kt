package local.printquote.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test

class HomeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun loadsSharedDataAndOpensEveryPlaceholder() {
        compose.onNodeWithText("Android development environment ready.").assertIsDisplayed()
        compose.waitUntil(timeoutMillis = 10_000) {
            compose.onAllNodes(hasText("Shared data loaded:", substring = true))
                .fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNode(hasText("Prusa XL 2-tool: 2 toolheads.", substring = true)).assertIsDisplayed()
        listOf("New Quote", "Printers", "Filaments", "Settings").forEach { title ->
            compose.onNodeWithText(title).performClick()
            compose.onNodeWithText("This section is a placeholder for future Android development.")
                .assertIsDisplayed()
            compose.onNodeWithText("Close").performClick()
            compose.onNodeWithText(title).assertIsDisplayed()
            compose.onNodeWithText("This section is a placeholder for future Android development.")
                .assertDoesNotExist()
        }
    }
}
