struct SQLiteMigration {
    var dropTables: [Table] = []
    var createTables: [Table] = []
    var alterTables: [SQLiteAlterTable] = []

    struct SQLiteAlterTable {
        let srcTable: Table
        let destTable: Table
        var dropIndexes: [Index] = []
        var dropConstraints: [Constraint] = []
        var dropColumns: [Column] = []
        var addColumns: [Column] = []
        var alterColumns: [(Column, Column)] = []
        var addConstraints: [Constraint] = []
        var createIndexes: [Index] = []
        var columnIsDropped: Set<String> = Set()
        var columnIsAdded: Set<String> = Set()
    }

    init(srcCatalog: Catalog, destCatalog: Catalog, dropObjects: Bool) {
        if srcCatalog.schemas.isEmpty && destCatalog.schemas.isEmpty {
            return
        }
        if destCatalog.schemas.isEmpty {
            if dropObjects {
                for srcTable in srcCatalog.schemas[0].tables {
                    if isVirtualTable(srcTable) {
                        continue
                    }
                    dropTables.append(srcTable)
                }
            }
            return
        }
        if srcCatalog.schemas.isEmpty {
            for destTable in destCatalog.schemas[0].tables {
                if isVirtualTable(destTable) {
                    continue
                }
                createTables.append(destTable)
            }
            return
        }

        // Because SQLite doesn't support constraint names, we have to generate it
        // ourselves (we need constraint names because that's how we identify the
        // existence of a constraint).
        for srcSchema in srcCatalog.schemas {
            for srcTable in srcSchema.tables {
                if isVirtualTable(srcTable) {
                    continue
                }
                for srcConstraint in srcTable.constraints {
                    switch srcConstraint.constraintType {
                    case PRIMARY_KEY, UNIQUE, FOREIGN_KEY:
                        srcConstraint.constraintName = generateName(
                            nameType: srcConstraint.constraintType,
                            tableName: srcConstraint.tableName,
                            columnNames: srcConstraint.columns
                        )
                    default:
                        break
                    }
                }
            }
        }
        for destSchema in destCatalog.schemas {
            for destTable in destSchema.tables {
                if isVirtualTable(destTable) {
                    continue
                }
                for destConstraint in destTable.constraints {
                    switch destConstraint.constraintType {
                    case PRIMARY_KEY, UNIQUE, FOREIGN_KEY:
                        destConstraint.constraintName = generateName(
                            nameType: destConstraint.constraintType,
                            tableName: destConstraint.tableName,
                            columnNames: destConstraint.columns
                        )
                    default:
                        break
                    }
                }
            }
        }

        var srcCache = CatalogCache(from: srcCatalog)
        var srcSchema = srcCatalog.schemas[0]
        var destCache = CatalogCache(from: destCatalog)
        var destSchema = destCatalog.schemas[0]
        if dropObjects {
            for srcTable in srcSchema.tables {
                if srcTable.ignore {
                    continue
                }
                if isVirtualTable(srcTable) {
                    continue
                }
                let destTable = destCache.getTable(
                    schema: destSchema,
                    tableName: srcTable.tableName
                )
                if destTable == nil {
                    // DROP TABLE.
                    dropTables.append(srcTable)
                }
            }
        }
        for destTable in destSchema.tables {
            if destTable.ignore {
                continue
            }
            if isVirtualTable(destTable) {
                continue
            }
            guard
                let srcTable = srcCache.getTable(
                    schema: srcSchema,
                    tableName: destTable.tableName
                )
            else {
                // CREATE TABLE.
                createTables.append(destTable)
                continue
            }
            var alterTable = SQLiteAlterTable(
                srcTable: srcTable,
                destTable: destTable
            )
            for srcConstraint in srcTable.constraints {
                if srcConstraint.ignore {
                    continue
                }
                let destConstraint = destCache.getConstraint(
                    table: destTable,
                    constraintName: srcConstraint.constraintName
                )
                if destConstraint == nil {
                    // DROP CONSTRAINT.
                    alterTable.dropConstraints.append(srcConstraint)
                }
            }
            for srcIndex in srcTable.indexes {
                if srcIndex.ignore {
                    continue
                }
                let destIndex = destCache.getIndex(
                    table: destTable,
                    indexName: srcIndex.indexName
                )
                if destIndex == nil {
                    alterTable.dropIndexes.append(srcIndex)
                }
            }
            for srcColumn in srcTable.columns {
                if srcColumn.ignore {
                    continue
                }
                let destColumn = destCache.getColumn(
                    table: destTable,
                    columnName: srcColumn.columnName
                )
                if destColumn == nil {
                    // DROP COLUMN.
                    alterTable.dropColumns.append(srcColumn)
                    alterTable.columnIsDropped.insert(srcColumn.columnName)
                }
            }
            for destColumn in destTable.columns {
                if destColumn.ignore {
                    continue
                }
                guard
                    let srcColumn = srcCache.getColumn(
                        table: srcTable,
                        columnName: destColumn.columnName
                    )
                else {
                    // ADD COLUMN.
                    alterTable.addColumns.append(destColumn)
                    alterTable.columnIsAdded.insert(destColumn.columnName)
                    continue
                }
                let columnsAreDifferent = {
                    if srcColumn.columnType != destColumn.columnType {
                        return true
                    }
                    let srcDefault = normalizeColumnDefault(
                        columnDefault: srcColumn.columnDefault
                    )
                    let destDefault = normalizeColumnDefault(
                        columnDefault: destColumn.columnDefault
                    )
                    if srcDefault != destDefault {
                        return true
                    }
                    if srcColumn.isNotNull != destColumn.isNotNull {
                        return true
                    }
                    return false
                }()
                if columnsAreDifferent {
                    // ALTER COLUMN.
                    alterTable.alterColumns.append((srcColumn, destColumn))
                }
            }
            for destIndex in destTable.indexes {
                if destIndex.ignore {
                    continue
                }
                let srcIndex = srcCache.getIndex(
                    table: srcTable,
                    indexName: destIndex.indexName
                )
                if srcIndex == nil {
                    // CREATE INDEX.
                    alterTable.createIndexes.append(destIndex)
                }
            }
            for destConstraint in destTable.constraints {
                if destConstraint.ignore {
                    continue
                }
                let srcConstraint = srcCache.getConstraint(
                    table: srcTable,
                    constraintName: destConstraint.constraintName
                )
                if srcConstraint == nil {
                    // ADD CONSTRAINT.
                    alterTable.addConstraints.append(destConstraint)
                }
            }
            if !alterTable.dropConstraints.isEmpty
                || !alterTable.dropIndexes.isEmpty
                || !alterTable.addColumns.isEmpty
                || !alterTable.alterColumns.isEmpty
                || !alterTable.createIndexes.isEmpty
                || !alterTable.addConstraints.isEmpty
            {
                if dropObjects {
                    // If we are dropping objects, it is safe to run the alter table as-is.
                    alterTables.append(alterTable)
                } else {
                    // Else we run alter table only if we are adding any columns or
                    // creating any indexes -- the other operations all involve
                    // dropping objects. Zero them out so that only adding columns
                    // and creating indexes are left behind.
                    if !alterTable.addColumns.isEmpty
                        || !alterTable.createIndexes.isEmpty
                    {
                        alterTable.dropIndexes.removeAll()
                        alterTable.dropConstraints.removeAll()
                        alterTable.dropColumns.removeAll()
                        alterTable.alterColumns.removeAll()
                        alterTable.addConstraints.removeAll()
                        alterTables.append(alterTable)
                    }
                }
            }
        }
    }

    func sql(prefix: String) -> [(
        fileName: String, contents: String, warnings: String
    )] {
        return []
    }
    
    func copyTable() -> String {
        return ""
    }
}
