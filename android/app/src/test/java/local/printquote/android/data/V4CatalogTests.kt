package local.printquote.android.data

import org.junit.Test
import org.junit.Assert.*
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID
import java.nio.file.Files

class V4CatalogTests {
 private fun product(count:Int):JSONObject {
  val variants=JSONArray()
  repeat(count){i->variants.put(JSONObject().put("id",UUID.randomUUID().toString()).put("name",if(i%2==0)"Black" else "Red").put("colorHex","#000000").put("sizes",JSONArray().put(JSONObject().put("id",UUID.randomUUID().toString()).put("diameterMM",1.75).put("netWeightGrams",1000))))}
  return JSONObject().put("id",UUID.randomUUID().toString()).put("brand","Maker").put("name","Test PLA").put("materialFamily","PLA").put("variants",variants)
 }
 @Test fun inlineInventoryEditsValidateAndPreserveImportedValues(){
  val original=JSONObject().put("id","material").put("pricePerKG",20).put("catalogSnapshot",JSONObject().put("fields",JSONObject().put("density",1.24)))
  val edited=inlineMaterialEdit(original,"Price / kg","47.25")
  assertEquals(20,original.getInt("pricePerKG"));assertEquals("47.25",edited.get("pricePerKG").toString());assertEquals(original.getJSONObject("catalogSnapshot").toString(),edited.getJSONObject("catalogSnapshot").toString())
  try{inlineMaterialEdit(original,"Stock (g)","-1");fail("Negative stock must fail")}catch(_:IllegalArgumentException){}
  try{inlineMaterialEdit(original,"Price / kg","12oops");fail("Partial numeric strings must fail")}catch(_:IllegalArgumentException){}
 }
 @Test fun priceAndTechnicalSortingKeepUnknownsLast(){
  val rows=listOf(CatalogRecord("unknown","A","Maker","PLA"),CatalogRecord("expensive","B","Maker","PLA",difficulty="Hard",drying="Required"),CatalogRecord("cheap","C","Maker","PLA",difficulty="Easy",drying="Not required"))
  val index=FilamentCatalogIndex(rows)
  assertEquals("cheap",index.search(CatalogQuery(sort="Price / kg"),prices=mapOf("cheap" to 12.0,"expensive" to 47.0)).rows.first().id)
  assertEquals("cheap",index.search(CatalogQuery(sort="Difficulty")).rows.first().id)
  assertEquals("unknown",index.search(CatalogQuery(sort="Drying Requirement")).rows.last().id)
 }
 @Test fun sharedFixtureKeepsAllSpoolSizes(){
  val text=javaClass.classLoader!!.getResourceAsStream("v4-filament-fixture.json")!!.bufferedReader().use{it.readText()}
  val root=JSONObject(text);val n=CatalogNormalizer();val products=root.getJSONArray("products");val rows=(0 until products.length()).flatMap{n.product(products.getJSONObject(it))}
  assertEquals(4,n.diagnostics.products);assertEquals(40,n.diagnostics.variants);assertEquals(120,n.diagnostics.stored);assertEquals(120,FilamentCatalogIndex(rows).search(CatalogQuery()).matches)
 }
 @Test fun fullPipelineNeverCollapsesColorsIntoThreeSamples(){
  val normalizer=CatalogNormalizer();val rows=normalizer.product(product(120));val index=FilamentCatalogIndex(rows)
  assertEquals(120,normalizer.diagnostics.discovered);assertEquals(120,normalizer.diagnostics.stored);assertEquals(120,index.search(CatalogQuery()).matches)
  assertEquals(60,index.search(CatalogQuery(text="black PLA")).matches)
  assertEquals(1,index.search(CatalogQuery(favoritesOnly=true),setOf(rows[0].id)).matches)
  assertEquals(1,index.search(CatalogQuery(recentOnly=true),recent=mapOf(rows[1].id to 123L)).matches)
 }
 @Test fun rejectedAndDuplicateSpoolsHaveReasons(){
  val source=product(120);val variants=source.getJSONArray("variants");variants.put(variants.getJSONObject(0));variants.getJSONObject(1).put("colorHex","bad-color")
  val normalizer=CatalogNormalizer();normalizer.product(source);val c=normalizer.diagnostics
  assertEquals(119,c.stored);assertEquals(1,c.duplicates);assertEquals(1,c.rejected);assertEquals(c.discovered,c.stored+c.rejected+c.duplicates);assertEquals(2,c.quarantine.size)
 }
 @Test fun fiftyThousandRowsUseBoundedPages(){
  val rows=(0 until 50000).map{CatalogRecord("spool-$it","Test $it",if(it%2==0)"Maker A" else "Maker B","PLA",color="Black")}
  val index=FilamentCatalogIndex(rows);val query=CatalogQuery(text="black PLA",brands=setOf("Maker B"))
  val first=index.search(query);val second=index.search(query.copy(offset=100))
  assertEquals(25000,first.matches);assertEquals(100,first.rows.size);assertTrue(first.rows.map{it.id}.intersect(second.rows.map{it.id}.toSet()).isEmpty())
 }
 @Test fun journalSurvivesRelaunchAndPreservesNewestDraft(){
  val folder=Files.createTempDirectory("pq-recovery-test").toFile()
  try {val id=UUID.randomUUID().toString();val journal=DraftJournal(folder);journal.write(JSONObject().put("id",id).put("notes","first").toString());journal.write(JSONObject().put("id",id).put("notes","latest").toString());val restored=DraftJournal(folder).read();assertEquals(1,restored.size);assertEquals("latest",restored[0].getString("notes"));java.io.File(folder,"bad.json").writeText("broken");val scan=journal.scan();assertEquals(1,scan.drafts.size);assertEquals(1,scan.issues.size);assertTrue(java.io.File(folder,"bad.json").exists());java.io.File(folder,"bad.json").delete();journal.discard(id);assertTrue(journal.read().isEmpty())} finally {folder.deleteRecursively()}
 }
 @Test fun queuedWorkspaceWritesPreserveUnrelatedChanges(){
  val base=JSONObject().put("quotes",JSONArray().put(JSONObject().put("id","q").put("notes","old"))).put("filaments",JSONArray().put(JSONObject().put("id","m").put("price",20)))
  val latest=JSONObject(base.toString());latest.getJSONArray("quotes").getJSONObject(0).put("notes","autosaved")
  val next=JSONObject(base.toString());next.getJSONArray("filaments").getJSONObject(0).put("price",47)
  val merged=mergeWorkspaceChanges(latest,base,next)
  assertEquals("autosaved",merged.getJSONArray("quotes").getJSONObject(0).getString("notes"));assertEquals(47,merged.getJSONArray("filaments").getJSONObject(0).getInt("price"))
 }
}
