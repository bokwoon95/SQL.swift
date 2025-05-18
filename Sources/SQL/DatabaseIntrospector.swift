import Foundation
import SQLite3

// DatabaseIntrospector.swift, MigrateCmd.swift, GenerateCmd.swift, AutomigrateCmd.swift

// ddl.go, catalog_cache.go, database_introspector.go

public let PRIMARY_KEY = "PRIMARY KEY"
public let FOREIGN_KEY = "FOREIGN KEY"
public let UNIQUE = "UNIQUE"
public let CHECK = "CHECK"
public let INDEX = "INDEX"

public let RESTRICT = "RESTRICT"
public let CASCADE = "CASCADE"
public let NO_ACTION = "NO ACTION"
public let SET_NULL = "SET NULL"
public let SET_DEFAULT = "SET DEFAULT"

public class Catalog: Codable {
    public var VersionNums: [Int] = []
    public var CatalogName: String = ""
    public var CurrentSchema: String = ""
    public var Schemas: [Schema] = []
}

public class Schema: Codable {
    public var SchemaName: String = ""
    public var Tables: [Table] = []
    public var Views: [View] = []
    public var ViewsValid: Bool = false
    public var Ignore: Bool = false
}

public class View: Codable {
    public var ViewSchema: String = ""
    public var ViewName: String = ""
    public var SQL: String = ""
    public var Columns: [String] = []
    public var ColumnTypes: [String] = []
    public var Ignore: Bool = false
}

public class Table: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var SQL: String = ""
    public var IsVirtual: Bool = false
    public var Columns: [Column] = []
    public var Constraints: [Constraint] = []
    public var Indexes: [Index] = []
    public var Triggers: [Trigger] = []
    public var Ignore: Bool = false
}

public class Column: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var ColumnName: String = ""
    public var ColumnType: String = ""
    public var CharacterLength: String = ""
    public var NumericPrecision: String = ""
    public var NumericScale: String = ""
    public var IsNotNull: Bool = false
    public var IsPrimaryKey: Bool = false
    public var IsAutoincrement: Bool = false
    public var ReferencesSchema: String = ""
    public var ReferencesTable: String = ""
    public var ReferencesColumn: String = ""
    public var UpdateRule: String = ""
    public var DeleteRule: String = ""
    public var IsGenerated: Bool = false
    public var GeneratedExpr: String = ""
    public var GeneratedExprStored: Bool = false
    public var ColumnDefault: String = ""
    public var Ignore: Bool = false
}

public class Constraint: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var ConstraintName: String = ""
    public var ConstraintType: String = ""
    public var Columns: [String] = []
    public var ReferencesSchema: String = ""
    public var ReferencesTable: String = ""
    public var ReferencesColumns: [String] = []
    public var UpdateRule: String = ""
    public var DeleteRule: String = ""
    public var Ignore: Bool = false
}

public class Index: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var IndexName: String = ""
    public var IsUnique: Bool = false
    public var Columns: [String] = []
    public var SQL: String = ""
    public var Ignore: Bool = false
}

public class Trigger: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var TriggerName: String = ""
    public var SQL = ""
    public var Ignore: Bool = false
}

public struct CatalogCache {
    struct Pair<T: Hashable, U: Hashable>: Hashable {
        let first: T
        let second: U
        init(_ first: T, _ second: U) {
            self.first = first
            self.second = second
        }
    }

    struct Triple<T: Hashable, U: Hashable, V: Hashable>: Hashable {
        let first: T
        let second: U
        let third: V
        init(_ first: T, _ second: U, _ third: V) {
            self.first = first
            self.second = second
            self.third = third
        }
    }

    var schemaIndices: [String: Int] = [:]
    var viewIndices: [Pair<String, String>: Int] = [:]
    var tableIndices: [Pair<String, String>: Int] = [:]
    var columnIndices: [Triple<String, String, String>: Int] = [:]
    var constraintIndices: [Triple<String, String, String>: Int] = [:]
    var indexIndices: [Triple<String, String, String>: Int] = [:]
    var triggerIndices: [Triple<String, String, String>: Int] = [:]
    var primaryKeyIndices: [Pair<String, String>: Int] = [:]
    var foreignKeyIndices: [Pair<String, String>: [Int]] = [:]

    public init(from catalog: Catalog) {
        for (i, schema) in catalog.Schemas.enumerated() {
            self.schemaIndices[schema.SchemaName] = i
            for (j, view) in schema.Views.enumerated() {
                let viewID = Pair(schema.SchemaName, view.ViewName)
                self.viewIndices[viewID] = j
            }
            for (j, table) in schema.Tables.enumerated() {
                let tableID = Pair(schema.SchemaName, table.TableName)
                self.tableIndices[tableID] = j
                for (k, column) in table.Columns.enumerated() {
                    let columnID = Triple(
                        schema.SchemaName,
                        table.TableName,
                        column.ColumnName
                    )
                    self.columnIndices[columnID] = k
                }
                for (k, constraint) in table.Constraints.enumerated() {
                    let constraintID = Triple(
                        schema.SchemaName,
                        table.TableName,
                        constraint.ConstraintName
                    )
                    let tableID = Pair(schema.SchemaName, table.TableName)
                    switch constraint.ConstraintType {
                    case PRIMARY_KEY:
                        primaryKeyIndices[tableID] = k
                    case FOREIGN_KEY:
                        foreignKeyIndices[tableID, default: []].append(k)
                    default:
                        break
                    }
                    if constraint.ConstraintName.isEmpty {  // SQLite constraints have no names.
                        continue
                    }
                    self.constraintIndices[constraintID] = k
                }
                for (k, index) in table.Indexes.enumerated() {
                    let indexID = Triple(
                        schema.SchemaName,
                        table.TableName,
                        index.IndexName
                    )
                    self.indexIndices[indexID] = k
                }
                for (k, trigger) in table.Triggers.enumerated() {
                    let triggerID = Triple(
                        schema.SchemaName,
                        table.TableName,
                        trigger.TriggerName
                    )
                    self.triggerIndices[triggerID] = k
                }
            }
        }
    }

    public func getSchema(catalog: Catalog?, schemaName: String) -> Schema? {
        guard let catalog = catalog else {
            return nil
        }
        if let i = schemaIndices[schemaName], !catalog.Schemas[i].Ignore {
            return catalog.Schemas[i]
        }
        return nil
    }

    public mutating func getOrCreateSchema(catalog: Catalog, schemaName: String)
        -> Schema
    {
        if let i = schemaIndices[schemaName], !catalog.Schemas[i].Ignore {
            return catalog.Schemas[i]
        }
        let schema = Schema()
        schema.SchemaName = schemaName
        catalog.Schemas.append(schema)
        let i = catalog.Schemas.count - 1
        schemaIndices[schemaName] = i
        return catalog.Schemas[i]
    }

    public mutating func addOrUpdateSchema(catalog: Catalog, schema: Schema) {
        if let i = schemaIndices[schema.SchemaName], !catalog.Schemas[i].Ignore
        {
            catalog.Schemas[i] = schema
            return
        }
        catalog.Schemas.append(schema)
        let i = catalog.Schemas.count - 1
        schemaIndices[schema.SchemaName] = i
    }

    public func getView(schema: Schema?, viewName: String) -> View? {
        guard let schema = schema else {
            return nil
        }
        let viewID = Pair(schema.SchemaName, viewName)
        if let i = viewIndices[viewID], !schema.Views[i].Ignore {
            return schema.Views[i]
        }
        return nil
    }

    public mutating func getOrCreateView(schema: Schema, viewName: String) -> View {
        let viewID = Pair(schema.SchemaName, viewName)
        if let i = viewIndices[viewID], !schema.Views[i].Ignore {
            return schema.Views[i]
        }
        let view = View()
        view.ViewSchema = schema.SchemaName
        view.ViewName = viewName
        schema.Views.append(view)
        let i = schema.Views.count - 1
        viewIndices[viewID] = i
        return schema.Views[i]
    }

    public mutating func addOrUpdateView(schema: Schema, view: View) {
        let viewID = Pair(schema.SchemaName, view.ViewName)
        if let i = viewIndices[viewID], !schema.Views[i].Ignore {
            schema.Views[i] = view
            return
        }
        schema.Views.append(view)
        let i = schema.Views.count - 1
        viewIndices[viewID] = i
    }

    public func getTable(schema: Schema?, tableName: String) -> Table? {
        guard let schema = schema else {
            return nil
        }
        let tableID = Pair(schema.SchemaName, tableName)
        if let i = tableIndices[tableID], !schema.Tables[i].Ignore {
            return schema.Tables[i]
        }
        return nil
    }

    public mutating func getOrCreateTable(schema: Schema, tableName: String) -> Table {
        let tableID = Pair(schema.SchemaName, tableName)
        if let i = tableIndices[tableID], !schema.Tables[i].Ignore {
            return schema.Tables[i]
        }
        let table = Table()
        table.TableSchema = schema.SchemaName
        table.TableName = tableName
        schema.Tables.append(table)
        let i = schema.Tables.count - 1
        tableIndices[tableID] = i
        return schema.Tables[i]
    }

    public mutating func addOrUpdateTable(schema: Schema, table: Table) {
        let tableID = Pair(schema.SchemaName, table.TableName)
        if let i = tableIndices[tableID], !schema.Tables[i].Ignore {
            schema.Tables[i] = table
            return
        }
        schema.Tables.append(table)
        let i = schema.Tables.count - 1
        tableIndices[tableID] = i
    }

    public func getColumn(table: Table?, columnName: String) -> Column? {
        guard let table = table else {
            return nil
        }
        let columnID = Triple(table.TableSchema, table.TableName, columnName)
        if let i = columnIndices[columnID], !table.Columns[i].Ignore {
            return table.Columns[i]
        }
        return nil
    }

    public mutating func getOrCreateColumn(table: Table, columnName: String) -> Column
    {
        let columnID = Triple(table.TableSchema, table.TableName, columnName)
        if let i = columnIndices[columnID], !table.Columns[i].Ignore {
            return table.Columns[i]
        }
        let column = Column()
        column.TableSchema = table.TableSchema
        column.TableName = table.TableName
        column.ColumnName = columnName
        table.Columns.append(column)
        let i = table.Columns.count - 1
        columnIndices[columnID] = i
        return table.Columns[i]
    }

    public mutating func addOrUpdateColumn(table: Table, column: Column) {
        let columnID = Triple(
            table.TableSchema,
            table.TableName,
            column.ColumnName
        )
        if let i = columnIndices[columnID], !table.Columns[i].Ignore {
            table.Columns[i] = column
            return
        }
        table.Columns.append(column)
        let i = table.Columns.count - 1
        columnIndices[columnID] = i
    }

    public func getConstraint(table: Table?, constraintName: String) -> Constraint? {
        guard let table = table else {
            return nil
        }
        let constraintID = Triple(
            table.TableSchema,
            table.TableName,
            constraintName
        )
        if let i = constraintIndices[constraintID], !table.Constraints[i].Ignore
        {
            return table.Constraints[i]
        }
        return nil
    }

    public mutating func getOrCreateConstraint(table: Table, constraintName: String)
        -> Constraint
    {
        let constraintID = Triple(
            table.TableSchema,
            table.TableName,
            constraintName
        )
        if let i = constraintIndices[constraintID], !table.Constraints[i].Ignore
        {
            return table.Constraints[i]
        }
        let constraint = Constraint()
        constraint.TableSchema = table.TableSchema
        constraint.TableName = table.TableName
        constraint.ConstraintName = constraintName
        table.Constraints.append(constraint)
        let i = table.Constraints.count - 1
        constraintIndices[constraintID] = i
        return table.Constraints[i]
    }

    public mutating func addOrUpdateConstraint(table: Table, constraint: Constraint) {
        let constraintID = Triple(
            table.TableSchema,
            table.TableName,
            constraint.ConstraintName
        )
        if let i = constraintIndices[constraintID], !table.Constraints[i].Ignore
        {
            table.Constraints[i] = constraint
            return
        }
        table.Constraints.append(constraint)
        let i = table.Constraints.count - 1
        let tableID = Pair(table.TableSchema, table.TableName)
        switch constraint.ConstraintType {
        case PRIMARY_KEY:
            primaryKeyIndices[tableID] = i
        case FOREIGN_KEY:
            foreignKeyIndices[tableID, default: []].append(i)
        default:
            break
        }
        if !constraint.ConstraintName.isEmpty {  // SQLite constraints have no name.
            constraintIndices[constraintID] = i
        }
    }

    public func getIndex(table: Table?, indexName: String) -> Index? {
        guard let table = table else {
            return nil
        }
        let indexID = Triple(table.TableSchema, table.TableName, indexName)
        if let i = indexIndices[indexID], !table.Indexes[i].Ignore {
            return table.Indexes[i]
        }
        return nil
    }

    public mutating func getOrCreateIndex(table: Table, indexName: String) -> Index {
        let indexID = Triple(table.TableSchema, table.TableName, indexName)
        if let i = indexIndices[indexID], !table.Indexes[i].Ignore {
            return table.Indexes[i]
        }
        let index = Index()
        index.TableSchema = table.TableSchema
        index.TableName = table.TableName
        index.IndexName = indexName
        table.Indexes.append(index)
        let i = table.Indexes.count - 1
        indexIndices[indexID] = i
        return table.Indexes[i]
    }

    public mutating func addOrUpdateIndex(table: Table, index: Index) {
        let indexID = Triple(
            table.TableSchema,
            table.TableName,
            index.IndexName
        )
        if let i = indexIndices[indexID], !table.Indexes[i].Ignore {
            table.Indexes[i] = index
            return
        }
        table.Indexes.append(index)
        let i = table.Indexes.count - 1
        indexIndices[indexID] = i
    }

    public func getTrigger(table: Table?, triggerName: String) -> Trigger? {
        guard let table = table else {
            return nil
        }
        let triggerID = Triple(table.TableSchema, table.TableName, triggerName)
        if let i = triggerIndices[triggerID], !table.Triggers[i].Ignore {
            return table.Triggers[i]
        }
        return nil
    }

    public mutating func getOrCreateTrigger(table: Table, triggerName: String)
        -> Trigger
    {
        let triggerID = Triple(table.TableSchema, table.TableName, triggerName)
        if let i = triggerIndices[triggerID], !table.Triggers[i].Ignore {
            return table.Triggers[i]
        }
        let trigger = Trigger()
        trigger.TableSchema = table.TableSchema
        trigger.TableName = table.TableName
        trigger.TriggerName = triggerName
        table.Triggers.append(trigger)
        let i = table.Triggers.count - 1
        triggerIndices[triggerID] = i
        return table.Triggers[i]
    }

    public mutating func addOrUpdateTrigger(table: Table, trigger: Trigger) {
        let triggerID = Triple(
            table.TableSchema,
            table.TableName,
            trigger.TriggerName
        )
        if let i = triggerIndices[triggerID], !table.Triggers[i].Ignore {
            table.Triggers[i] = trigger
            return
        }
        table.Triggers.append(trigger)
        let i = table.Triggers.count - 1
        triggerIndices[triggerID] = i
    }

    public func getPrimaryKey(table: Table?) -> Constraint? {
        guard let table = table else {
            return nil
        }
        let tableID = Pair(table.TableSchema, table.TableName)
        if let i = primaryKeyIndices[tableID] {
            return table.Constraints[i]
        }
        return nil
    }

    public func getForeignKeys(table: Table?) -> [Constraint] {
        guard let table = table else {
            return []
        }
        let tableID = Pair(table.TableSchema, table.TableName)
        guard let indices = foreignKeyIndices[tableID] else {
            return []
        }
        var foreignKeys: [Constraint] = []
        for i in indices {
            let foreignKey = table.Constraints[i]
            if foreignKey.Ignore {
                continue
            }
            foreignKeys.append(foreignKey)
        }
        return foreignKeys
    }
}

public struct Filter {
    public var version: String = ""
    public var versionNums: [Int] = []
    public var includeSystemCatalogs: Bool = false
    public var constraintTypes: Set<String> = Set()
    public var objectTypes: Set<String> = Set()
    public var tables: [String] = []
    public var schemas: [String] = []
    public var excludeSchemas: [String] = []
    public var excludeTables: [String] = []
    public var views: [String] = []
    public var excludeViews: [String] = []
}

public struct DatabaseIntrospector {
    public var database: Database
    public var filter: Filter = Filter()

    public func writeCatalog(_ catalog: Catalog) throws {
        var _ = CatalogCache(from: catalog)
    }

    func mklist(_ strs: [String]) -> String {
        var result = ""
        var written = false
        for str in strs {
            if str.isEmpty {
                continue
            }
            if !written {
                written = true
            } else {
                result += ", "
            }
            result += "'" + str.replacingOccurrences(of: "'", with: "''") + "'"
        }
        return result
    }

    public mutating func getVersion() throws -> String {
        let version = try database.fetchOne(sql: "SELECT {*}") { row in
            return try row.string("sqlite_version()")
        }
        return version ?? ""
    }

    public mutating func getVersionNums() throws -> [Int] {
        let version = try getVersion()
        let strs = version.split(separator: ".")
        var versionNums: [Int] = []
        versionNums.reserveCapacity(strs.count)
        for str in strs {
            versionNums.append(Int(str) ?? -1)
        }
        return versionNums
    }

    public mutating func getColumns() throws -> [Column] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            return .expression(
                "tbl_name NOT LIKE 'sqlite_%' AND sql NOT LIKE 'CREATE TABLE ''%'"
            )
        }()
        let tableFilter: Value = {
            if !filter.tables.isEmpty {
                return .expression(
                    "tbl_name IN (\(mklist(filter.tables))"
                )
            }
            if !filter.excludeTables.isEmpty {
                return .expression(
                    "tbl_name NOT IN (\(mklist(filter.excludeTables))"
                )
            }
            return .expression("1 = 1")
        }()
        return try database.fetchAll(
            sql: """
                SELECT {*}
                FROM (
                    SELECT tbl_name
                    FROM sqlite_schema
                    WHERE type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                ) AS tables
                CROSS JOIN pragma_table_xinfo(tables.tbl_name) AS columns
                ORDER BY tables.tbl_name, columns.cid
                """,
            values: [
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            ]
        ) { row in
            let column = Column()
            column.TableName = try row.string("tables.tbl_name AS table_name")
            column.ColumnName = try row.string("columns.name AS column_name")
            column.ColumnType = try row.string("columns.type AS column_type")
            column.IsNotNull = try row.bool("columns.\"notnull\" AS is_notnull")
            column.IsGenerated = try row.bool(
                "columns.hidden = 2 AS is_generated"
            )
            column.ColumnDefault = try row.string(
                "COALESCE(columns.dflt_value, '') AS column_default"
            )
            let suffix = " GENERATED ALWAYS"
            if column.ColumnType.hasSuffix(suffix) {
                column.ColumnType = String(
                    column.ColumnType.prefix(
                        column.ColumnType.count - suffix.count
                    )
                )
                if !column.IsGenerated {
                    column.IsGenerated = true
                }
            }
            if !column.ColumnDefault.isEmpty {
                if !isLiteral(s: column.ColumnDefault) {
                    column.ColumnDefault = wrapBrackets(s: column.ColumnDefault)
                }
            }
            return column
        }
    }

    public mutating func getConstraints() throws -> [Constraint] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            return .expression(
                "tbl_name NOT LIKE 'sqlite_%' AND sql NOT LIKE 'CREATE TABLE ''%'"
            )
        }()
        let tableFilter: Value = {
            if !filter.tables.isEmpty {
                return .expression(
                    "tbl_name IN (\(mklist(filter.tables))"
                )
            }
            if !filter.excludeTables.isEmpty {
                return .expression(
                    "tbl_name NOT IN (\(mklist(filter.excludeTables))"
                )
            }
            return .expression("1 = 1")
        }()
        let unionPrimaryKey: Value = {
            if !filter.constraintTypes.isEmpty
                && !filter.constraintTypes.contains("PRIMARY KEY")
            {
                return .expression("")
            }
            return .expression(
                """
                UNION ALL
                SELECT
                table_name
                ,'PRIMARY KEY' AS constraint_type
                ,COALESCE(group_concat(column_name), 'ROWID') AS columns
                ,'' AS references_table
                ,'' AS references_columns
                ,'' AS update_rule
                ,'' AS delete_rule
                FROM (
                    SELECT tables.tbl_name AS table_name, columns.name AS column_name
                    FROM (
                        SELECT tbl_name
                        FROM sqlite_schema
                        WHERE type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                    ) AS tables
                    CROSS JOIN pragma_table_info(tables.tbl_name) AS columns
                    WHERE columns.pk > 0 /* exclude non-primarykey columns */
                    ORDER BY tables.tbl_name, columns.pk
                ) AS primary_key_columns
                GROUP BY table_name
                """,
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            )
        }()
        let unionUnique: Value = {
            if !filter.constraintTypes.isEmpty
                && !filter.constraintTypes.contains("UNIQUE")
            {
                return .expression("")
            }
            return .expression(
                """
                UNION ALL
                SELECT
                table_name
                ,'UNIQUE' AS constraint_type
                ,COALESCE(group_concat(column_name), '') AS columns
                ,'' AS references_table
                ,'' AS references_columns
                ,'' AS update_rule
                ,'' AS delete_rule
                FROM (
                    SELECT tables.tbl_name AS table_name, indexes.name AS index_name, columns.name AS column_name
                    FROM (
                        SELECT tbl_name
                        FROM sqlite_schema
                        WHERE type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                    ) AS tables
                    CROSS JOIN pragma_index_list(tables.tbl_name) AS indexes
                    CROSS JOIN pragma_index_info(indexes.name) AS columns
                    WHERE indexes."unique" AND indexes.origin = 'u'
                    ORDER BY columns.seqno
                    ) AS unique_columns
                GROUP BY table_name, index_name
                """,
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            )
        }()
        let unionForeignKey: Value = {
            if !filter.constraintTypes.isEmpty
                && !filter.constraintTypes.contains("FOREIGN KEY")
            {
                return .expression("")
            }
            return .expression(
                """
                UNION ALL
                SELECT
                table_name
                ,'FOREIGN KEY' AS constraint_type
                ,COALESCE(group_concat(column_name), '') AS columns
                ,references_table
                ,COALESCE(group_concat(references_column), '') AS references_columns
                ,update_rule
                ,delete_rule
                FROM (
                    SELECT
                    tables.tbl_name AS table_name
                    ,columns.id AS foreign_key_id
                    ,columns."from" AS column_name
                    ,columns."table" AS references_table
                    ,columns."to" AS references_column
                    ,columns.on_update AS update_rule
                    ,columns.on_delete AS delete_rule
                    FROM (
                        SELECT tbl_name
                        FROM sqlite_schema
                        WHERE type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                    ) AS tables
                    CROSS JOIN pragma_foreign_key_list(tables.tbl_name) AS columns
                    ORDER BY columns.seq
                ) AS foreign_key_columns
                GROUP BY table_name, foreign_key_id, references_table, update_rule, delete_rule
                """,
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            )
        }()
        return try database.fetchAll(
            sql: """
                SELECT {*} FROM (
                SELECT
                '' AS table_name
                ,'' AS constraint_type
                ,'' AS columns
                ,'' AS references_table
                ,'' AS references_columns
                ,'' AS update_rule
                ,'' AS delete_rule
                WHERE 1 <> 1
                {unionPrimaryKey}
                {unionUnique}
                {unionForeignKey}                
                ) ORDER BY table_name, columns, constraint_type
                """,
            values: [
                .parameter("unionPrimaryKey", unionPrimaryKey),
                .parameter("unionUnique", unionUnique),
                .parameter("unionForeignKey", unionForeignKey),
            ]
        ) { row in
            let constraint = Constraint()
            constraint.TableName = try row.string("table_name")
            constraint.ConstraintType = try row.string("constraint_type")
            let columns = try row.string("columns")
            constraint.ReferencesTable = try row.string("references_table")
            let referencesColumns = try row.string("references_columns")
            constraint.UpdateRule = try row.string("update_rule")
            constraint.DeleteRule = try row.string("delete_rule")
            if !columns.isEmpty {
                constraint.Columns = columns.components(separatedBy: ",")
            }
            if !referencesColumns.isEmpty {
                constraint.ReferencesColumns = referencesColumns.components(
                    separatedBy: ","
                )
            }
            return constraint
        }
    }

    public mutating func getIndexes() throws -> [Index] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            return .expression(
                "tbl_name NOT LIKE 'sqlite_%' AND sql NOT LIKE 'CREATE TABLE ''%'"
            )
        }()
        let tableFilter: Value = {
            if !filter.tables.isEmpty {
                return .expression(
                    "tbl_name IN (\(mklist(filter.tables))"
                )
            }
            if !filter.excludeTables.isEmpty {
                return .expression(
                    "tbl_name NOT IN (\(mklist(filter.excludeTables))"
                )
            }
            return .expression("1 = 1")
        }()
        return try database.fetchAll(
            sql: """
                SELECT {*}
                FROM (
                    SELECT
                    tables.tbl_name AS table_name
                    ,indexes.name AS index_name
                    ,indexes."unique" AS is_unique
                    ,CASE columns.cid WHEN -1 THEN '' /* rowid */ WHEN -2 THEN '' /* expression */ ELSE columns.name END AS column_name
                    ,columns.seqno
                    ,m.sql
                    FROM (
                        SELECT tbl_name
                        FROM sqlite_schema
                        WHERE type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                    ) AS tables
                    CROSS JOIN pragma_index_list(tables.tbl_name) AS indexes
                    CROSS JOIN pragma_index_info(indexes.name) AS columns
                    JOIN sqlite_schema AS m ON m.type = 'index' AND m.tbl_name = tables.tbl_name AND m.name = indexes.name
                    WHERE indexes.origin = 'c' /* 'c' = 'CREATE INDEX', 'u' = 'UNIQUE', 'pk' = 'PRIMARY KEY' */
                    ORDER BY indexes.name, columns.seqno
                ) AS index_columns
                GROUP BY table_name, index_name, is_unique, sql
                ORDER BY table_name, index_name
                """,
            values: [
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            ]
        ) { row in
            let index = Index()
            index.TableName = try row.string("table_name")
            index.IndexName = try row.string("index_name")
            index.IsUnique = try row.bool("is_unique")
            let columns = try row.string("group_concat(column_name) AS columns")
            index.SQL = try row.string("sql || ';' AS sql")
            if !columns.isEmpty {
                index.Columns = columns.components(separatedBy: ",")
            }
            return index
        }
    }

    public mutating func getTables() throws -> [Table] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            if compareVersionNums(lhs: filter.versionNums, rhs: [3, 37]) < 0 {
                return .expression(
                    "m.tbl_name NOT LIKE 'sqlite_%' AND m.sql NOT LIKE 'CREATE TABLE ''%'"
                )
            }
            return .expression(
                """
                m.tbl_name NOT LIKE 'sqlite_%' AND EXISTS (
                    SELECT 1
                    FROM pragma_table_list AS tl
                    WHERE tl."type" IN ('table', 'virtual') AND tl.schema = 'main' AND tl.name = m.tbl_name
                )
                """
            )
        }()
        let tableFilter: Value = {
            if !filter.tables.isEmpty {
                return .expression(
                    "m.tbl_name IN (\(mklist(filter.tables))"
                )
            }
            if !filter.excludeTables.isEmpty {
                return .expression(
                    "m.tbl_name NOT IN (\(mklist(filter.excludeTables))"
                )
            }
            return .expression("1 = 1")
        }()
        return try database.fetchAll(
            sql: """
                SELECT {*}
                FROM sqlite_schema AS m
                WHERE m.type = 'table' AND {systemCatalogFilter} AND {tableFilter}
                ORDER BY m.tbl_name
                """,
            values: [
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            ]
        ) { row in
            let table = Table()
            table.TableName = try row.string("m.tbl_name AS table_name")
            let sql = try row.string("m.sql || ';' AS sql")
            table.SQL = sql.replacingOccurrences(of: "\r\n", with: "\n")
            return table
        }
    }

    public mutating func getTriggers() throws -> [Trigger] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            return .expression(
                "tbl_name NOT LIKE 'sqlite_%' AND sql NOT LIKE 'CREATE TABLE ''%'"
            )
        }()
        let tableFilter: Value = {
            if !filter.tables.isEmpty {
                return .expression(
                    "tbl_name IN (\(mklist(filter.tables))"
                )
            }
            if !filter.excludeTables.isEmpty {
                return .expression(
                    "tbl_name NOT IN (\(mklist(filter.excludeTables))"
                )
            }
            return .expression("1 = 1")
        }()
        return try database.fetchAll(
            sql: """
                SELECT {*}
                FROM sqlite_schema
                WHERE type = 'trigger' AND {systemCatalogFilter} AND {tableFilter}
                ORDER BY tbl_name, name
                """,
            values: [
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            ]
        ) { row in
            let trigger = Trigger()
            trigger.TableName = try row.string("tbl_name AS table_name")
            trigger.TriggerName = try row.string("name AS trigger_name")
            let sql = try row.string("sql || ';' AS sql")
            trigger.SQL = sql.replacingOccurrences(of: "\r\n", with: "\n")
            return trigger
        }
    }

    public mutating func getViews() throws -> [View] {
        let systemCatalogFilter: Value = {
            if filter.includeSystemCatalogs {
                return .expression("1 = 1")
            }
            return .expression(
                "tbl_name NOT LIKE 'sqlite_%' AND sql NOT LIKE 'CREATE TABLE ''%'"
            )
        }()
        let tableFilter: Value = {
            if !filter.views.isEmpty {
                return .expression(
                    "tbl_name IN (\(mklist(filter.views))"
                )
            }
            if !filter.excludeViews.isEmpty {
                return .expression(
                    "tbl_name NOT IN (\(mklist(filter.excludeViews))"
                )
            }
            return .expression("1 = 1")
        }()
        return try database.fetchAll(
            sql: """
                SELECT
                    views.tbl_name AS view_name
                    ,views.sql || ';' AS sql
                    ,group_concat(columns.name, '|') AS column_names
                    ,group_concat(columns.type, '|') AS column_types
                FROM (
                    SELECT tbl_name, sql
                    FROM sqlite_schema
                    WHERE type = 'view' AND {systemCatalogFilter} AND {tableFilter}
                ) AS views
                CROSS JOIN pragma_table_xinfo(views.tbl_name) AS columns
                GROUP BY views.tbl_name, views.sql
                ORDER BY views.tbl_name
                """,
            values: [
                .parameter("systemCatalogFilter", systemCatalogFilter),
                .parameter("tableFilter", tableFilter),
            ]
        ) { row in
            let view = View()
            view.ViewName = try row.string("views.tbl_name AS view_name")
            let sql = try row.string("views.sql || ';' AS sql")
            view.SQL = sql.replacingOccurrences(of: "\r\n", with: "\n")
            let columnNames = try row.string(
                "group_concat(columns.name, '|') AS column_names"
            )
            if !columnNames.isEmpty {
                view.Columns = columnNames.components(separatedBy: "|")
            }
            let columnTypes = try row.string(
                "group_concat(columns.name, '|') AS column_names"
            )
            if !columnTypes.isEmpty {
                view.ColumnTypes = columnTypes.components(separatedBy: "|")
            }
            return view
        }
    }
}

func generateName(nameType: String, tableName: String, columnNames: [String])
    -> String
{
    var name = ""
    for character in tableName {
        if character == " " {
            name += "_"
        } else {
            name += String(character)
        }
    }
    for columnName in columnNames {
        name += "_"
        for character in columnName {
            if character == " " {
                name += "_"
            } else {
                name += String(character)
            }
        }
    }
    switch nameType {
    case PRIMARY_KEY:
        return name + "_pkey"
    case FOREIGN_KEY:
        return name + "_fkey"
    case UNIQUE:
        return name + "_unique"
    case CHECK:
        return name + "_check"
    default:
        return name
    }
}

func isLiteral(s: String) -> Bool {
    // Is string literal?
    if s.count >= 2 && s.first == "'" && s.last == "'" {
        return true
    }
    // Is known literal?
    if s.caseInsensitiveCompare("TRUE") == .orderedSame
        || s.caseInsensitiveCompare("FALSE") == .orderedSame
        || s.caseInsensitiveCompare("CURRENT_DATE") == .orderedSame
        || s.caseInsensitiveCompare("CURRENT_TIME") == .orderedSame
        || s.caseInsensitiveCompare("CURRENT_TIMESTAMP") == .orderedSame
        || s.caseInsensitiveCompare("NULL") == .orderedSame
    {
        return true
    }
    // If int literal?
    if Int(s) != nil {
        return true
    }
    // Is float literal?
    if Double(s) != nil {
        return true
    }
    return false
}

func wrapBrackets(s: String) -> String {
    if s.isEmpty {
        return s
    }
    if s.first == "(" && s.last == ")" {
        return s
    }
    return "(" + s + ")"
}

func compareVersionNums(lhs: [Int], rhs: [Int]) -> Int {
    if lhs == rhs {
        return 0
    }
    for (i, lhsNum) in lhs.enumerated() {
        if rhs.count <= i || lhsNum > rhs[i] {
            return 1
        }
        if lhsNum < rhs[i] {
            return -1
        }
    }
    return 1
}
