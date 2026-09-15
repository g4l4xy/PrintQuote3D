package local.printquote.android.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Semantic adapter for SharedSchemas/pq-design-tokens.json.
object PQSpacing { val xs=4.dp; val sm=8.dp; val md=12.dp; val lg=16.dp; val xl=20.dp; val section=24.dp; val page=32.dp }
object PQRadius { val control=6.dp; val panel=12.dp; val floating=20.dp }
object PQMotion { const val fast=120; const val standard=180; const val pane=240 }
object PQIconSize { val navigation=24.dp; val identity=40.dp }
object PQControlSize { val desktop=32.dp; val touch=48.dp }
object PQBorder { val normal=1.dp; val emphasized=2.dp }
object PQElevation { val tools=3.dp; val modal=8.dp }
object PQLayout { val medium=600.dp; val expanded=840.dp; val wide=1200.dp }
enum class PQGlassMaterial { Navigation, Toolbar, Floating, Inspector, Modal }
fun pqColors(dark:Boolean,contrast:Boolean=false):ColorScheme {
 val base=if(dark)darkColorScheme(primary=Color(0xFF8BB5FF),onPrimary=Color(0xFF102A53),primaryContainer=Color(0xFF243F69),onPrimaryContainer=Color(0xFFE4EDFF),secondary=Color(0xFFAFBED0),onSecondary=Color(0xFF182230),background=Color(0xFF151A21),onBackground=Color(0xFFF2F5FA),surface=Color(0xFF1E2631),onSurface=Color(0xFFF2F5FA),surfaceVariant=Color(0xFF293545),onSurfaceVariant=Color(0xFFAFBED0),surfaceContainer=Color(0xFF1E2631),surfaceContainerHigh=Color(0xFF293545),surfaceContainerLow=Color(0xFF151A21),outline=Color(0xFF8494A9),outlineVariant=Color(0xFF45556B),error=Color(0xFFFFB4AB))
 else lightColorScheme(primary=Color(0xFF205BCD),onPrimary=Color.White,primaryContainer=Color(0xFFDCE7FF),onPrimaryContainer=Color(0xFF153C7F),secondary=Color(0xFF536175),onSecondary=Color.White,background=Color(0xFFF4F6F9),onBackground=Color(0xFF182230),surface=Color.White,onSurface=Color(0xFF182230),surfaceVariant=Color(0xFFE8EDF4),onSurfaceVariant=Color(0xFF536175),surfaceContainer=Color.White,surfaceContainerHigh=Color(0xFFE8EDF4),surfaceContainerLow=Color(0xFFF4F6F9),outline=Color(0xFF66758A),outlineVariant=Color(0xFFB8C3D2),error=Color(0xFFB3261E))
 return if(contrast)base.copy(onSurface=if(dark)Color.White else Color.Black,onBackground=if(dark)Color.White else Color.Black,onSurfaceVariant=if(dark)Color.White else Color.Black,outline=if(dark)Color.White else Color.Black)else base
}
val PQTypography=Typography().let{it.copy(headlineLarge=it.headlineLarge.copy(fontWeight=FontWeight.SemiBold),headlineMedium=it.headlineMedium.copy(fontWeight=FontWeight.SemiBold),titleLarge=it.titleLarge.copy(fontWeight=FontWeight.SemiBold))}
val PQShapes=Shapes(extraSmall=RoundedCornerShape(PQRadius.control),small=RoundedCornerShape(PQRadius.control),medium=RoundedCornerShape(PQRadius.panel),large=RoundedCornerShape(PQRadius.panel),extraLarge=RoundedCornerShape(PQRadius.floating))
@Composable fun PQGlassSurface(modifier:Modifier=Modifier,role:PQGlassMaterial=PQGlassMaterial.Toolbar,content:@Composable ()->Unit) {
 // Tonal hierarchy is deliberate: no expensive backdrop blur over data rows.
 Surface(modifier,shape=RoundedCornerShape(if(role==PQGlassMaterial.Toolbar)PQRadius.panel else PQRadius.floating),color=MaterialTheme.colorScheme.surfaceContainerHigh,tonalElevation=PQElevation.tools,content=content)
}
@Composable fun PQSectionHeader(title:String,subtitle:String="") {
 Column(Modifier.fillMaxWidth(),verticalArrangement=Arrangement.spacedBy(PQSpacing.xs)){Text(title,style=MaterialTheme.typography.titleLarge);if(subtitle.isNotEmpty())Text(subtitle,style=MaterialTheme.typography.bodyMedium,color=MaterialTheme.colorScheme.onSurfaceVariant)}
}
@Composable fun PQMetric(label:String,value:String,modifier:Modifier=Modifier){Surface(modifier,shape=RoundedCornerShape(PQRadius.panel),color=MaterialTheme.colorScheme.surface){Column(Modifier.padding(PQSpacing.lg),verticalArrangement=Arrangement.spacedBy(PQSpacing.sm)){Text(label,style=MaterialTheme.typography.labelLarge,color=MaterialTheme.colorScheme.onSurfaceVariant);Text(value,style=MaterialTheme.typography.headlineMedium.copy(fontFeatureSettings="tnum"))}}}
@Composable fun PQAppearanceControls(){
 PQSectionHeader("Appearance","Choose the theme and clarity that suit your workspace.")
 FlowRow(horizontalArrangement=Arrangement.spacedBy(PQSpacing.sm)){listOf("System","Light","Dark").forEach{value->FilterChip(PQAppearance.mode==value,onClick={PQAppearance.updateMode(value)},label={Text(value)})}}
 Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Text("Increase contrast",Modifier.weight(1f));Switch(PQAppearance.highContrast,{PQAppearance.setContrast(it)})}
 Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Text("Reduce visual effects",Modifier.weight(1f));Switch(PQAppearance.reduced,{PQAppearance.updateReduced(it)})}
 Text("Data panels stay opaque. These settings do not hide controls or information.",style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
}

object PQAppearance {
 private var store:android.content.SharedPreferences?=null
 var mode by mutableStateOf("System");private set
 var highContrast by mutableStateOf(false);private set
 var reduced by mutableStateOf(false);private set
 fun load(context:android.content.Context){if(store==null){store=context.getSharedPreferences("pq.design",0);mode=store!!.getString("theme","System") ?: "System";highContrast=store!!.getBoolean("contrast",false);reduced=store!!.getBoolean("reduced",false)}}
 fun updateMode(value:String){mode=value;store?.edit()?.putString("theme",value)?.apply()}
 fun setContrast(value:Boolean){highContrast=value;store?.edit()?.putBoolean("contrast",value)?.apply()}
 fun updateReduced(value:Boolean){reduced=value;store?.edit()?.putBoolean("reduced",value)?.apply()}
}
@Composable fun PQTheme(content:@Composable ()->Unit){
 val context=androidx.compose.ui.platform.LocalContext.current
 remember(context){PQAppearance.load(context);true}
 val dark=when(PQAppearance.mode){"Dark"->true;"Light"->false;else->isSystemInDarkTheme()}
 MaterialTheme(colorScheme=pqColors(dark,PQAppearance.highContrast),typography=PQTypography,shapes=PQShapes,content=content)
}
