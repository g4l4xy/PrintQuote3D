package local.printquote.android.data

import org.json.JSONArray
import org.json.JSONObject
import org.xml.sax.Attributes
import org.xml.sax.helpers.DefaultHandler
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.ZipFile
import javax.xml.parsers.SAXParserFactory

/** Read-only inspection. Never treats configuration flags as consumed material. */
data class ModelField(val category:String,val source:String,val key:String,val value:String)
data class ModelReport(val fileName:String,val format:String,val fields:List<ModelField>,val warnings:List<String>)
object ModelImport {
 const val MAX_SOURCE = 512L*1024*1024
 private const val MAX_ENTRY = 128L*1024*1024
 fun inspect(file:File, name:String=file.name, cancelled:()->Boolean={false}):ModelReport {
  val started=System.nanoTime()
  require(file.length() in 1..MAX_SOURCE) {"File is empty or exceeds 512 MiB."}
  val fields=mutableListOf<ModelField>(); val warnings=mutableListOf<String>()
  fun check() {
   if(cancelled() || Thread.currentThread().isInterrupted) throw java.util.concurrent.CancellationException("Import cancelled")
   require(System.nanoTime()-started<120_000_000_000L){"Import exceeded the two-minute processing budget."}
  }
  check()
  var reportBytes=0L
  fun add(category:String,source:String,key:String,value:String) {
   check(); val valueBytes=value.toByteArray(Charsets.UTF_8).size;val keyBytes=key.toByteArray(Charsets.UTF_8).size
   require(fields.size<30000 && valueBytes<=65536 && keyBytes<=65536){"Metadata exceeds inspection limits."}
   reportBytes+=valueBytes+keyBytes+source.toByteArray(Charsets.UTF_8).size+category.length
   require(reportBytes<=16L*1024*1024){"Expanded report exceeds the 16 MiB text budget."}
   fields+=ModelField(category,source,key,value)
  }
  when(name.substringAfterLast('.').lowercase()) {
   "stl" -> {
    // Bound the in-memory STL reader independently from archive limits.
    require(file.length()<=MAX_ENTRY){"STL exceeds the 128 MiB inspection limit."}
    val buffer=java.io.ByteArrayOutputStream()
    file.inputStream().use{input->val chunk=ByteArray(65536);while(true){check();val n=input.read(chunk);if(n<0)break;require(buffer.size().toLong()+n<=MAX_ENTRY){"STL exceeds the 128 MiB inspection limit."};buffer.write(chunk,0,n)}}
    val data=buffer.toByteArray(); val bounds=Bounds(); var triangles=0; var attributes=0
    val binaryCount=if(data.size>=84) ByteBuffer.wrap(data,80,4).order(ByteOrder.LITTLE_ENDIAN).int.toLong() and 0xffffffffL else -1
    if(binaryCount>=0 && 84+50*binaryCount==data.size.toLong()) {
     val b=ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN);b.position(84)
     repeat(binaryCount.toInt()) {
      check();repeat(3){require(b.float.isFinite()){ "Invalid STL normal." }}
      repeat(3){bounds.vertex(doubleArrayOf(b.float.toDouble(),b.float.toDouble(),b.float.toDouble()))}
      if(b.short.toInt()!=0)attributes++;triangles++
     }
     add("Geometry",name,"encoding","Binary STL")
     add("Metadata",name,"header",String(data.copyOfRange(0,80),Charsets.ISO_8859_1).trimEnd('\u0000'))
     add("Metadata",name,"facets with attribute bytes",attributes.toString())
    } else {
     var stage=0;var vertex=0;var solid=false;var ended=false
     Charsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(data)).toString().removePrefix("\uFEFF").lineSequence().forEach {line->
      check();val t=line.trim().split(Regex("\\s+")); if(t.first().isEmpty()) return@forEach
      when(t[0]) {
       "solid"->{require(stage==0 && !solid){"Malformed ASCII STL."};solid=true;ended=false}
       "facet"->{require(solid && stage==0 && t.size==5 && t[1]=="normal"){"Malformed STL facet."};t.drop(2).forEach {require(it.toDoubleOrNull()?.isFinite()==true)};stage=1}
       "outer"->{require(stage==1 && t==listOf("outer","loop"));stage=2;vertex=0}
       "vertex"->{require(stage==2 && vertex<3 && t.size==4);bounds.vertex(t.drop(1).map{it.toDouble()}.toDoubleArray());vertex++}
       "endloop"->{require(stage==2 && vertex==3 && t.size==1);stage=3}
       "endfacet"->{require(stage==3 && t.size==1);stage=0;triangles++}
       "endsolid"->{require(solid && stage==0);solid=false;ended=true}
       else->error("Unrecognized or truncated STL data.")
      }
     }
     require(ended && !solid && stage==0){"Truncated ASCII STL."}
     add("Geometry",name,"encoding","ASCII STL")
    }
    require(triangles>0){"STL contains no triangles."}
    add("Geometry",name,"triangles",triangles.toString());add("Geometry",name,"bounds",bounds.description())
    warnings+="STL has no standard unit, printer, toolhead or filament settings. Bounds use file coordinates. No material usage, supports or prime-tower estimate is inferred."
    warnings+="STL attribute bytes and header are retained for inspection; vendor color conventions are not decoded. Topology and printable volume are not validated."
   }
   "3mf" -> ZipFile(file).use {zip->
    val entries=mutableListOf<java.util.zip.ZipEntry>();val enumeration=zip.entries()
    while(enumeration.hasMoreElements()){check();require(entries.size<4096){"Too many archive entries."};entries+=enumeration.nextElement()}
    var total=0L;val names=mutableSetOf<String>()
    entries.forEach {e->
     check();require(e.name.toByteArray(Charsets.UTF_8).size<=4096 && e.name.none{it.code<32 || it.code==127} && !e.name.contains("//") && !e.name.startsWith('/') && !e.name.contains('\\') && !e.name.contains(':') && e.name.split('/').none{it==".." || it=="."} && names.add(e.name)){"Unsafe or duplicate archive path."}
     require(e.size in 0..MAX_ENTRY){"Archive entry exceeds 128 MiB."};total+=e.size;require(total<=MAX_SOURCE){"Expanded archive exceeds 512 MiB."}
    }
    require(entries.any{it.name.endsWith(".model",true)} || entries.any{it.name.endsWith(".gcode",true)}){"No model or sliced G-code in this 3MF."}
    entries.filter{!it.isDirectory}.forEach {e->
     add("Package",e.name,"uncompressed bytes",e.size.toString())
     val ext=e.name.substringAfterLast('.').lowercase()
     val textual=ext in listOf("model","xml","rels","config","json","gcode")
     val limit=if(textual && ext !in listOf("model","gcode"))16L*1024*1024 else MAX_ENTRY
     require(e.size<=limit){"${e.name}: metadata exceeds the 16 MiB entry budget."}
     try {
      var expanded=0L
      val out=java.io.ByteArrayOutputStream();val crc=java.util.zip.CRC32()
      zip.getInputStream(e).use {input->val buf=ByteArray(65536);while(true){check();val n=input.read(buf);if(n<0)break;expanded+=n;require(expanded<=limit && expanded<=e.size){"Expanded entry exceeds declared size."};if(textual)out.write(buf,0,n);crc.update(buf,0,n)}}
      require(expanded==e.size && crc.value==e.crc){"Archive entry is damaged."}
      if(!textual)return@forEach
      val data=out.toByteArray();val text=Charsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(data)).toString().removePrefix("\uFEFF");require(!text.contains('\u0000')){"Metadata must use UTF-8 text."}
      require(ext!="model" || text.trimStart().startsWith('<')){"3MF model must contain XML."}
      val category=if(e.name.endsWith("slice_info.config") || ext=="gcode")"Sliced results" else if(e.name.endsWith("project_settings.config"))"Project settings" else "Metadata"
      if(ext=="gcode") {
       var last="";text.lineSequence().forEachIndexed {i,line->check();val s=line.trim();if(s.startsWith(';')) {val body=s.removePrefix(";").trim();if((body.contains('=') || body.contains(':')) && body!=last){add(category,e.name,"line ${i+1}",body);last=body}}}
      } else if(text.trimStart().startsWith('{') || text.trimStart().startsWith('[')) {
       var depth=0;var quoted=false;var escaped=false
       text.forEachIndexed{index,c->if(index%4096==0)check();if(escaped)escaped=false else if(quoted && c=='\\')escaped=true else if(c=='"')quoted=!quoted else if(!quoted){if(c=='{' || c=='['){depth++;require(depth<=64){"JSON nesting limit exceeded."}};if(c=='}' || c==']')depth--}}
       fun walk(value:Any?,path:String,depth:Int) {require(depth<=64){"JSON nesting limit exceeded."};when(value){is JSONObject->if(value.length()==0)add(category,e.name,path,"{}") else value.keys().asSequence().toList().sorted().forEach{walk(value.get(it),if(path.isEmpty())escapedJSONKey(it) else "$path.${escapedJSONKey(it)}",depth+1)};is JSONArray->if(value.length()==0)add(category,e.name,path,"[]") else (0 until value.length()).forEach{walk(value.get(it),"$path[$it]",depth+1)};else->add(category,e.name,path,value.toString())}}
       walk(if(text.trimStart().startsWith('{'))JSONObject(text)else JSONArray(text),"",0)
      } else if(text.trimStart().startsWith('<')) {
       require(!text.contains("<!DOCTYPE",true) && !text.contains("<!ENTITY",true)){"DTD/entity declarations are not supported."}
       val stack=mutableListOf<String>();val counts=mutableListOf<MutableMap<String,Int>>();counts+=mutableMapOf<String,Int>();val bodies=mutableListOf<StringBuilder>()
       var bounds=Bounds();var vertices=0L;var triangles=0L;var objectPath="";val properties=mutableMapOf<String,Long>()
       val handler=object:DefaultHandler(){
        override fun startElement(uri:String?,localName:String?,qName:String,a:Attributes){
         check();require(stack.size<64){"XML nesting limit exceeded."};val index=(counts.last()[qName]?:0)+1;counts.last()[qName]=index;stack+="$qName[$index]";counts+=mutableMapOf<String,Int>();bodies+=StringBuilder()
         val tag=qName.substringAfter(':');val path=stack.joinToString("/");if(ext=="model" && stack.size==1)require(tag=="model"){"Invalid 3MF model root."}
         if(ext=="model" && tag=="object"){bounds=Bounds();vertices=0;triangles=0;properties.clear();objectPath=path}
         if(ext=="model" && tag=="vertex") {bounds.vertex(doubleArrayOf(a.getValue("x").toDouble(),a.getValue("y").toDouble(),a.getValue("z").toDouble()));vertices++}
         else if(ext=="model" && tag=="triangle") {require(listOf("v1","v2","v3").all{a.getValue(it)?.toLongOrNull()?.let{v->v>=0 && v<vertices}==true}){"Invalid triangle vertex reference."};triangles++;repeat(a.length){j->val key=a.getQName(j);if(key !in listOf("v1","v2","v3")){val p="$key=${a.getValue(j)}";require(properties.size<30000);properties[p]=(properties[p]?:0)+1}}}
         else {repeat(a.length){j->add(category,e.name,"$path/@${a.getQName(j)}",a.getValue(j))};if(a.getValue("key")!=null && a.getValue("value")!=null)add(category,e.name,"$path/${a.getValue("key")}",a.getValue("value"))}
        }
        override fun characters(ch:CharArray,start:Int,length:Int){if(bodies.isNotEmpty() && !(ext=="model" && stack.last().substringBefore('[').substringAfter(':') in listOf("vertices","triangles"))){require(bodies.last().length+length<=65536){"XML text exceeds limit."};bodies.last().append(ch,start,length)}}
        override fun endElement(uri:String?,localName:String?,qName:String){
         val body=bodies.removeAt(bodies.lastIndex).toString().trim();if(body.isNotEmpty())add(category,e.name,stack.joinToString("/"),body)
         if(ext=="model" && qName.substringAfter(':')=="object") {add("Geometry",e.name,"$objectPath/vertices",vertices.toString());add("Geometry",e.name,"$objectPath/triangles",triangles.toString());if(vertices>0)add("Geometry",e.name,"$objectPath/local bounds",bounds.description());properties.toSortedMap().forEach{(k,v)->add("Geometry",e.name,"$objectPath/triangle property $k",v.toString())}}
         stack.removeAt(stack.lastIndex);counts.removeAt(counts.lastIndex)
        }
       }
       val factory=SAXParserFactory.newInstance();factory.isNamespaceAware=false
       // DTD bytes are rejected above; disable external resolution as defense in depth.
       val parser=factory.newSAXParser();parser.xmlReader.entityResolver=org.xml.sax.EntityResolver{_,_->throw org.xml.sax.SAXException("External entities are disabled.")}
       parser.xmlReader.contentHandler=handler;parser.xmlReader.errorHandler=handler;parser.xmlReader.parse(org.xml.sax.InputSource(data.inputStream()))
      } else add("Metadata",e.name,"unrecognized text",text)
     } catch(e:java.util.concurrent.CancellationException){throw e}
       catch(failure:Exception){throw IllegalArgumentException("${e.name}: ${failure.message ?: "Cannot inspect archive entry."}",failure)}
    }
    warnings+="Project settings are not sliced usage. Sliced results are exporter estimates, not actual printer measurements. Missing values remain unknown; duplicate statistics are not summed."
    warnings+="Mesh bounds are local resource coordinates. Build/component transforms, object roles and material assignments are retained as metadata. No assembled dimensions, toolpath-derived support/tower grams, texture or paint decoding is performed."
   }
   else->error("Choose an STL or 3MF file.")
  }
  check()
  return ModelReport(name,name.substringAfterLast('.').uppercase(),fields.toList(),warnings.toList())
 }
 private fun escapedJSONKey(key:String)=key.replace("\\","\\\\").replace(".","\\.").replace("[","\\[").replace("]","\\]")
 private class Bounds {
  val min=DoubleArray(3){Double.POSITIVE_INFINITY};val max=DoubleArray(3){Double.NEGATIVE_INFINITY}
  fun vertex(v:DoubleArray){require(v.all{it.isFinite()}){"Nonfinite geometry coordinate."};repeat(3){min[it]=kotlin.math.min(min[it],v[it]);max[it]=kotlin.math.max(max[it],v[it])}}
  fun description()="min (${min.joinToString()}); max (${max.joinToString()})"
 }
}
