package local.printquote.android.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import android.provider.OpenableColumns
import kotlinx.coroutines.*
import local.printquote.android.data.ModelImport
import local.printquote.android.data.ModelReport
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

@Composable fun ModelInspectionScreen() {
 val context=LocalContext.current;val scope=rememberCoroutineScope()
 var report by remember {mutableStateOf<ModelReport?>(null)};var error by remember {mutableStateOf<String?>(null)}
 var busy by remember {mutableStateOf(false)};var search by remember {mutableStateOf("")};var category by remember {mutableStateOf("All")}
 val cancelled=remember {AtomicBoolean(false)}
 DisposableEffect(Unit){onDispose{cancelled.set(true)}}
 val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null){
  cancelled.set(false);busy=true;error=null;report=null
  scope.launch {
   try {
    val result=withContext(Dispatchers.IO){
     var name="model.3mf"
     context.contentResolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME),null,null,null)?.use{if(it.moveToFirst()) name=it.getString(0)}
     val tmp=File.createTempFile("model-inspection-",".tmp",context.cacheDir)
     try {
      context.contentResolver.openInputStream(uri)?.use{input->tmp.outputStream().use{out->val buf=ByteArray(65536);var total=0L;while(true){ensureActive();if(cancelled.get())throw CancellationException();val n=input.read(buf);if(n<0)break;total+=n;require(total<=ModelImport.MAX_SOURCE){"File exceeds 512 MiB."};out.write(buf,0,n)}}} ?: error("Cannot read the selected file.")
      ModelImport.inspect(tmp,name){cancelled.get() || !isActive}
     } finally {tmp.delete()}
    }
    if(!cancelled.get())report=result
   } catch(e:Exception){if(!cancelled.get() && e !is CancellationException)error=e.message ?: "Import failed."} finally{busy=false}
  }
 }}
 Column(Modifier.fillMaxSize().padding(20.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
  Text("Inspect STL / 3MF",style=MaterialTheme.typography.headlineSmall)
  Text("Review geometry and OrcaSlicer / Bambu Studio metadata. Your quotes stay unchanged.")
  Row {Button(enabled=!busy,onClick={picker.launch(arrayOf("*/*"))}){Text("Choose file")};if(busy){TextButton(onClick={cancelled.set(true)}){Text("Cancel")}}}
  if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
  error?.let{Text(it,color=MaterialTheme.colorScheme.error)}
  report?.let{r->
   Text(r.fileName,style=MaterialTheme.typography.titleMedium)
   var notes by remember {mutableStateOf(false)}
   TextButton(onClick={notes=!notes}){Text("How to read this report")};if(notes)r.warnings.forEach{Text(it,style=MaterialTheme.typography.bodySmall)}
   OutlinedTextField(search,{search=it},label={Text("Search printer, filament, support, tower…")},modifier=Modifier.fillMaxWidth())
   var menu by remember {mutableStateOf(false)}
   Box{TextButton(onClick={menu=true}){Text("Category: $category")};DropdownMenu(menu,{menu=false}){listOf("All","Geometry","Project settings","Sliced results","Metadata","Package").forEach{c->DropdownMenuItem(text={Text(c)},onClick={category=c;menu=false})}}}
   val rows=remember(r,search,category){r.fields.filter{(category=="All" || it.category==category) && (it.source+" "+it.key+" "+it.value).contains(search,true)}}
   Text("${rows.size} of ${r.fields.size} fields",style=MaterialTheme.typography.bodySmall)
   LazyColumn(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(12.dp)){items(rows){f->SelectionContainer{Column{Text(f.key,style=MaterialTheme.typography.titleSmall);Text(f.value.ifEmpty{"(empty)"});Text("${f.category} · ${f.source}",style=MaterialTheme.typography.bodySmall);HorizontalDivider()}}}}
  }
 }
}
