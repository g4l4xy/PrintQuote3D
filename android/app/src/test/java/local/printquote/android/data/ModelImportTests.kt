package local.printquote.android.data

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ModelImportTests {
 private fun fixture(name:String,block:(File)->Unit){val f=File.createTempFile("model-test-",".tmp");try{javaClass.classLoader!!.getResourceAsStream("model-import/$name")!!.use{input->f.outputStream().use{input.copyTo(it)}};block(f)}finally{f.delete()}}
 @Test fun asciiAndBinarySTLAgree(){for(name in listOf("triangle.stl","binary-solid.stl"))fixture(name){f->val r=ModelImport.inspect(f,name);assertEquals("1",r.fields.single{it.key=="triangles"}.value);assertTrue(r.fields.single{it.key=="bounds"}.value.contains("20.0"));assertTrue(r.fields.none{it.category=="Sliced results"})}}
 @Test fun slicerMetadataPreservesScopesAndUnknownFields(){fixture("orca-sliced.3mf"){f->val r=ModelImport.inspect(f,"orca-sliced.3mf")
fun field(key:String,value:String)=r.fields.any{it.key.endsWith(key) && it.value==value}
assertTrue(field("printer_model","Bambu Lab X1 Carbon"));assertTrue(field("filament_type[1]","PETG"));assertTrue(field("filament_colour[0]","#FF0000"));assertTrue(field("unknown_future_field.value","retained"));assertTrue(field("enable_support","1"));assertTrue(field("enable_prime_tower","1"));assertTrue(r.fields.any{it.category=="Sliced results" && it.key.endsWith("/@used_g") && it.value=="12.5"});assertTrue(field("/triangles","1"));assertTrue(field("/@transform","1 0 0 0 1 0 0 0 1 10 20 30"));assertTrue(r.fields.any{it.value.contains("Prime tower")});assertFalse(r.fields.any{it.key=="support grams"})}}
 @Test fun rejectsUnsafeMalformedAndDeepFiles(){for(name in listOf("unsafe.3mf","entities.3mf","malformed.3mf","deep.3mf","truncated.stl"))fixture(name){f->assertThrows(Exception::class.java){ModelImport.inspect(f,name)}}}
 @Test fun cancellationStopsInspection(){fixture("orca-sliced.3mf"){f->assertThrows(java.util.concurrent.CancellationException::class.java){ModelImport.inspect(f,"orca-sliced.3mf"){true}}}}
 @Test fun userSampleWhenExplicitlyProvided(){val sample=System.getenv("PRINTQUOTE_TEST_MODEL");org.junit.Assume.assumeTrue(sample!=null);val r=ModelImport.inspect(File(sample));assertTrue(r.fields.any{it.key=="printer_model"});assertTrue(r.fields.any{it.category=="Geometry" && it.key.endsWith("/triangles") && it.value.toInt()>0})}
}
