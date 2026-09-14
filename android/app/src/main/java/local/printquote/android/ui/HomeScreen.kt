package local.printquote.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun HomeScreen(sharedDataStatus: String) {
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    MaterialTheme {
        Scaffold { padding ->
            Column(
                Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text("PrintQuote", style = MaterialTheme.typography.headlineLarge)
                Text("3D Printing Quote & Pricing", style = MaterialTheme.typography.titleLarge)
                Text("Android development environment ready.")
                listOf("New Quote", "Printers", "Filaments", "Settings").forEach { destination ->
                    OutlinedButton(onClick = { selected = destination }, modifier = Modifier.fillMaxWidth()) {
                        Text(destination)
                    }
                }
                Text(sharedDataStatus, style = MaterialTheme.typography.bodySmall)
            }
        }
        selected?.let { destination ->
            AlertDialog(
                onDismissRequest = { selected = null },
                title = { Text(destination) },
                text = { Text("This section is a placeholder for future Android development.") },
                confirmButton = { TextButton(onClick = { selected = null }) { Text("Close") } },
            )
        }
    }
}
