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
    public var VersionNums: [Int] = []
    public var CatalogName: String = ""
    public var CurrentSchema: String = ""
    public var Schemas: [Schema] = []

    private enum CodingKeys: String, CodingKey {
        case VersionNums
        case CatalogName
        case CurrentSchema
        case Schemas
    }

    // Replaced the empty init() with a memberwise initializer with default values
    public init(
        VersionNums: [Int] = [],
        CatalogName: String = "",
        CurrentSchema: String = "",
        Schemas: [Schema] = []
    ) {
        self.VersionNums = VersionNums
        self.CatalogName = CatalogName
        self.CurrentSchema = CurrentSchema
        self.Schemas = Schemas
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode, keeping default value if key is missing
        self.VersionNums =
            try container.decodeIfPresent([Int].self, forKey: .VersionNums)
            ?? self.VersionNums
        self.CatalogName =
            try container.decodeIfPresent(String.self, forKey: .CatalogName)
            ?? self.CatalogName
        self.CurrentSchema =
            try container.decodeIfPresent(String.self, forKey: .CurrentSchema)
            ?? self.CurrentSchema
        self.Schemas =
            try container.decodeIfPresent([Schema].self, forKey: .Schemas)
            ?? self.Schemas
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode only if value is not the zero value
        if !VersionNums.isEmpty {
            try container.encode(VersionNums, forKey: .VersionNums)
        }
        if !CatalogName.isEmpty {
            try container.encode(CatalogName, forKey: .CatalogName)
        }
        if !CurrentSchema.isEmpty {
            try container.encode(CurrentSchema, forKey: .CurrentSchema)
        }
        if !Schemas.isEmpty {
            try container.encode(Schemas, forKey: .Schemas)
        }
    }
}

public class Schema: Codable {
    public var SchemaName: String = ""
    public var Tables: [Table] = []
    public var Views: [View] = []
    public var ViewsValid: Bool = false
    public var Ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case SchemaName
        case Tables
        case Views
        case ViewsValid
        case Ignore
    }

    // Replaced the empty init() with a memberwise initializer with default values
    public init(
        SchemaName: String = "",
        Tables: [Table] = [],
        Views: [View] = [],
        ViewsValid: Bool = false,
        Ignore: Bool = false
    ) {
        self.SchemaName = SchemaName
        self.Tables = Tables
        self.Views = Views
        self.ViewsValid = ViewsValid
        self.Ignore = Ignore
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.SchemaName =
            try container.decodeIfPresent(String.self, forKey: .SchemaName)
            ?? self.SchemaName
        self.Tables =
            try container.decodeIfPresent([Table].self, forKey: .Tables)
            ?? self.Tables
        self.Views =
            try container.decodeIfPresent([View].self, forKey: .Views)
            ?? self.Views
        self.ViewsValid =
            try container.decodeIfPresent(Bool.self, forKey: .ViewsValid)
            ?? self.ViewsValid
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !SchemaName.isEmpty {
            try container.encode(SchemaName, forKey: .SchemaName)
        }
        if !Tables.isEmpty {
            try container.encode(Tables, forKey: .Tables)
        }
        if !Views.isEmpty {
            try container.encode(Views, forKey: .Views)
        }
        // Encode Bool fields only if they are true
        if ViewsValid {
            try container.encode(ViewsValid, forKey: .ViewsValid)
        }
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
}

public class View: Codable {
    public var ViewSchema: String = ""
    public var ViewName: String = ""
    public var SQL: String = ""
    public var Columns: [String] = []
    public var ColumnTypes: [String] = []
    public var Ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case ViewSchema
        case ViewName
        case SQL
        case Columns
        case ColumnTypes
        case Ignore
    }

    // Replaced the empty init() with a memberwise initializer with default values
    public init(
        ViewSchema: String = "",
        ViewName: String = "",
        SQL: String = "",
        Columns: [String] = [],
        ColumnTypes: [String] = [],
        Ignore: Bool = false
    ) {
        self.ViewSchema = ViewSchema
        self.ViewName = ViewName
        self.SQL = SQL
        self.Columns = Columns
        self.ColumnTypes = ColumnTypes
        self.Ignore = Ignore
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ViewSchema =
            try container.decodeIfPresent(String.self, forKey: .ViewSchema)
            ?? self.ViewSchema
        self.ViewName =
            try container.decodeIfPresent(String.self, forKey: .ViewName)
            ?? self.ViewName
        self.SQL =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? self.SQL
        self.Columns =
            try container.decodeIfPresent([String].self, forKey: .Columns)
            ?? self.Columns
        self.ColumnTypes =
            try container.decodeIfPresent([String].self, forKey: .ColumnTypes)
            ?? self.ColumnTypes
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !ViewSchema.isEmpty {
            try container.encode(ViewSchema, forKey: .ViewSchema)
        }
        if !ViewName.isEmpty {
            try container.encode(ViewName, forKey: .ViewName)
        }
        if !SQL.isEmpty {
            try container.encode(SQL, forKey: .SQL)
        }
        if !Columns.isEmpty {
            try container.encode(Columns, forKey: .Columns)
        }
        if !ColumnTypes.isEmpty {
            try container.encode(ColumnTypes, forKey: .ColumnTypes)
        }
        // Encode Bool fields only if they are true
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
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

    // Replaced the empty init() with a memberwise initializer with default values
    public init(
        TableSchema: String = "",
        TableName: String = "",
        SQL: String = "",
        IsVirtual: Bool = false,
        Columns: [Column] = [],
        Constraints: [Constraint] = [],
        Indexes: [Index] = [],
        Triggers: [Trigger] = [],
        Ignore: Bool = false
    ) {
        self.TableSchema = TableSchema
        self.TableName = TableName
        self.SQL = SQL
        self.IsVirtual = IsVirtual
        self.Columns = Columns
        self.Constraints = Constraints
        self.Indexes = Indexes
        self.Triggers = Triggers
        self.Ignore = Ignore
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.TableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.TableSchema
        self.TableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.TableName
        self.SQL =
            try container.decodeIfPresent(String.self, forKey: .SQL) ?? self.SQL
        self.IsVirtual =
            try container.decodeIfPresent(Bool.self, forKey: .IsVirtual)
            ?? self.IsVirtual
        self.Columns =
            try container.decodeIfPresent([Column].self, forKey: .Columns)
            ?? self.Columns
        self.Constraints =
            try container.decodeIfPresent(
                [Constraint].self,
                forKey: .Constraints
            ) ?? self.Constraints
        self.Indexes =
            try container.decodeIfPresent([Index].self, forKey: .Indexes)
            ?? self.Indexes
        self.Triggers =
            try container.decodeIfPresent([Trigger].self, forKey: .Triggers)
            ?? self.Triggers
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !TableSchema.isEmpty {
            try container.encode(TableSchema, forKey: .TableSchema)
        }
        if !TableName.isEmpty {
            try container.encode(TableName, forKey: .TableName)
        }
        if !SQL.isEmpty {
            try container.encode(SQL, forKey: .SQL)
        }
        // Encode Bool fields only if they are true
        if IsVirtual {
            try container.encode(IsVirtual, forKey: .IsVirtual)
        }
        if !Columns.isEmpty {
            try container.encode(Columns, forKey: .Columns)
        }
        if !Constraints.isEmpty {
            try container.encode(Constraints, forKey: .Constraints)
        }
        if !Indexes.isEmpty {
            try container.encode(Indexes, forKey: .Indexes)
        }
        if !Triggers.isEmpty {
            try container.encode(Triggers, forKey: .Triggers)
        }
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
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

    // Replaced the empty init() with a memberwise initializer with default values
    public init(
        TableSchema: String = "",
        TableName: String = "",
        ColumnName: String = "",
        ColumnType: String = "",
        CharacterLength: String = "",
        NumericPrecision: String = "",
        NumericScale: String = "",
        IsNotNull: Bool = false,
        IsPrimaryKey: Bool = false,
        IsAutoincrement: Bool = false,
        ReferencesSchema: String = "",
        ReferencesTable: String = "",
        ReferencesColumn: String = "",
        UpdateRule: String = "",
        DeleteRule: String = "",
        IsGenerated: Bool = false,
        GeneratedExpr: String = "",
        GeneratedExprStored: Bool = false,
        ColumnDefault: String = "",
        Ignore: Bool = false
    ) {
        self.TableSchema = TableSchema
        self.TableName = TableName
        self.ColumnName = ColumnName
        self.ColumnType = ColumnType
        self.CharacterLength = CharacterLength
        self.NumericPrecision = NumericPrecision
        self.NumericScale = NumericScale
        self.IsNotNull = IsNotNull
        self.IsPrimaryKey = IsPrimaryKey
        self.IsAutoincrement = IsAutoincrement
        self.ReferencesSchema = ReferencesSchema
        self.ReferencesTable = ReferencesTable
        self.ReferencesColumn = ReferencesColumn
        self.UpdateRule = UpdateRule
        self.DeleteRule = DeleteRule
        self.IsGenerated = IsGenerated
        self.GeneratedExpr = GeneratedExpr
        self.GeneratedExprStored = GeneratedExprStored
        self.ColumnDefault = ColumnDefault
        self.Ignore = Ignore
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.TableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.TableSchema
        self.TableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.TableName
        self.ColumnName =
            try container.decodeIfPresent(String.self, forKey: .ColumnName)
            ?? self.ColumnName
        self.ColumnType =
            try container.decodeIfPresent(String.self, forKey: .ColumnType)
            ?? self.ColumnType
        self.CharacterLength =
            try container.decodeIfPresent(String.self, forKey: .CharacterLength)
            ?? self.CharacterLength
        self.NumericPrecision =
            try container.decodeIfPresent(
                String.self,
                forKey: .NumericPrecision
            ) ?? self.NumericPrecision
        self.NumericScale =
            try container.decodeIfPresent(String.self, forKey: .NumericScale)
            ?? self.NumericScale
        self.IsNotNull =
            try container.decodeIfPresent(Bool.self, forKey: .IsNotNull)
            ?? self.IsNotNull
        self.IsPrimaryKey =
            try container.decodeIfPresent(Bool.self, forKey: .IsPrimaryKey)
            ?? self.IsPrimaryKey
        self.IsAutoincrement =
            try container.decodeIfPresent(Bool.self, forKey: .IsAutoincrement)
            ?? self.IsAutoincrement
        self.ReferencesSchema =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesSchema
            ) ?? self.ReferencesSchema
        self.ReferencesTable =
            try container.decodeIfPresent(String.self, forKey: .ReferencesTable)
            ?? self.ReferencesTable
        self.ReferencesColumn =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesColumn
            ) ?? self.ReferencesColumn
        self.UpdateRule =
            try container.decodeIfPresent(String.self, forKey: .UpdateRule)
            ?? self.UpdateRule
        self.DeleteRule =
            try container.decodeIfPresent(String.self, forKey: .DeleteRule)
            ?? self.DeleteRule
        self.IsGenerated =
            try container.decodeIfPresent(Bool.self, forKey: .IsGenerated)
            ?? self.IsGenerated
        self.GeneratedExpr =
            try container.decodeIfPresent(String.self, forKey: .GeneratedExpr)
            ?? self.GeneratedExpr
        self.GeneratedExprStored =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .GeneratedExprStored
            ) ?? self.GeneratedExprStored
        self.ColumnDefault =
            try container.decodeIfPresent(String.self, forKey: .ColumnDefault)
            ?? self.ColumnDefault
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !TableSchema.isEmpty {
            try container.encode(TableSchema, forKey: .TableSchema)
        }
        if !TableName.isEmpty {
            try container.encode(TableName, forKey: .TableName)
        }
        if !ColumnName.isEmpty {
            try container.encode(ColumnName, forKey: .ColumnName)
        }
        if !ColumnType.isEmpty {
            try container.encode(ColumnType, forKey: .ColumnType)
        }
        if !CharacterLength.isEmpty {
            try container.encode(CharacterLength, forKey: .CharacterLength)
        }
        if !NumericPrecision.isEmpty {
            try container.encode(NumericPrecision, forKey: .NumericPrecision)
        }
        if !NumericScale.isEmpty {
            try container.encode(NumericScale, forKey: .NumericScale)
        }
        // Encode Bool fields only if they are true
        if IsNotNull {
            try container.encode(IsNotNull, forKey: .IsNotNull)
        }
        if IsPrimaryKey {
            try container.encode(IsPrimaryKey, forKey: .IsPrimaryKey)
        }
        if IsAutoincrement {
            try container.encode(IsAutoincrement, forKey: .IsAutoincrement)
        }
        if !ReferencesSchema.isEmpty {
            try container.encode(ReferencesSchema, forKey: .ReferencesSchema)
        }
        if !ReferencesTable.isEmpty {
            try container.encode(ReferencesTable, forKey: .ReferencesTable)
        }
        if !ReferencesColumn.isEmpty {
            try container.encode(ReferencesColumn, forKey: .ReferencesColumn)
        }
        if !UpdateRule.isEmpty {
            try container.encode(UpdateRule, forKey: .UpdateRule)
        }
        if !DeleteRule.isEmpty {
            try container.encode(DeleteRule, forKey: .DeleteRule)
        }
        if IsGenerated {
            try container.encode(IsGenerated, forKey: .IsGenerated)
        }
        if !GeneratedExpr.isEmpty {
            try container.encode(GeneratedExpr, forKey: .GeneratedExpr)
        }
        if GeneratedExprStored {
            try container.encode(
                GeneratedExprStored,
                forKey: .GeneratedExprStored
            )
        }
        if !ColumnDefault.isEmpty {
            try container.encode(ColumnDefault, forKey: .ColumnDefault)
        }
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
        }
    }
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

    // Replaced the empty init() with a memberwise initializer with default values
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
        self.TableSchema = TableSchema
        self.TableName = TableName
        self.ConstraintName = ConstraintName
        self.ConstraintType = ConstraintType
        self.Columns = Columns
        self.ReferencesSchema = ReferencesSchema
        self.ReferencesTable = ReferencesTable
        self.ReferencesColumns = ReferencesColumns
        self.UpdateRule = UpdateRule
        self.DeleteRule = DeleteRule
        self.Ignore = Ignore
    }

    // Keep the required init(from:) for custom decoding logic
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.TableSchema =
            try container.decodeIfPresent(String.self, forKey: .TableSchema)
            ?? self.TableSchema
        self.TableName =
            try container.decodeIfPresent(String.self, forKey: .TableName)
            ?? self.TableName
        self.ConstraintName =
            try container.decodeIfPresent(String.self, forKey: .ConstraintName)
            ?? self.ConstraintName
        self.ConstraintType =
            try container.decodeIfPresent(String.self, forKey: .ConstraintType)
            ?? self.ConstraintType
        self.Columns =
            try container.decodeIfPresent([String].self, forKey: .Columns)
            ?? self.Columns
        self.ReferencesSchema =
            try container.decodeIfPresent(
                String.self,
                forKey: .ReferencesSchema
            ) ?? self.ReferencesSchema
        self.ReferencesTable =
            try container.decodeIfPresent(String.self, forKey: .ReferencesTable)
            ?? self.ReferencesTable
        self.ReferencesColumns =
            try container.decodeIfPresent(
                [String].self,
                forKey: .ReferencesColumns
            ) ?? self.ReferencesColumns
        self.UpdateRule =
            try container.decodeIfPresent(String.self, forKey: .UpdateRule)
            ?? self.UpdateRule
        self.DeleteRule =
            try container.decodeIfPresent(String.self, forKey: .DeleteRule)
            ?? self.DeleteRule
        self.Ignore =
            try container.decodeIfPresent(Bool.self, forKey: .Ignore)
            ?? self.Ignore
    }

    // Keep the custom encode(to:) logic
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !TableSchema.isEmpty {
            try container.encode(TableSchema, forKey: .TableSchema)
        }
        if !TableName.isEmpty {
            try container.encode(TableName, forKey: .TableName)
        }
        if !ConstraintName.isEmpty {
            try container.encode(ConstraintName, forKey: .ConstraintName)
        }
        if !ConstraintType.isEmpty {
            try container.encode(ConstraintType, forKey: .ConstraintType)
        }
        if !Columns.isEmpty {
            try container.encode(Columns, forKey: .Columns)
        }
        if !ReferencesSchema.isEmpty {
            try container.encode(ReferencesSchema, forKey: .ReferencesSchema)
        }
        if !ReferencesTable.isEmpty {
            try container.encode(ReferencesTable, forKey: .ReferencesTable)
        }
        if !ReferencesColumns.isEmpty {
            try container.encode(ReferencesColumns, forKey: .ReferencesColumns)
        }
        if !UpdateRule.isEmpty {
            try container.encode(UpdateRule, forKey: .UpdateRule)
        }
        if !DeleteRule.isEmpty {
            try container.encode(DeleteRule, forKey: .DeleteRule)
        }
        // Encode Bool fields only if they are true
        if Ignore {
            try container.encode(Ignore, forKey: .Ignore)
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

    // Replaced the empty init() with a memberwise initializer with default values
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

    // Keep the required init(from:) for custom decoding logic
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

    // Keep the custom encode(to:) logic
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
        // Encode Bool fields only if they are true
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
    public var SQL: String = ""  // Added explicit String type for clarity
    public var Ignore: Bool = false

    private enum CodingKeys: String, CodingKey {
        case TableSchema
        case TableName
        case TriggerName
        case SQL
        case Ignore
    }

    // Replaced the empty init() with a memberwise initializer with default values
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

    // Keep the required init(from:) for custom decoding logic
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

    // Keep the custom encode(to:) logic
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
        // Encode Bool fields only if they are true
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

    public mutating func getOrCreateView(schema: Schema, viewName: String)
        -> View
    {
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

    public mutating func getOrCreateTable(schema: Schema, tableName: String)
        -> Table
    {
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

    public mutating func getOrCreateColumn(table: Table, columnName: String)
        -> Column
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

    public func getConstraint(table: Table?, constraintName: String)
        -> Constraint?
    {
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

    public mutating func getOrCreateConstraint(
        table: Table,
        constraintName: String
    )
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

    public mutating func addOrUpdateConstraint(
        table: Table,
        constraint: Constraint
    ) {
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

    public mutating func getOrCreateIndex(table: Table, indexName: String)
        -> Index
    {
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
