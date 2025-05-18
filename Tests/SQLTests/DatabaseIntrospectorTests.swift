import Foundation
import Testing

@testable import SQL

@Test func testCatalogEncodeDecode() throws {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try jsonEncoder.encode(Catalog())
    print(String(data: data, encoding: .utf8)!)
}
