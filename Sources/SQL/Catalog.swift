import Foundation

// DatabaseIntrospector.swift (ddl.go, catalog_cache.go, database_introspector.go), MigrateCmd.swift, GenerateCmd.swift, AutomigrateCmd.swift

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
    public var versionNums: [Int]
    public var catalogName: String
    public var currentSchema: String
    public var schemas: [Schema]

    private enum CodingKeys: String, CodingKey {
        case VersionNums
        case CatalogName
        case CurrentSchema
        case Schemas
    }

    public init(
        versionNums: [Int] = [],
        catalogName: String = "",
        currentSchema: String = "",
        schemas: [Schema] = []
    ) {
        self.versionNums = versionNums
        self.catalogName = catalogName
        self.currentSchema = currentSchema
        self.schemas = schemas
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.versionNums =
            try container.decodeIfPresent([Int].self, forKey: .VersionNums)
            ?? []
        self.catalogName =
            try container.decodeIfPresent(String.self, forKey: .CatalogName)
            ?? ""
        self.currentSchema =
            try container.decodeIfPresent(String.self, forKey: .CurrentSchema)
            ?? ""
        self.schemas =
            try container.decodeIfPresent([Schema].self, forKey: .Schemas)
            ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !versionNums.isEmpty {
            try container.encode(versionNums, forKey: .VersionNums)
        }
        if !catalogName.isEmpty {
            try container.encode(catalogName, forKey: .CatalogName)
        }
        if !currentSchema.isEmpty {
            try container.encode(currentSchema, forKey: .CurrentSchema)
        }
        if !schemas.isEmpty {
            try container.encode(schemas, forKey: .Schemas)
        }
    }
}

public class Schema: Codable {
    public var schemaName: String
    public var tables: [Table]
    public var views: [View]
    public var viewsValid: Bool
    public var ignore: Bool

    private enum CodingKeys: String, CodingKey {
        case SchemaName
        case Tables
        case Views
        case ViewsValid
        case Ignore
    }

    public init(
        schemaName: String = "",
        tables: [Table] = [],
        views: [View] = [],
        viewsValid: Bool = false,
        ignore: Bool = false
    ) {
        self.schemaName = schemaName
        self.tables = tables
        self.views = views
        self.viewsValid = viewsValid
        self.ignore = ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaName =
            try container.decodeIfPresent(String.self, forKey: .SchemaName)
            ?? ""
        self.tables =
            try container.decodeIfPresent([Table].self, forKey: .Tables)
            ?? []
        self.views =
            try container.decodeIfPresent([View].self, forKey: .Views)
            ?? []
        self.viewsValid =
            try container.decodeIfPresent(Bool.self, forKey: .ViewsValid)
            ?? false
        self.ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !schemaName.isEmpty {
            try container.encode(schemaName, forKey: .SchemaName)
        }
        if !tables.isEmpty {
            try container.encode(tables, forKey: .Tables)
        }
        if !views.isEmpty {
            try container.encode(views, forKey: .Views)
        }
        if viewsValid {
            try container.encode(viewsValid, forKey: .ViewsValid)
        }
        if ignore {
            try container.encode(ignore, forKey: .Ignore)
        }
    }
}

public class View: Codable {
    public var viewSchema: String
    public var viewName: String
    public var sql: String
    public var columns: [String]
    public var columnTypes: [String]
    public var ignore: Bool

    private enum CodingKeys: String, CodingKey {
        case ViewSchema
        case ViewName
        case SQL
        case Columns
        case ColumnTypes
        case Ignore
    }

    public init(
        viewSchema: String = "",
        viewName: String = "",
        sql: String = "",
        columns: [String] = [],
        columnTypes: [String] = [],
        ignore: Bool = false
    ) {
        self.viewSchema = viewSchema
        self.viewName = viewName
        self.sql = sql
        self.columns = columns
        self.columnTypes = columnTypes
        self.ignore = ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.viewSchema =
            try container.decodeIfPresent(String.self, forKey: .ViewSchema)
            ?? ""
        self.viewName =
            try container.decodeIfPresent(String.self, forKey: .ViewName)
            ?? ""
        self.sql =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? ""
        self.columns =
            try container.decodeIfPresent([String].self, forKey: .Columns)
            ?? []
        self.columnTypes =
            try container.decodeIfPresent([String].self, forKey: .ColumnTypes)
            ?? []
        self.ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !viewSchema.isEmpty {
            try container.encode(viewSchema, forKey: .ViewSchema)
        }
        if !viewName.isEmpty {
            try container.encode(viewName, forKey: .ViewName)
        }
        if !sql.isEmpty {
            try container.encode(sql, forKey: .SQL)
        }
        if !columns.isEmpty {
            try container.encode(columns, forKey: .Columns)
        }
        if !columnTypes.isEmpty {
            try container.encode(columnTypes, forKey: .ColumnTypes)
        }
        if ignore {
            try container.encode(ignore, forKey: .Ignore)
        }
    }
}

public class Table: Codable {
    public var tableSchema: String
    public var tableName: String
    public var sql: String
    public var isVirtual: Bool
    public var columns: [Column]
    public var constraints: [Constraint]
    public var indexes: [Index]
    public var triggers: [Trigger]
    public var ignore: Bool

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case SQL
        case IsVirtual
        case Columns
        case Constraints
        case Indexes
        case Triggers
        case Ignore
    }

    public init(
        tableSchema: String = "",
        tableName: String = "",
        sql: String = "",
        isVirtual: Bool = false,
        columns: [Column] = [],
        constraints: [Constraint] = [],
        indexes: [Index] = [],
        triggers: [Trigger] = [],
        ignore: Bool = false
    ) {
        self.tableSchema = tableSchema
        self.tableName = tableName
        self.sql = sql
        self.isVirtual = isVirtual
        self.columns = columns
        self.constraints = constraints
        self.indexes = indexes
        self.triggers = triggers
        self.ignore = ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? ""
        self.tableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? ""
        self.sql =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? ""
        self.isVirtual =
            try container.decodeIfPresent(Bool.self, forKey: .IsVirtual)
            ?? false
        self.columns =
            try container.decodeIfPresent([Column].self, forKey: .Columns)
            ?? []
        self.constraints =
            try container.decodeIfPresent(
                [Constraint].self,
                forKey: .Constraints
            ) ?? []
        self.indexes =
            try container.decodeIfPresent([Index].self, forKey: .Indexes)
            ?? []
        self.triggers =
            try container.decodeIfPresent([Trigger].self, forKey: .Triggers)
            ?? []
        self.ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !tableSchema.isEmpty {
            try container.encode(tableSchema, forKey: .TableSchema)
        }
        if !tableName.isEmpty {
            try container.encode(tableName, forKey: .TableName)
        }
        if !sql.isEmpty {
            try container.encode(sql, forKey: .SQL)
        }
        if isVirtual {
            try container.encode(isVirtual, forKey: .IsVirtual)
        }
        if !columns.isEmpty {
            try container.encode(columns, forKey: .Columns)
        }
        if !constraints.isEmpty {
            try container.encode(constraints, forKey: .Constraints)
        }
        if !indexes.isEmpty {
            try container.encode(indexes, forKey: .Indexes)
        }
        if !triggers.isEmpty {
            try container.encode(triggers, forKey: .Triggers)
        }
        if ignore {
            try container.encode(ignore, forKey: .Ignore)
        }
    }
}

public class Column: Codable {
    public var tableSchema: String
    public var tableName: String
    public var columnName: String
    public var columnType: String
    public var characterLength: String
    public var numericPrecision: String
    public var numericScale: String
    public var isNotNull: Bool
    public var isPrimaryKey: Bool
    public var isAutoincrement: Bool
    public var referencesSchema: String
    public var referencesTable: String
    public var referencesColumn: String
    public var updateRule: String
    public var deleteRule: String
    public var isGenerated: Bool
    public var generatedExpr: String
    public var generatedExprStored: Bool
    public var columnDefault: String
    public var ignore: Bool

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case ColumnName
        case ColumnType
        case CharacterLength
        case NumericPrecision
        case NumericScale
        case IsNotNull
        case IsPrimaryKey
        case IsAutoincrement
        case ReferencesSchema
        case ReferencesTable
        case ReferencesColumn
        case UpdateRule
        case DeleteRule
        case IsGenerated
        case GeneratedExpr
        case GeneratedExprStored
        case ColumnDefault
        case Ignore
    }

    public init(
        tableSchema: String = "",
        tableName: String = "",
        columnName: String = "",
        columnType: String = "",
        characterLength: String = "",
        numericPrecision: String = "",
        numericScale: String = "",
        isNotNull: Bool = false,
        isPrimaryKey: Bool = false,
        isAutoincrement: Bool = false,
        referencesSchema: String = "",
        referencesTable: String = "",
        referencesColumn: String = "",
        updateRule: String = "",
        deleteRule: String = "",
        isGenerated: Bool = false,
        generatedExpr: String = "",
        generatedExprStored: Bool = false,
        columnDefault: String = "",
        ignore: Bool = false
    ) {
        self.tableSchema = tableSchema
        self.tableName = tableName
        self.columnName = columnName
        self.columnType = columnType
        self.characterLength = characterLength
        self.numericPrecision = numericPrecision
        self.numericScale = numericScale
        self.isNotNull = isNotNull
        self.isPrimaryKey = isPrimaryKey
        self.isAutoincrement = isAutoincrement
        self.referencesSchema = referencesSchema
        self.referencesTable = referencesTable
        self.referencesColumn = referencesColumn
        self.updateRule = updateRule
        self.deleteRule = deleteRule
        self.isGenerated = isGenerated
        self.generatedExpr = generatedExpr
        self.generatedExprStored = generatedExprStored
        self.columnDefault = columnDefault
        self.ignore = ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? ""
        self.tableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? ""
        self.columnName =
            try container.decodeIfPresent(String.self, forKey: .ColumnName)
            ?? ""
        self.columnType =
            try container.decodeIfPresent(String.self, forKey: .ColumnType)
            ?? ""
        self.characterLength =
            try container.decodeIfPresent(String.self, forKey: .CharacterLength)
            ?? ""
        self.numericPrecision =
            try container.decodeIfPresent(
                String.self,
                forKey: .NumericPrecision
            ) ?? ""
        self.numericScale =
            try container.decodeIfPresent(String.self, forKey: .NumericScale)
            ?? ""
        self.isNotNull =
            try container.decodeIfPresent(Bool.self, forKey: .IsNotNull)
            ?? false
        self.isPrimaryKey =
            try container.decodeIfPresent(Bool.self, forKey: .IsPrimaryKey)
            ?? false
        self.isAutoincrement =
            try container.decodeIfPresent(Bool.self, forKey: .IsAutoincrement)
            ?? false
        self.referencesSchema =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesSchema
            ) ?? ""
        self.referencesTable =
            try container.decodeIfPresent(String.self, forKey: .ReferencesTable)
            ?? ""
        self.referencesColumn =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesColumn
            ) ?? ""
        self.updateRule =
            try container.decodeIfPresent(String.self, forKey: .UpdateRule)
            ?? ""
        self.deleteRule =
            try container.decodeIfPresent(String.self, forKey: .DeleteRule)
            ?? ""
        self.isGenerated =
            try container.decodeIfPresent(Bool.self, forKey: .IsGenerated)
            ?? false
        self.generatedExpr =
            try container.decodeIfPresent(String.self, forKey: .GeneratedExpr)
            ?? ""
        self.generatedExprStored =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .GeneratedExprStored
            ) ?? false
        self.columnDefault =
            try container.decodeIfPresent(String.self, forKey: .ColumnDefault)
            ?? ""
        self.ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !tableSchema.isEmpty {
            try container.encode(tableSchema, forKey: .TableSchema)
        }
        if !tableName.isEmpty {
            try container.encode(tableName, forKey: .TableName)
        }
        if !columnName.isEmpty {
            try container.encode(columnName, forKey: .ColumnName)
        }
        if !columnType.isEmpty {
            try container.encode(columnType, forKey: .ColumnType)
        }
        if !characterLength.isEmpty {
            try container.encode(characterLength, forKey: .CharacterLength)
        }
        if !numericPrecision.isEmpty {
            try container.encode(numericPrecision, forKey: .NumericPrecision)
        }
        if !numericScale.isEmpty {
            try container.encode(numericScale, forKey: .NumericScale)
        }
        if isNotNull {
            try container.encode(isNotNull, forKey: .IsNotNull)
        }
        if isPrimaryKey {
            try container.encode(isPrimaryKey, forKey: .IsPrimaryKey)
        }
        if isAutoincrement {
            try container.encode(isAutoincrement, forKey: .IsAutoincrement)
        }
        if !referencesSchema.isEmpty {
            try container.encode(referencesSchema, forKey: .ReferencesSchema)
        }
        if !referencesTable.isEmpty {
            try container.encode(referencesTable, forKey: .ReferencesTable)
        }
        if !referencesColumn.isEmpty {
            try container.encode(referencesColumn, forKey: .ReferencesColumn)
        }
        if !updateRule.isEmpty {
            try container.encode(updateRule, forKey: .UpdateRule)
        }
        if !deleteRule.isEmpty {
            try container.encode(deleteRule, forKey: .DeleteRule)
        }
        if isGenerated {
            try container.encode(isGenerated, forKey: .IsGenerated)
        }
        if !generatedExpr.isEmpty {
            try container.encode(generatedExpr, forKey: .GeneratedExpr)
        }
        if generatedExprStored {
            try container.encode(
                generatedExprStored,
                forKey: .GeneratedExprStored
            )
        }
        if !columnDefault.isEmpty {
            try container.encode(columnDefault, forKey: .ColumnDefault)
        }
        if ignore {
            try container.encode(ignore, forKey: .Ignore)
        }
    }
}

public class Constraint: Codable {
    public var tableSchema: String = ""
    public var tableName: String = ""
    public var constraintName: String = ""
    public var constraintType: String = ""
    public var columns: [String] = []
    public var referencesSchema: String = ""
    public var referencesTable: String = ""
    public var referencesColumns: [String] = []
    public var updateRule: String = ""
    public var deleteRule: String = ""
    public var ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case ConstraintName
        case ConstraintType
        case Columns
        case ReferencesSchema
        case ReferencesTable
        case ReferencesColumns
        case UpdateRule
        case DeleteRule
        case Ignore
    }

    public init(
        TableSchema: String = "",
        TableName: String = "",
        ConstraintName: String = "",
        ConstraintType: String = "",
        Columns: [String] = [],
        ReferencesSchema: String = "",
        ReferencesTable: String = "",
        ReferencesColumns: [String] = [],
        UpdateRule: String = "",
        DeleteRule: String = "",
        Ignore: Bool = false
    ) {
        self.tableSchema = TableSchema
        self.tableName = TableName
        self.constraintName = ConstraintName
        self.constraintType = ConstraintType
        self.columns = Columns
        self.referencesSchema = ReferencesSchema
        self.referencesTable = ReferencesTable
        self.referencesColumns = ReferencesColumns
        self.updateRule = UpdateRule
        self.deleteRule = DeleteRule
        self.ignore = Ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.tableSchema
        self.tableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.tableName
        self.constraintName =
            try container.decodeIfPresent(String.self, forKey: .ConstraintName)
            ?? self.constraintName
        self.constraintType =
            try container.decodeIfPresent(String.self, forKey: .ConstraintType)
            ?? self.constraintType
        self.columns =
            try container.decodeIfPresent([String].self, forKey: .Columns)
            ?? self.columns
        self.referencesSchema =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesSchema
            ) ?? self.referencesSchema
        self.referencesTable =
            try container.decodeIfPresent(String.self, forKey: .ReferencesTable)
            ?? self.referencesTable
        self.referencesColumns =
            try container.decodeIfPresent(
                [String].self,
                forKey: .ReferencesColumns
            ) ?? self.referencesColumns
        self.updateRule =
            try container.decodeIfPresent(String.self, forKey: .UpdateRule)
            ?? self.updateRule
        self.deleteRule =
            try container.decodeIfPresent(String.self, forKey: .DeleteRule)
            ?? self.deleteRule
        self.ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.ignore
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !tableSchema.isEmpty {
            try container.encode(tableSchema, forKey: .TableSchema)
        }
        if !tableName.isEmpty {
            try container.encode(tableName, forKey: .TableName)
        }
        if !constraintName.isEmpty {
            try container.encode(constraintName, forKey: .ConstraintName)
        }
        if !constraintType.isEmpty {
            try container.encode(constraintType, forKey: .ConstraintType)
        }
        if !columns.isEmpty {
            try container.encode(columns, forKey: .Columns)
        }
        if !referencesSchema.isEmpty {
            try container.encode(referencesSchema, forKey: .ReferencesSchema)
        }
        if !referencesTable.isEmpty {
            try container.encode(referencesTable, forKey: .ReferencesTable)
        }
        if !referencesColumns.isEmpty {
            try container.encode(referencesColumns, forKey: .ReferencesColumns)
        }
        if !updateRule.isEmpty {
            try container.encode(updateRule, forKey: .UpdateRule)
        }
        if !deleteRule.isEmpty {
            try container.encode(deleteRule, forKey: .DeleteRule)
        }
        if ignore {
            try container.encode(ignore, forKey: .Ignore)
        }
    }
}

public class Index: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var IndexName: String = ""
    public var IsUnique: Bool = false
    public var Columns: [String] = []
    public var SQL: String = ""
    public var Ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case IndexName
        case IsUnique
        case Columns
        case SQL
        case Ignore
    }

    public init(
        TableSchema: String = "",
        TableName: String = "",
        IndexName: String = "",
        IsUnique: Bool = false,
        Columns: [String] = [],
        SQL: String = "",
        Ignore: Bool = false
    ) {
        self.TableSchema = TableSchema
        self.TableName = TableName
        self.IndexName = IndexName
        self.IsUnique = IsUnique
        self.Columns = Columns
        self.SQL = SQL
        self.Ignore = Ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.TableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.TableSchema
        self.TableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.TableName
        self.IndexName =
            try container.decodeIfPresent(String.self, forKey: .IndexName)
            ?? self.IndexName
        self.IsUnique =
            try container.decodeIfPresent(Bool.self, forKey: .IsUnique)
            ?? self.IsUnique
        self.Columns =
            try container.decodeIfPresent([String].self, forKey: .Columns)
            ?? self.Columns
        self.SQL =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? self.SQL
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !TableSchema.isEmpty {
            try container.encode(TableSchema, forKey: .TableSchema)
        }
        if !TableName.isEmpty {
            try container.encode(TableName, forKey: .TableName)
        }
        if !IndexName.isEmpty {
            try container.encode(IndexName, forKey: .IndexName)
        }
        if IsUnique {
            try container.encode(IsUnique, forKey: .IsUnique)
        }
        if !Columns.isEmpty {
            try container.encode(Columns, forKey: .Columns)
        }
        if !SQL.isEmpty {
            try container.encode(SQL, forKey: .SQL)
        }
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
}

public class Trigger: Codable {
    public var TableSchema: String = ""
    public var TableName: String = ""
    public var TriggerName: String = ""
    public var SQL: String = ""
    public var Ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case TriggerName
        case SQL
        case Ignore
    }

    public init(
        TableSchema: String = "",
        TableName: String = "",
        TriggerName: String = "",
        SQL: String = "",
        Ignore: Bool = false
    ) {
        self.TableSchema = TableSchema
        self.TableName = TableName
        self.TriggerName = TriggerName
        self.SQL = SQL
        self.Ignore = Ignore
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.TableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.TableSchema
        self.TableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.TableName
        self.TriggerName =
            try container.decodeIfPresent(String.self, forKey: .TriggerName)
            ?? self.TriggerName
        self.SQL =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? self.SQL
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !TableSchema.isEmpty {
            try container.encode(TableSchema, forKey: .TableSchema)
        }
        if !TableName.isEmpty {
            try container.encode(TableName, forKey: .TableName)
        }
        if !TriggerName.isEmpty {
            try container.encode(TriggerName, forKey: .TriggerName)
        }
        if !SQL.isEmpty {
            try container.encode(SQL, forKey: .SQL)
        }
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
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
        for (i, schema) in catalog.schemas.enumerated() {
            self.schemaIndices[schema.schemaName] = i
            for (j, view) in schema.views.enumerated() {
                let viewID = Pair(schema.schemaName, view.viewName)
                self.viewIndices[viewID] = j
            }
            for (j, table) in schema.tables.enumerated() {
                let tableID = Pair(schema.schemaName, table.tableName)
                self.tableIndices[tableID] = j
                for (k, column) in table.columns.enumerated() {
                    let columnID = Triple(
                        schema.schemaName,
                        table.tableName,
                        column.columnName
                    )
                    self.columnIndices[columnID] = k
                }
                for (k, constraint) in table.constraints.enumerated() {
                    let constraintID = Triple(
                        schema.schemaName,
                        table.tableName,
                        constraint.constraintName
                    )
                    let tableID = Pair(schema.schemaName, table.tableName)
                    switch constraint.constraintType {
                    case PRIMARY_KEY:
                        primaryKeyIndices[tableID] = k
                    case FOREIGN_KEY:
                        foreignKeyIndices[tableID, default: []].append(k)
                    default:
                        break
                    }
                    if constraint.constraintName.isEmpty {  // SQLite constraints have no names.
                        continue
                    }
                    self.constraintIndices[constraintID] = k
                }
                for (k, index) in table.indexes.enumerated() {
                    let indexID = Triple(
                        schema.schemaName,
                        table.tableName,
                        index.IndexName
                    )
                    self.indexIndices[indexID] = k
                }
                for (k, trigger) in table.triggers.enumerated() {
                    let triggerID = Triple(
                        schema.schemaName,
                        table.tableName,
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
        if let i = schemaIndices[schemaName], !catalog.schemas[i].ignore {
            return catalog.schemas[i]
        }
        return nil
    }

    public mutating func getOrCreateSchema(catalog: Catalog, schemaName: String)
        -> Schema
    {
        if let i = schemaIndices[schemaName], !catalog.schemas[i].ignore {
            return catalog.schemas[i]
        }
        let schema = Schema()
        schema.schemaName = schemaName
        catalog.schemas.append(schema)
        let i = catalog.schemas.count - 1
        schemaIndices[schemaName] = i
        return catalog.schemas[i]
    }

    public mutating func addOrUpdateSchema(catalog: Catalog, schema: Schema) {
        if let i = schemaIndices[schema.schemaName], !catalog.schemas[i].ignore
        {
            catalog.schemas[i] = schema
            return
        }
        catalog.schemas.append(schema)
        let i = catalog.schemas.count - 1
        schemaIndices[schema.schemaName] = i
    }

    public func getView(schema: Schema?, viewName: String) -> View? {
        guard let schema = schema else {
            return nil
        }
        let viewID = Pair(schema.schemaName, viewName)
        if let i = viewIndices[viewID], !schema.views[i].ignore {
            return schema.views[i]
        }
        return nil
    }

    public mutating func getOrCreateView(schema: Schema, viewName: String)
        -> View
    {
        let viewID = Pair(schema.schemaName, viewName)
        if let i = viewIndices[viewID], !schema.views[i].ignore {
            return schema.views[i]
        }
        let view = View()
        view.viewSchema = schema.schemaName
        view.viewName = viewName
        schema.views.append(view)
        let i = schema.views.count - 1
        viewIndices[viewID] = i
        return schema.views[i]
    }

    public mutating func addOrUpdateView(schema: Schema, view: View) {
        let viewID = Pair(schema.schemaName, view.viewName)
        if let i = viewIndices[viewID], !schema.views[i].ignore {
            schema.views[i] = view
            return
        }
        schema.views.append(view)
        let i = schema.views.count - 1
        viewIndices[viewID] = i
    }

    public func getTable(schema: Schema?, tableName: String) -> Table? {
        guard let schema = schema else {
            return nil
        }
        let tableID = Pair(schema.schemaName, tableName)
        if let i = tableIndices[tableID], !schema.tables[i].ignore {
            return schema.tables[i]
        }
        return nil
    }

    public mutating func getOrCreateTable(schema: Schema, tableName: String)
        -> Table
    {
        let tableID = Pair(schema.schemaName, tableName)
        if let i = tableIndices[tableID], !schema.tables[i].ignore {
            return schema.tables[i]
        }
        let table = Table()
        table.tableSchema = schema.schemaName
        table.tableName = tableName
        schema.tables.append(table)
        let i = schema.tables.count - 1
        tableIndices[tableID] = i
        return schema.tables[i]
    }

    public mutating func addOrUpdateTable(schema: Schema, table: Table) {
        let tableID = Pair(schema.schemaName, table.tableName)
        if let i = tableIndices[tableID], !schema.tables[i].ignore {
            schema.tables[i] = table
            return
        }
        schema.tables.append(table)
        let i = schema.tables.count - 1
        tableIndices[tableID] = i
    }

    public func getColumn(table: Table?, columnName: String) -> Column? {
        guard let table = table else {
            return nil
        }
        let columnID = Triple(table.tableSchema, table.tableName, columnName)
        if let i = columnIndices[columnID], !table.columns[i].ignore {
            return table.columns[i]
        }
        return nil
    }

    public mutating func getOrCreateColumn(table: Table, columnName: String)
        -> Column
    {
        let columnID = Triple(table.tableSchema, table.tableName, columnName)
        if let i = columnIndices[columnID], !table.columns[i].ignore {
            return table.columns[i]
        }
        let column = Column()
        column.tableSchema = table.tableSchema
        column.tableName = table.tableName
        column.columnName = columnName
        table.columns.append(column)
        let i = table.columns.count - 1
        columnIndices[columnID] = i
        return table.columns[i]
    }

    public mutating func addOrUpdateColumn(table: Table, column: Column) {
        let columnID = Triple(
            table.tableSchema,
            table.tableName,
            column.columnName
        )
        if let i = columnIndices[columnID], !table.columns[i].ignore {
            table.columns[i] = column
            return
        }
        table.columns.append(column)
        let i = table.columns.count - 1
        columnIndices[columnID] = i
    }

    public func getConstraint(table: Table?, constraintName: String)
        -> Constraint?
    {
        guard let table = table else {
            return nil
        }
        let constraintID = Triple(
            table.tableSchema,
            table.tableName,
            constraintName
        )
        if let i = constraintIndices[constraintID], !table.constraints[i].ignore
        {
            return table.constraints[i]
        }
        return nil
    }

    public mutating func getOrCreateConstraint(
        table: Table,
        constraintName: String
    )
        -> Constraint
    {
        let constraintID = Triple(
            table.tableSchema,
            table.tableName,
            constraintName
        )
        if let i = constraintIndices[constraintID], !table.constraints[i].ignore
        {
            return table.constraints[i]
        }
        let constraint = Constraint()
        constraint.tableSchema = table.tableSchema
        constraint.tableName = table.tableName
        constraint.constraintName = constraintName
        table.constraints.append(constraint)
        let i = table.constraints.count - 1
        constraintIndices[constraintID] = i
        return table.constraints[i]
    }

    public mutating func addOrUpdateConstraint(
        table: Table,
        constraint: Constraint
    ) {
        let constraintID = Triple(
            table.tableSchema,
            table.tableName,
            constraint.constraintName
        )
        if let i = constraintIndices[constraintID], !table.constraints[i].ignore
        {
            table.constraints[i] = constraint
            return
        }
        table.constraints.append(constraint)
        let i = table.constraints.count - 1
        let tableID = Pair(table.tableSchema, table.tableName)
        switch constraint.constraintType {
        case PRIMARY_KEY:
            primaryKeyIndices[tableID] = i
        case FOREIGN_KEY:
            foreignKeyIndices[tableID, default: []].append(i)
        default:
            break
        }
        if !constraint.constraintName.isEmpty {  // SQLite constraints have no name.
            constraintIndices[constraintID] = i
        }
    }

    public func getIndex(table: Table?, indexName: String) -> Index? {
        guard let table = table else {
            return nil
        }
        let indexID = Triple(table.tableSchema, table.tableName, indexName)
        if let i = indexIndices[indexID], !table.indexes[i].Ignore {
            return table.indexes[i]
        }
        return nil
    }

    public mutating func getOrCreateIndex(table: Table, indexName: String)
        -> Index
    {
        let indexID = Triple(table.tableSchema, table.tableName, indexName)
        if let i = indexIndices[indexID], !table.indexes[i].Ignore {
            return table.indexes[i]
        }
        let index = Index()
        index.TableSchema = table.tableSchema
        index.TableName = table.tableName
        index.IndexName = indexName
        table.indexes.append(index)
        let i = table.indexes.count - 1
        indexIndices[indexID] = i
        return table.indexes[i]
    }

    public mutating func addOrUpdateIndex(table: Table, index: Index) {
        let indexID = Triple(
            table.tableSchema,
            table.tableName,
            index.IndexName
        )
        if let i = indexIndices[indexID], !table.indexes[i].Ignore {
            table.indexes[i] = index
            return
        }
        table.indexes.append(index)
        let i = table.indexes.count - 1
        indexIndices[indexID] = i
    }

    public func getTrigger(table: Table?, triggerName: String) -> Trigger? {
        guard let table = table else {
            return nil
        }
        let triggerID = Triple(table.tableSchema, table.tableName, triggerName)
        if let i = triggerIndices[triggerID], !table.triggers[i].Ignore {
            return table.triggers[i]
        }
        return nil
    }

    public mutating func getOrCreateTrigger(table: Table, triggerName: String)
        -> Trigger
    {
        let triggerID = Triple(table.tableSchema, table.tableName, triggerName)
        if let i = triggerIndices[triggerID], !table.triggers[i].Ignore {
            return table.triggers[i]
        }
        let trigger = Trigger()
        trigger.TableSchema = table.tableSchema
        trigger.TableName = table.tableName
        trigger.TriggerName = triggerName
        table.triggers.append(trigger)
        let i = table.triggers.count - 1
        triggerIndices[triggerID] = i
        return table.triggers[i]
    }

    public mutating func addOrUpdateTrigger(table: Table, trigger: Trigger) {
        let triggerID = Triple(
            table.tableSchema,
            table.tableName,
            trigger.TriggerName
        )
        if let i = triggerIndices[triggerID], !table.triggers[i].Ignore {
            table.triggers[i] = trigger
            return
        }
        table.triggers.append(trigger)
        let i = table.triggers.count - 1
        triggerIndices[triggerID] = i
    }

    public func getPrimaryKey(table: Table?) -> Constraint? {
        guard let table = table else {
            return nil
        }
        let tableID = Pair(table.tableSchema, table.tableName)
        if let i = primaryKeyIndices[tableID] {
            return table.constraints[i]
        }
        return nil
    }

    public func getForeignKeys(table: Table?) -> [Constraint] {
        guard let table = table else {
            return []
        }
        let tableID = Pair(table.tableSchema, table.tableName)
        guard let indices = foreignKeyIndices[tableID] else {
            return []
        }
        var foreignKeys: [Constraint] = []
        for i in indices {
            let foreignKey = table.constraints[i]
            if foreignKey.ignore {
                continue
            }
            foreignKeys.append(foreignKey)
        }
        return foreignKeys
    }
}
