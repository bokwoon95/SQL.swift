import Foundation

public struct Filter {
    public var version: String = ""
    public var versionNums: [Int] = []
    public var includeSystemCatalogs: Bool = false
    public var constraintTypes: Set<String> = Set()
    public var objectTypes: Set<String> = Set()  // VIEWS, TABLES
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

    public mutating func writeCatalog(catalog: Catalog) throws {
        var cache = CatalogCache(from: catalog)
        catalog.versionNums = try getVersionNums()
        filter.versionNums = catalog.versionNums
        if filter.objectTypes.isEmpty || filter.objectTypes.contains("VIEWS") {
            let views = try getViews()
            for view in views {
                let schema = cache.getOrCreateSchema(
                    catalog: catalog,
                    schemaName: view.viewSchema
                )
                schema.viewsValid = true
                cache.addOrUpdateView(schema: schema, view: view)
            }
        }
        if filter.objectTypes.isEmpty || filter.objectTypes.contains("TABLES") {
            let tables = try getTables()
            for table in tables {
                let schema = cache.getOrCreateSchema(
                    catalog: catalog,
                    schemaName: table.tableSchema
                )
                cache.addOrUpdateTable(schema: schema, table: table)
            }
            let columns = try getColumns()
            for column in columns {
                guard
                    let schema = cache.getSchema(
                        catalog: catalog,
                        schemaName: column.tableSchema
                    )
                else {
                    continue
                }
                guard
                    let table = cache.getTable(
                        schema: schema,
                        tableName: column.tableName
                    )
                else {
                    continue
                }
                cache.addOrUpdateColumn(table: table, column: column)
            }
            let constraints = try getConstraints()
            for constraint in constraints {
                guard
                    let schema = cache.getSchema(
                        catalog: catalog,
                        schemaName: constraint.tableSchema
                    )
                else {
                    continue
                }
                guard
                    let table = cache.getTable(
                        schema: schema,
                        tableName: constraint.tableName
                    )
                else {
                    continue
                }
                cache.addOrUpdateConstraint(
                    table: table,
                    constraint: constraint
                )
            }
            let indexes = try getIndexes()
            for index in indexes {
                guard
                    let schema = cache.getSchema(
                        catalog: catalog,
                        schemaName: index.tableSchema
                    )
                else {
                    continue
                }
                guard
                    let table = cache.getTable(
                        schema: schema,
                        tableName: index.tableName
                    )
                else {
                    continue
                }
                cache.addOrUpdateIndex(table: table, index: index)
            }
            let triggers = try getTriggers()
            for trigger in triggers {
                guard
                    let schema = cache.getSchema(
                        catalog: catalog,
                        schemaName: trigger.tableSchema
                    )
                else {
                    continue
                }
                guard
                    let table = cache.getTable(
                        schema: schema,
                        tableName: trigger.tableName
                    )
                else {
                    continue
                }
                cache.addOrUpdateTrigger(table: table, trigger: trigger)
            }
            // Set IsPrimaryKey and IsUnique fields for each primary key or unique column.
            for schema in catalog.schemas {
                for table in schema.tables {
                    for constraint in table.constraints {
                        if constraint.columns.count != 1 {
                            continue
                        }
                        guard
                            let column = cache.getColumn(
                                table: table,
                                columnName: constraint.columns[0]
                            )
                        else {
                            continue
                        }
                        switch constraint.constraintType {
                        case PRIMARY_KEY:
                            column.isPrimaryKey = true
                        case UNIQUE:
                            column.isUnique = true
                        case FOREIGN_KEY:
                            column.referencesSchema =
                                constraint.referencesSchema
                            column.referencesTable = constraint.referencesTable
                            column.referencesColumn =
                                constraint.referencesColumns[0]
                            column.updateRule = constraint.updateRule
                            column.deleteRule = constraint.deleteRule
                        default:
                            break
                        }
                    }
                }
            }
        }

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
            column.tableName = try row.string("tables.tbl_name AS table_name")
            column.columnName = try row.string("columns.name AS column_name")
            column.columnType = try row.string("columns.type AS column_type")
            column.isNotNull = try row.bool("columns.\"notnull\" AS is_notnull")
            column.isGenerated = try row.bool(
                "columns.hidden = 2 AS is_generated"
            )
            column.columnDefault = try row.string(
                "COALESCE(columns.dflt_value, '') AS column_default"
            )
            let suffix = " GENERATED ALWAYS"
            if column.columnType.hasSuffix(suffix) {
                column.columnType = String(
                    column.columnType.prefix(
                        column.columnType.count - suffix.count
                    )
                )
                if !column.isGenerated {
                    column.isGenerated = true
                }
            }
            if !column.columnDefault.isEmpty {
                if !isLiteral(column.columnDefault) {
                    column.columnDefault = wrapBrackets(column.columnDefault)
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
            constraint.tableName = try row.string("table_name")
            constraint.constraintType = try row.string("constraint_type")
            let columns = try row.string("columns")
            constraint.referencesTable = try row.string("references_table")
            let referencesColumns = try row.string("references_columns")
            constraint.updateRule = try row.string("update_rule")
            constraint.deleteRule = try row.string("delete_rule")
            if !columns.isEmpty {
                constraint.columns = columns.components(separatedBy: ",")
            }
            if !referencesColumns.isEmpty {
                constraint.referencesColumns = referencesColumns.components(
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
            index.tableName = try row.string("table_name")
            index.indexName = try row.string("index_name")
            index.isUnique = try row.bool("is_unique")
            let columns = try row.string("group_concat(column_name) AS columns")
            index.sql = try row.string("sql || ';' AS sql")
            if !columns.isEmpty {
                index.columns = columns.components(separatedBy: ",")
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
            table.tableName = try row.string("m.tbl_name AS table_name")
            let sql = try row.string("m.sql || ';' AS sql")
            table.sql = sql.replacingOccurrences(of: "\r\n", with: "\n")
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
            trigger.tableName = try row.string("tbl_name AS table_name")
            trigger.triggerName = try row.string("name AS trigger_name")
            let sql = try row.string("sql || ';' AS sql")
            trigger.sql = sql.replacingOccurrences(of: "\r\n", with: "\n")
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
                SELECT {*}
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
            view.viewName = try row.string("views.tbl_name AS view_name")
            let sql = try row.string("views.sql || ';' AS sql")
            view.sql = sql.replacingOccurrences(of: "\r\n", with: "\n")
            let columnNames = try row.string(
                "group_concat(columns.name, '|') AS column_names"
            )
            if !columnNames.isEmpty {
                view.columns = columnNames.components(separatedBy: "|")
            }
            let columnTypes = try row.string(
                "group_concat(columns.name, '|') AS column_names"
            )
            if !columnTypes.isEmpty {
                view.columnTypes = columnTypes.components(separatedBy: "|")
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
        return name + "_key"
    case INDEX:
        return name + "_idx"
    case CHECK:
        return name + "_check"
    default:
        return name
    }
}

func isLiteral(_ s: String) -> Bool {
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

func wrapBrackets(_ s: String) -> String {
    if s.isEmpty {
        return s
    }
    if s.first == "(" && s.last == ")" {
        return s
    }
    return "(" + s + ")"
}

func unwrapBrackets(_ s: String) -> String {
    if s.isEmpty {
        return s
    }
    if s.first == "(" && s.last == ")" {
        return String(s.dropFirst().dropLast())
    }
    return s
}

func wrappedInBrackets(_ s: String) -> Bool {
    return !s.isEmpty && s.first == "(" && s.last == ")"
}

func normalizeColumnType(columnType: String) -> (
    normalizedType: String, arg1: String, arg2: String
) {
    let columnType = columnType.trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()
    var normalizedType = columnType
    var arg1 = ""
    var arg2 = ""
    var args = ""
    var suffix = ""
    if let i = columnType.firstIndex(of: "("),
        let j = columnType.lastIndex(of: ")"), j > i
    {
        normalizedType = String(columnType[..<i]).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        args = columnType[columnType.index(after: i)..<j].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        suffix = columnType[columnType.index(after: j)...].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let k = args.firstIndex(of: ",") {
            arg1 = String(args[..<k]).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            arg2 = String(args[columnType.index(after: k)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            arg1 = args.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    var _ = suffix  // We'll use this if we are Postgres.
    return (normalizedType, arg1, arg2)
}

func normalizeColumnDefault(columnDefault: String) -> String {
    let columnDefault = columnDefault.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
    if columnDefault.isEmpty {
        return ""
    }
    let upperDefault = columnDefault.uppercased()
    switch upperDefault {
    case "1", "TRUE":
        return "'1'"
    case "0", "FALSE":
        return "'0'"
    case "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "NULL":
        return upperDefault
    default:
        break
    }

    // SQLite specific
    if upperDefault == "DATETIME()" || upperDefault == "DATETIME('NOW')" {
        return "CURRENT_TIMESTAMP"
    }

    return columnDefault
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
    return -1
}
