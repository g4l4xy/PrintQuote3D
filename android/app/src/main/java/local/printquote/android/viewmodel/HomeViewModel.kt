package local.printquote.android.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import local.printquote.android.data.PrinterRepository

class HomeViewModel(repository: PrinterRepository) : ViewModel() {
    private val mutableStatus = MutableStateFlow("Loading shared printer data…")
    val status = mutableStatus.asStateFlow()

    init {
        viewModelScope.launch {
            mutableStatus.value = try {
                val printers = withContext(Dispatchers.IO) { repository.load() }
                val example = printers.first()
                "Shared data loaded: ${printers.size} profiles. ${example.manufacturer} ${example.model}: ${example.toolheads} toolheads."
            } catch (error: Exception) {
                "Shared data could not be loaded: ${error.message}"
            }
        }
    }
}
