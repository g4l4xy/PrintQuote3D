import local.printquote.windows.*
import local.printquote.android.model.*
import local.printquote.android.pricing.PricingEngine
import org.junit.Test
import org.junit.Assert.*
import java.nio.file.Files
import java.sql.DriverManager

class SqliteTests {
 @Test fun databaseRoundTripPreservesOverridesSnapshotsAndDecimalPrecision(){
  val dir=Files.createTempDirectory("printquote-sqlite");try{
   val db=SqliteWorkspaceStore(dir.resolve("workspace.sqlite"));val l=db.load()
   assertEquals(1007,l.array("printers").size)
   val p=l.array("printers").first();p.put("machineRate","123.1234567890123456789")
   val q=Defaults.quote(l);q.put("result",PricingEngine.calculate(q.getJSONObject("input")))
   l.put("quotes",array(listOf(q)));p.put("machineRate",999);l.put("unknownFutureField","preserved");db.save(l)
   val restored=SqliteWorkspaceStore(dir.resolve("workspace.sqlite")).load()
   assertEquals("preserved",restored.text("unknownFutureField"))
   assertEquals("123.1234567890123456789",restored.array("quotes").first().getJSONObject("printer").text("machineRate"))
   assertEquals(1007,restored.array("printers").size)
  }finally{dir.toFile().deleteRecursively()}
 }
 @Test fun unsupportedDocumentDoesNotResetDatabase(){
  val dir=Files.createTempDirectory("printquote-invalid");try{
   val path=dir.resolve("workspace.sqlite");val db=SqliteWorkspaceStore(path);db.load()
   DriverManager.getConnection("jdbc:sqlite:$path").use{c->c.createStatement().use{it.executeUpdate("UPDATE workspace SET payload='{\"formatVersion\":99,\"document\":{}}'")}}
   assertThrows(IllegalArgumentException::class.java){db.load()}
   DriverManager.getConnection("jdbc:sqlite:$path").use{c->c.createStatement().use{s->s.executeQuery("SELECT payload FROM workspace").use{r->r.next();assertTrue(r.getString(1).contains("99"))}}}
  }finally{dir.toFile().deleteRecursively()}
 }
 @Test fun catalogImportPreservesFieldPriorityAndSelectedSize(){
  val catalog=MaterialCatalogRepository{resource("open_filaments_v2.json").bufferedReader()}
  assertEquals(2089,catalog.index().size)
  val(p,meta)=catalog.product(catalog.index().first().id)
  val v=p.array("variants").first();val s=v.array("sizes").first()
  val material=MaterialCatalogRepository.material(p,v,s,meta,"24.95")
  assertEquals(s.text("id"),material.text("id"));assertEquals("24.95",material.text("pricePerKG"))
  assertTrue(material.getJSONObject("catalogSnapshot").getJSONObject("fields").length()>0)
 }
}
