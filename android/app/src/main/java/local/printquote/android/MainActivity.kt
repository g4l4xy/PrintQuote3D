package local.printquote.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import local.printquote.android.data.PrinterRepository
import local.printquote.android.ui.HomeScreen
import local.printquote.android.viewmodel.HomeViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val appAssets = applicationContext.assets
        setContent {
            val home = viewModel { HomeViewModel(PrinterRepository {
                appAssets.open(PrinterRepository.FILE).bufferedReader().use { it.readText() }
            }) }
            HomeScreen(home.status.collectAsStateWithLifecycle().value)
        }
    }
}
