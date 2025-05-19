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

@Suite(.serialized) class TestCatalogCache {
    let LOREM_IPSUM = "lorem ipsum"
    var catalog: Catalog
    var cache: CatalogCache

    init() throws {
        let decoder = JSONDecoder()
        catalog = try decoder.decode(
            Catalog.self,
            from: Data(
                contentsOf: Bundle.module.url(
                    forResource: "sqlite_schema",
                    withExtension: "json",
                )!
            )
        )
        cache = CatalogCache(from: catalog)
    }

    @Test func schema() {
        // get nonexistent schema
        var gotSchema = cache.getSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        #expect(gotSchema == nil)
        // create schema and assert it was created
        let wantSchema = Schema()
        wantSchema.schemaName = LOREM_IPSUM
        cache.addOrUpdateSchema(catalog: catalog, schema: wantSchema)
        gotSchema = cache.getSchema(catalog: catalog, schemaName: LOREM_IPSUM)
        #expect(gotSchema === wantSchema)
        // modify schema and assert it was modified
        wantSchema.viewsValid = true
        cache.addOrUpdateSchema(catalog: catalog, schema: wantSchema)
        gotSchema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        #expect(gotSchema!.viewsValid == wantSchema.viewsValid)
    }

    @Test func view() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        // get nonexistent view
        var gotView = cache.getView(schema: schema, viewName: LOREM_IPSUM)
        #expect(gotView == nil)
        // create view and assert it was created
        let wantView = View()
        wantView.viewSchema = LOREM_IPSUM
        wantView.viewName = LOREM_IPSUM
        cache.addOrUpdateView(schema: schema, view: wantView)
        gotView = cache.getView(schema: schema, viewName: LOREM_IPSUM)
        #expect(gotView === wantView)
        // modify view and assert it was modified
        wantView.sql = LOREM_IPSUM
        cache.addOrUpdateView(schema: schema, view: wantView)
        gotView = cache.getOrCreateView(schema: schema, viewName: LOREM_IPSUM)
        #expect(gotView!.sql == wantView.sql)
    }

    @Test func table() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        // get nonexistent table
        var gotTable = cache.getTable(schema: schema, tableName: LOREM_IPSUM)
        #expect(gotTable == nil)
        // create table and assert it was created
        let wantTable = Table()
        wantTable.tableSchema = LOREM_IPSUM
        wantTable.tableName = LOREM_IPSUM
        cache.addOrUpdateTable(schema: schema, table: wantTable)
        gotTable = cache.getTable(schema: schema, tableName: LOREM_IPSUM)
        #expect(gotTable === wantTable)
        // modify table and assert it was modified
        wantTable.sql = LOREM_IPSUM
        cache.addOrUpdateTable(schema: schema, table: wantTable)
        gotTable = cache.getOrCreateTable(
            schema: schema,
            tableName: LOREM_IPSUM
        )
        #expect(gotTable!.sql == wantTable.sql)
    }
    
    @Test func column() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        let table = cache.getOrCreateTable(
            schema: schema,
            tableName: LOREM_IPSUM
        )
        // get nonexistent column
        var gotColumn = cache.getColumn(table: table, columnName: LOREM_IPSUM)
        #expect(gotColumn == nil)
        // create column and assert it was created
        let wantColumn = Column()
        wantColumn.tableSchema = LOREM_IPSUM
        wantColumn.tableName = LOREM_IPSUM
        wantColumn.columnName = LOREM_IPSUM
        wantColumn.columnType = LOREM_IPSUM
        cache.addOrUpdateColumn(table: table, column: wantColumn)
        gotColumn = cache.getColumn(table: table, columnName: LOREM_IPSUM)
        #expect(gotColumn === wantColumn)
        // modify column and assert it was modified
        wantColumn.columnDefault = LOREM_IPSUM
        cache.addOrUpdateColumn(table: table, column: wantColumn)
        gotColumn = cache.getOrCreateColumn(table: table, columnName: LOREM_IPSUM)
        #expect(gotColumn!.columnDefault == wantColumn.columnDefault)
    }
    
    @Test func constraints() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        let table = cache.getOrCreateTable(
            schema: schema,
            tableName: LOREM_IPSUM
        )
        // get nonexistent primary key
        var gotConstraint = cache.getConstraint(table: table, constraintName: LOREM_IPSUM)
        #expect(gotConstraint == nil)
        // create primary key and assert it was created
        let wantConstraint = Constraint()
        wantConstraint.tableSchema = LOREM_IPSUM
        wantConstraint.tableName = LOREM_IPSUM
        wantConstraint.constraintName = LOREM_IPSUM
        wantConstraint.constraintType = PRIMARY_KEY
        wantConstraint.columns = [LOREM_IPSUM]
        cache.addOrUpdateConstraint(table: table, constraint: wantConstraint)
        gotConstraint = cache.getConstraint(table: table, constraintName: LOREM_IPSUM)
        #expect(gotConstraint === wantConstraint)
        var gotPrimaryKey = cache.getPrimaryKey(table: table)
        #expect(gotPrimaryKey === wantConstraint)
        // modify primary key and assert it was modified
        wantConstraint.updateRule = LOREM_IPSUM
        cache.addOrUpdateConstraint(table: table, constraint: wantConstraint)
        gotConstraint = cache.getOrCreateConstraint(table: table, constraintName: LOREM_IPSUM)
        #expect(gotConstraint === wantConstraint)
        gotPrimaryKey = cache.getPrimaryKey(table: table)
        #expect(gotPrimaryKey === wantConstraint)
        // get nonexistent foreign keys
        var gotForeignKeys = cache.getForeignKeys(table: table)
        #expect(gotForeignKeys.isEmpty)
        // create foreign keys and assert they were created
        var wantForeignKeys: [Constraint] = []
        for i in 1...3 {
            wantForeignKeys.append(Constraint())
            wantForeignKeys.last!.tableSchema = LOREM_IPSUM
            wantForeignKeys.last!.tableName = LOREM_IPSUM
            wantForeignKeys.last!.constraintName = String(i)
            wantForeignKeys.last!.constraintType = FOREIGN_KEY
        }
        for wantForeignKey in wantForeignKeys {
            cache.addOrUpdateConstraint(table: table, constraint: wantForeignKey)
        }
        gotForeignKeys = cache.getForeignKeys(table: table)
        for (i, wantForeignKey) in wantForeignKeys.enumerated() {
            let gotForeignKey = gotForeignKeys[i]
            #expect(gotForeignKey === wantForeignKey)
        }
        // modify foreign keys and assert they were modified
        for wantForeignKey in wantForeignKeys {
            wantForeignKey.updateRule = LOREM_IPSUM
            cache.addOrUpdateConstraint(table: table, constraint: wantForeignKey)
        }
        gotForeignKeys = cache.getForeignKeys(table: table)
        for (i, wantForeignKey) in wantForeignKeys.enumerated() {
            let gotForeignKey = gotForeignKeys[i]
            #expect(gotForeignKey === wantForeignKey)
        }
    }
    
    @Test func index() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        let table = cache.getOrCreateTable(
            schema: schema,
            tableName: LOREM_IPSUM
        )
        // get nonexistent index
        var gotIndex = cache.getIndex(table: table, indexName: LOREM_IPSUM)
        #expect(gotIndex == nil)
        // create index and assert it was created
        let wantIndex = Index()
        wantIndex.tableSchema = LOREM_IPSUM
        wantIndex.tableName = LOREM_IPSUM
        wantIndex.indexName = LOREM_IPSUM
        wantIndex.columns = [LOREM_IPSUM]
        cache.addOrUpdateIndex(table: table, index: wantIndex)
        gotIndex = cache.getIndex(table: table, indexName: LOREM_IPSUM)
        #expect(gotIndex === wantIndex)
        // modify index and assert it was modified
        wantIndex.sql = LOREM_IPSUM
        cache.addOrUpdateIndex(table: table, index: wantIndex)
        gotIndex = cache.getOrCreateIndex(table: table, indexName: LOREM_IPSUM)
        #expect(gotIndex === wantIndex)
    }
    
    @Test func trigger() {
        let schema = cache.getOrCreateSchema(
            catalog: catalog,
            schemaName: LOREM_IPSUM
        )
        let table = cache.getOrCreateTable(
            schema: schema,
            tableName: LOREM_IPSUM
        )
        // get nonexistent trigger
        var gotTrigger = cache.getTrigger(table: table, triggerName: LOREM_IPSUM)
        #expect(gotTrigger == nil)
        // create trigger and assert it was created
        let wantTrigger = Trigger()
        wantTrigger.tableSchema = LOREM_IPSUM
        wantTrigger.tableName = LOREM_IPSUM
        wantTrigger.triggerName = LOREM_IPSUM
        cache.addOrUpdateTrigger(table: table, trigger: wantTrigger)
        gotTrigger = cache.getTrigger(table: table, triggerName: LOREM_IPSUM)
        #expect(gotTrigger === wantTrigger)
        // modify trigger and assert it was modified
        wantTrigger.sql = LOREM_IPSUM
        cache.addOrUpdateTrigger(table: table, trigger: wantTrigger)
        gotTrigger = cache.getOrCreateTrigger(table: table, triggerName: LOREM_IPSUM)
        #expect(gotTrigger === wantTrigger)
    }
}
