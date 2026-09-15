import XCTest
import QuoteDomain
@testable import QuoteData

final class FilamentRepositoryTests:XCTestCase {
    func synthetic(_ count:Int)throws->Data {
        let original=try JSONSerialization.jsonObject(with:SeedLoader.data("open_filaments_v2")) as! [String:Any]
        var root=original;let template=(original["products"] as! [[String:Any]])[0]
        var products=[[String:Any]]()
        for i in 0..<count {
            var product=template;product["id"]=UUID().uuidString;product["name"]="Test Product \(i)";product["brand"]=i%2==0 ? "Maker A":"Maker B";product["materialFamily"]=i%2==0 ? "PLA":"PETG"
            var variant=(product["variants"] as! [[String:Any]])[0];variant["id"]=UUID().uuidString;variant["name"]=i%3==0 ? "Black":"Red"
            var size=(variant["sizes"] as! [[String:Any]])[0];size["id"]=UUID().uuidString;variant["sizes"]=[size];product["variants"]=[variant];products.append(product)
        }
        root["products"]=products;return try JSONSerialization.data(withJSONObject:root)
    }
    func testSharedFixtureKeepsThreeSpoolSizesPerColor()async throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let repo=try FilamentRepository();let (_,counts)=try await repo.rebuild(data:Data(contentsOf:root.appendingPathComponent("SharedSchemas/v4-filament-fixture.json")))
        XCTAssertEqual(counts.products,4);XCTAssertEqual(counts.variants,40);XCTAssertEqual(counts.stored,120)
        let page=try await repo.search(.init());XCTAssertEqual(page.matches,120);XCTAssertEqual(Set(page.rows.map(\.id)).count,100)
    }
    func testCatalogIsNotThreeInventorySamples()async throws {
        let repo=try FilamentRepository();let (_,c)=try await repo.rebuild(data:SeedLoader.data("open_filaments_v2"))
        XCTAssertEqual(c.products,2089);XCTAssertEqual(c.variants,14577);XCTAssertEqual(c.discovered,22355)
        XCTAssertEqual(c.discovered,c.normalized+c.rejected+c.duplicates)
        XCTAssertEqual(c.stored,22355);XCTAssertEqual(c.rejected,0);XCTAssertEqual(c.duplicates,0)
        let page=try await repo.search(.init());XCTAssertEqual(page.rows.count,100);XCTAssertEqual(page.matches,c.stored)
    }
    func testHundredRecordsColorsFiltersAndFavorites()async throws {
        let repo=try FilamentRepository();let data=try synthetic(120);let (_,c)=try await repo.rebuild(data:data)
        XCTAssertEqual(c.discovered,120);XCTAssertEqual(c.stored,120)
        var query=FilamentQuery();query.text="black PLA";let black=try await repo.search(query);XCTAssertEqual(black.matches,20)
        let id=try XCTUnwrap(black.rows.first?.id);try await repo.favorite(id,enabled:true);try await repo.used(id)
        _ = try await repo.rebuild(data:data)
        query = .init();query.favoritesOnly=true;let favorite=try await repo.search(query);XCTAssertEqual(favorite.matches,1)
        query = .init();query.recentOnly=true;let recent=try await repo.search(query);XCTAssertEqual(recent.matches,1)
        query = .init();query.manufacturers=["Maker B"];let manufacturer=try await repo.search(query);XCTAssertEqual(manufacturer.matches,60)
    }
    func testQuarantineAndFailedRefreshPreserveIndex()async throws {
        let repo=try FilamentRepository();var root=try JSONSerialization.jsonObject(with:synthetic(120)) as! [String:Any]
        var products=root["products"] as! [[String:Any]];products[0]["materialFamily"]="";products.append(products[1]);root["products"]=products
        let (_,c)=try await repo.rebuild(data:JSONSerialization.data(withJSONObject:root));XCTAssertEqual(c.stored,119);XCTAssertEqual(c.rejected,1);XCTAssertEqual(c.duplicates,1);XCTAssertEqual(c.quarantine.count,2)
        root["schemaVersion"]=999
        do{_ = try await repo.rebuild(data:JSONSerialization.data(withJSONObject:root));XCTFail("Must reject unknown schema")}catch{}
        let page=try await repo.search(.init());XCTAssertEqual(page.matches,119)
    }
    func testCanceledRebuildRollsBackToLastGoodIndex()async throws {
        let repo=try FilamentRepository();let old=try synthetic(120);_ = try await repo.rebuild(data:old)
        let large=try synthetic(2000)
        let task=Task.detached {try await repo.rebuild(data:large,progress:{stage in
            if stage.hasPrefix("Indexing") {withUnsafeCurrentTask{$0?.cancel()}}
        })}
        do {_ = try await task.value;XCTFail("Refresh must cancel")}catch is CancellationError{}catch{XCTFail("Unexpected error: \(error)")}
        let page=try await repo.search(.init());XCTAssertEqual(page.matches,120)
    }
    func testInventoryPriceSortDoesNotInventSourcePrices()async throws {
        let repo=try FilamentRepository();_ = try await repo.rebuild(data:synthetic(120));let page=try await repo.search(.init())
        var expensive=FilamentProduct();expensive.id=UUID(uuidString:page.rows[0].id)!;expensive.pricePerKG=47
        var cheap=FilamentProduct();cheap.id=UUID(uuidString:page.rows[1].id)!;cheap.pricePerKG=12
        try await repo.syncInventoryPrices([expensive,cheap]);var query=FilamentQuery();query.sort="Price / kg"
        let sorted=try await repo.search(query);XCTAssertEqual(sorted.rows[0].id,cheap.id.uuidString);XCTAssertEqual(sorted.rows[1].id,expensive.id.uuidString);XCTAssertEqual(sorted.rows[2].price,"")
    }
    func testLargeVariantIndex()async throws {
        let repo=try FilamentRepository();let (_,c)=try await repo.rebuild(data:synthetic(50000));XCTAssertEqual(c.stored,50000)
        var query=FilamentQuery();query.text="black PETG";let page=try await repo.search(query);XCTAssertGreaterThan(page.matches,3000);XCTAssertEqual(page.rows.count,100)
        query.offset=100;let next=try await repo.search(query);XCTAssertNotEqual(page.rows.first?.id,next.rows.first?.id)
    }
}
