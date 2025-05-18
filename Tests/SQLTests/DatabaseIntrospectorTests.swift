import Foundation
import Testing

@testable import SQL

class Test_generateName {
    @Test func primaryKey() {
        let gotName = generateName(
            nameType: PRIMARY_KEY,
            tableName: "tbl",
            columnNames: ["col"]
        )
        #expect(gotName == "tbl_col_pkey")
    }

    @Test func foreignKey() {
        let gotName = generateName(
            nameType: FOREIGN_KEY,
            tableName: "tbl",
            columnNames: ["col"]
        )
        #expect(gotName == "tbl_col_fkey")
    }

    @Test func unique() {
        let gotName = generateName(
            nameType: UNIQUE,
            tableName: "tbl",
            columnNames: ["col 1", "col 2"]
        )
        #expect(gotName == "tbl_col_1_col_2_key")
    }

    @Test func check() {
        let gotName = generateName(
            nameType: CHECK,
            tableName: "my tbl",
            columnNames: ["col"]
        )
        #expect(gotName == "my_tbl_col_check")
    }

    @Test func index() {
        let gotName = generateName(
            nameType: INDEX,
            tableName: "tbl",
            columnNames: ["col1", "col2"]
        )
        #expect(gotName == "tbl_col1_col2_idx")
    }
}

class Test_isLiteral {
    @Test func empty() {
        let isTrue = isLiteral("")
        #expect(isTrue == false)
    }

    @Test func string() {
        let isTrue = isLiteral("'lorem ipsum'")
        #expect(isTrue == true)
    }

    @Test func knownLiteral() {
        let isTrue = isLiteral("current_timestamp")
        #expect(isTrue == true)
    }

    @Test func int() {
        let isTrue = isLiteral("123")
        #expect(isTrue == true)
    }

    @Test func double() {
        let isTrue = isLiteral("3.14")
        #expect(isTrue == true)
    }

    @Test func expression() {
        let isTrue = isLiteral("strftime('%s', 'now')")
        #expect(isTrue == false)
    }
}

// TODO: port from ddl_test.go (only handle SQLite)
class Test_wrappedInBrackets {
    @Test func empty() {
        let isTrue = wrappedInBrackets("")
        #expect(isTrue == false)
    }

    @Test func brackets() {
        let isTrue = wrappedInBrackets("(strftime('%s', 'now'))")
        #expect(isTrue == true)
    }

    @Test func noBrackets() {
        let isTrue = wrappedInBrackets("1 + 1")
        #expect(isTrue == false)
    }

    @Test func partialBrackets() {
        let isTrue = wrappedInBrackets("strftime('%s', 'now')")
        #expect(isTrue == false)
    }
}

// TODO: port from ddl_test.go (only handle SQLite)
class Test_wrapBrackets {
    @Test func empty() {
        let gotResult = wrapBrackets("")
        #expect(gotResult == "")
    }

    @Test func noBrackets() {
        let gotResult = wrapBrackets("lorem ipsum")
        #expect(gotResult == "(lorem ipsum)")
    }

    @Test func hasBrackets() {
        let gotResult = wrapBrackets("(lorem ipsum)")
        #expect(gotResult == "(lorem ipsum)")
    }
}

// TODO: port from ddl_test.go (only handle SQLite)
class Test_unwrapBrackets {
    @Test func empty() {
        let gotResult = unwrapBrackets("")
        #expect(gotResult == "")
    }

    @Test func hasBrackets() {
        let gotResult = unwrapBrackets("(lorem ipsum)")
        #expect(gotResult == "lorem ipsum")
    }

    @Test func noBrackets() {
        let gotResult = unwrapBrackets("lorem ipsum")
        #expect(gotResult == "lorem ipsum")
    }
}

// TODO: port from ddl_test.go (only handle SQLite)
class Test_normalizeColumnType {
    @Test func loremIpsum() {
        let (gotNormalizedType, gotArg1, gotArg2) = normalizeColumnType(
            columnType: "lorem ipsum"
        )
        #expect(gotNormalizedType == "LOREM IPSUM")
        #expect(gotArg1 == "")
        #expect(gotArg2 == "")
    }

    @Test func numeric() {
        let (gotNormalizedType, gotArg1, gotArg2) = normalizeColumnType(
            columnType: "NUMERIC(5,2)"
        )
        #expect(gotNormalizedType == "NUMERIC")
        #expect(gotArg1 == "5")
        #expect(gotArg2 == "2")
    }

    @Test func numericSpaced() {
        let (gotNormalizedType, gotArg1, gotArg2) = normalizeColumnType(
            columnType: "numeric (5, 2)"
        )
        #expect(gotNormalizedType == "NUMERIC")
        #expect(gotArg1 == "5")
        #expect(gotArg2 == "2")
    }

    @Test func varchar() {
        let (gotNormalizedType, gotArg1, gotArg2) = normalizeColumnType(
            columnType: "VARCHAR(255)"
        )
        #expect(gotNormalizedType == "VARCHAR")
        #expect(gotArg1 == "255")
        #expect(gotArg2 == "")
    }

    @Test func varcharSpaced() {
        let (gotNormalizedType, gotArg1, gotArg2) = normalizeColumnType(
            columnType: "varchar    (255)"
        )
        #expect(gotNormalizedType == "VARCHAR")
        #expect(gotArg1 == "255")
        #expect(gotArg2 == "")
    }
}

// TODO: port from ddl_test.go (only handle SQLite)
class Test_normalizeColumnDefault {
    @Test func literalOne() {
        let gotDefault = normalizeColumnDefault(columnDefault: "1")
        #expect(gotDefault == "'1'")
    }

    @Test func literalOneQuoted() {
        let gotDefault = normalizeColumnDefault(columnDefault: "'1'")
        #expect(gotDefault == "'1'")
    }

    @Test func literalTrue() {
        let gotDefault = normalizeColumnDefault(columnDefault: "true")
        #expect(gotDefault == "'1'")
    }

    @Test func literalZero() {
        let gotDefault = normalizeColumnDefault(columnDefault: "0")
        #expect(gotDefault == "'0'")
    }

    @Test func literalZeroQuoted() {
        let gotDefault = normalizeColumnDefault(columnDefault: "'0'")
        #expect(gotDefault == "'0'")
    }

    @Test func literalFalse() {
        let gotDefault = normalizeColumnDefault(columnDefault: "false")
        #expect(gotDefault == "'0'")
    }

    @Test func datetimeFunction() {
        let gotDefault = normalizeColumnDefault(columnDefault: "datetime()")
        #expect(gotDefault == "CURRENT_TIMESTAMP")
    }

    @Test func datetimeNowFunction() {
        let gotDefault = normalizeColumnDefault(
            columnDefault: "datetime('now')"
        )
        #expect(gotDefault == "CURRENT_TIMESTAMP")
    }

    @Test func currentTimestamp() {
        let gotDefault = normalizeColumnDefault(
            columnDefault: "current_timestamp"
        )
        #expect(gotDefault == "CURRENT_TIMESTAMP")
    }
}

// TODO: port from ddl_test.go
class Test_compareVersionNums {
    @Test func lowerThanMajor() {
        let v1 = [7, 1, 1]
        let v2 = [8]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == -1)
    }

    @Test func lowerThanMinor() {
        let v1 = [10, 2]
        let v2 = [10, 3]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == -1)
    }

    @Test func equal() {
        let v1 = [10, 2]
        let v2 = [10, 2]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == 0)
    }

    @Test func greaterThanMinor() {
        let v1 = [10, 3]
        let v2 = [10, 2]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == 1)
    }

    @Test func greaterThanMajor() {
        let v1 = [11, 10, 9]
        let v2 = [9, 10, 11]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == 1)
    }

    @Test func v1Shorter() {
        let v1 = [14, 2]
        let v2 = [14, 2, 1]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == -1)
    }

    @Test func v2Shorter() {
        let v1 = [14, 2, 1]
        let v2 = [14, 2]
        #expect(compareVersionNums(lhs: v1, rhs: v2) == 1)
    }
}

@Test func TestCatalogCache() throws {
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(
        Catalog.self,
        from: Data(
            contentsOf: Bundle.module.url(
                forResource: "sqlite_schema",
                withExtension: "json",
            )!
        )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    //    #expect(String(data: try encoder.encode(catalog), encoding: .utf8) != nil)
    print(String(data: try encoder.encode(catalog), encoding: .utf8)!)
}
