package local.printquote.windows

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import local.printquote.android.data.ModelImport
import local.printquote.android.data.ModelReport
import java.util.concurrent.atomic.AtomicBoolean
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter

@Composable fun ModelInspection() {
 val scope=rememberCoroutineScope();val cancelled=remember{AtomicBoolean(false)}
 var report by remember{mutableStateOf<ModelReport?>(null)};var error by remember{mutableStateOf<String?>(null)};var busy by remember{mutableStateOf(false)}
 var search by remember{mutableStateOf("")};var category by remember{mutableStateOf("All")}
 DisposableEffect(Unit){onDispose{cancelled.set(true)}}
 Column(Modifier.fillMaxSize().padding(24.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
  Text("Inspect STL / 3MF",style=MaterialTheme.typography.headlineMedium)
  Text("Review geometry and OrcaSlicer / Bambu Studio metadata. Your quotes stay unchanged.")
  Row {
   Button(enabled=!busy,onClick={
    val chooser=JFileChooser().apply{dialogTitle="Inspect STL / 3MF";fileFilter=FileNameExtensionFilter("STL and 3MF models","stl","3mf")}
    val owner=java.awt.Frame.getFrames().firstOrNull{it.isVisible && it.title=="PrintQuote 3D"}
    if(chooser.showOpenDialog(owner)==JFileChooser.APPROVE_OPTION){
     cancelled.set(false);busy=true;error=null;report=null
     scope.launch{try{val result=withContext(Dispatchers.IO){ModelImport.inspect(chooser.selectedFile){cancelled.get() || !isActive}};if(!cancelled.get())report=result}catch(e:Exception){if(!cancelled.get() && e !is CancellationException)error=e.message ?: "Import failed."}finally{busy=false}}
    }
   }){Text("Choose file")}
   if(busy)TextButton(onClick={cancelled.set(true)}){Text("Cancel")}
  }
  if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
  error?.let{Text(it,color=MaterialTheme.colorScheme.error)}
  report?.let{r->
   Text(r.fileName,style=MaterialTheme.typography.titleMedium)
   var notes by remember{mutableStateOf(false)};TextButton(onClick={notes=!notes}){Text("How to read this report")};if(notes)r.warnings.forEach{Text(it,style=MaterialTheme.typography.bodySmall)}
   OutlinedTextField(search,{search=it},label={Text("Search printer, filament, color, support, tower…")},modifier=Modifier.fillMaxWidth())
   var menu by remember{mutableStateOf(false)};Box{TextButton(onClick={menu=true}){Text("Category: $category")};DropdownMenu(menu,{menu=false}){listOf("All","Geometry","Project settings","Sliced results","Metadata","Package").forEach{c->DropdownMenuItem(text={Text(c)},onClick={category=c;menu=false})}}}
   val rows=remember(r,search,category){r.fields.filter{(category=="All" || it.category==category) && (it.source+" "+it.key+" "+it.value).contains(search,true)}}
   Text("${rows.size} of ${r.fields.size} fields",style=MaterialTheme.typography.bodySmall)
   LazyColumn(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(12.dp)){items(rows){f->SelectionContainer{Column{Text(f.key,style=MaterialTheme.typography.titleSmall);Text(f.value.ifEmpty{"(empty)"});Text("${f.category} · ${f.source}",style=MaterialTheme.typography.bodySmall);HorizontalDivider()}}}}
  }
 }
}
