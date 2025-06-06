import Foundation
import Testing

@testable import SQL

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
