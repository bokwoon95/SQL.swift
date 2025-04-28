import Foundation
import SQLite3

public indirect enum BaseValue: Sendable, Equatable {
    case null
    case data(Data)
    case bool(Bool)
    case double(Double)
    case int(Int)
    case int64(Int64)
    case string(String)
    case date(Date)
    case uuid(UUID)
    case parameter(_ name: String, _ baseValue: BaseValue)
}

public indirect enum Value: Sendable, Equatable {
    case null
    case data(Data)
    case bool(Bool)
    case double(Double)
    case int(Int)
    case int64(Int64)
    case string(String)
    case date(Date)
    case uuid(UUID)
    case parameter(_ name: String, _ value: Value)
    case expression(_ sql: String, _ values: [Value])
    case list(_ values: [Value])

    func toBaseValue() -> BaseValue? {
        switch self {
        case .null:
            return .null
        case .data(let data):
            return .data(data)
        case .bool(let bool):
            return .bool(bool)
        case .double(let double):
            return .double(double)
        case .int(let int):
            return .int(int)
        case .int64(let int64):
            return .int64(int64)
        case .string(let string):
            return .string(string)
        case .date(let date):
            return .date(date)
        case .uuid(let uuid):
            return .uuid(uuid)
        case .parameter, .expression, .list:
            return nil
        }
    }

    public static func data(_ data: Data?) -> Self {
        return data == nil ? .null : .data(data!)
    }

    public static func bool(_ bool: Bool?) -> Self {
        return bool == nil ? .null : .bool(bool!)
    }

    public static func double(_ double: Double?) -> Self {
        return double == nil ? .null : .double(double!)
    }

    public static func int(_ int: Int?) -> Self {
        return int == nil ? .null : .int(int!)
    }

    public static func int64(_ int64: Int64?) -> Self {
        return int64 == nil ? .null : .int64(int64!)
    }

    public static func string(_ string: String?) -> Self {
        return string == nil ? .null : .string(string!)
    }

    public static func date(_ date: Date?) -> Self {
        return date == nil ? .null : .date(date!)
    }

    public static func uuid(_ uuid: UUID?) -> Self {
        return uuid == nil ? .null : .uuid(uuid!)
    }

    public static func expression(_ sql: String, _ values: Value...)
        -> Self
    {
        return .expression(sql, values)
    }

    public static func toList<T>(_ items: T...) -> Self? {
        return toList(items)
    }

    public static func toList<T>(_ items: [T]) -> Self? {
        var values: [Value] = []
        for item in items {
            guard let value = Value.from(item) else {
                return nil
            }
            values.append(value)
        }
        return .list(values)
    }

    init?(_ item: Any) {
        guard let value = Value.from(item) else {
            return nil
        }
        self = value
    }

    static func from(_ item: Any) -> Value? {
        switch item {
        case let data as Data:
            return .data(data)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let int64 as Int64:
            return .int64(int64)
        case let string as String:
            return .string(string)
        case let date as Date:
            return .date(date)
        case let uuid as UUID:
            return .uuid(uuid)
        case let value as Value:
            return value
        default:
            let mirror = Mirror(reflecting: item)
            if mirror.displayStyle != .collection {
                return nil
            }
            var values: [Value] = []
            for child in mirror.children {
                guard let value = Value.from(child.value) else {
                    return nil
                }
                values.append(value)
            }
            return .list(values)
        }
    }
}

func appendValue(
    baseSQL: inout String,
    baseValues: inout [BaseValue],
    parameterIndices: inout [String: [Int]],
    value: Value
)
    throws
{
    switch value {
    case .null, .data, .bool, .double, .int, .int64, .string, .date, .uuid:
        baseSQL.append(":\(baseValues.count+1)")
        baseValues.append(value.toBaseValue()!)
    case .parameter(let name, let value):
        switch value {
        case .null, .data, .bool, .double, .int, .int64, .string, .date, .uuid:
            if let indices = parameterIndices[name] {
                baseSQL.append(":\(name)")
                for index in indices {
                    baseValues[index] = .parameter(
                        name,
                        value.toBaseValue()!
                    )
                }
            } else {
                baseSQL.append(":\(name)")
                baseValues.append(.parameter(name, value.toBaseValue()!))
                parameterIndices[name] = [baseValues.count - 1]
            }
        case .parameter, .expression, .list:
            try appendValue(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                value: value
            )
        }
    case .expression(let sql, let values):
        try appendSQL(
            baseSQL: &baseSQL,
            baseValues: &baseValues,
            parameterIndices: &parameterIndices,
            sql: sql,
            values: values
        )
    case .list(let values):
        for (i, value) in values.enumerated() {
            if i > 0 {
                baseSQL.append(", ")
            }
            try appendValue(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                value: value
            )
        }
    }
}

func appendSQL(
    baseSQL: inout String,
    baseValues: inout [BaseValue],
    parameterIndices: inout [String: [Int]],
    sql: String,
    values: [Value]
) throws {
    var anonymousIndex = 0
    var ordinalIndex: [Int: Int] = [:]
    try internalAppendSQL(
        baseSQL: &baseSQL,
        baseValues: &baseValues,
        parameterIndices: &parameterIndices,
        sql: sql,
        values: values,
        anonymousIndex: &anonymousIndex,
        ordinalIndex: &ordinalIndex
    )
}

public struct QueryBuildingError: Error {
    public let errmsg: String
    public let sql: String
    public let values: [Value]
}

func internalAppendSQL(
    baseSQL: inout String,
    baseValues: inout [BaseValue],
    parameterIndices: inout [String: [Int]],
    sql: String,
    values: [Value],
    anonymousIndex: inout Int,
    ordinalIndex: inout [Int: Int]
) throws {
    var parameterIndex: [String: Int] = [:]
    for (i, value) in values.enumerated() {
        guard case .parameter(let name, _) = value else {
            continue
        }
        if name.isEmpty {
            throw QueryBuildingError(
                errmsg:
                    "parameter name cannot be empty",
                sql: sql,
                values: values
            )
        }
        if parameterIndex[name] != nil {
            throw QueryBuildingError(
                errmsg:
                    "parameter name {\(name)} provided more than once",
                sql: sql,
                values: values
            )
        }
        parameterIndex[name] = i
    }
    let validParameterNameCharacters = CharacterSet(
        charactersIn: "a"..."z"
    )
    .union(CharacterSet(charactersIn: "A"..."Z"))
    .union(CharacterSet(charactersIn: "0"..."9"))
    .union(CharacterSet(charactersIn: "_"))
    var remainder = sql
    while !remainder.isEmpty {
        let character = remainder.removeFirst()
        if character != "{" {
            baseSQL.append(character)
            continue
        }
        if remainder.first == "{" {
            remainder.removeFirst()
            baseSQL.append("{")
            continue
        }
        guard let range = remainder.range(of: "}") else {
            throw QueryBuildingError(
                errmsg: "no matching '}' found",
                sql: sql,
                values: values
            )
        }
        let parameterName = String(remainder[..<range.lowerBound])
        remainder = String(remainder[range.upperBound...])
        if !parameterName.isEmpty
            && !parameterName.unicodeScalars.allSatisfy({ character in
                validParameterNameCharacters.contains(character)
            })
        {
            throw QueryBuildingError(
                errmsg:
                    "\(parameterName) is not a valid parameter name (only letters, digits and '_' are allowed)",
                sql: sql,
                values: values
            )
        }

        // is it an anonymous placeholder? e.g. {}
        if parameterName.isEmpty {
            if anonymousIndex >= values.count {
                throw QueryBuildingError(
                    errmsg:
                        "too few values passed in, expected more than \(anonymousIndex)",
                    sql: sql,
                    values: values
                )
            }
            let value = values[anonymousIndex]
            anonymousIndex += 1
            try appendValue(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                value: value
            )
            continue
        }

        // is it an ordinal placeholder? e.g. {1}, {2}, {3}
        if let ordinal = Int(parameterName) {
            let index = ordinal - 1
            if index < 0 || index >= values.count {
                throw QueryBuildingError(
                    errmsg:
                        "ordinal parameter {\(ordinal)} is out of bounds",
                    sql: sql,
                    values: values
                )
            }
            let value = values[index]
            switch value {
            case .null, .data, .bool, .double, .int, .int64, .string, .date,
                .uuid:
                if let index = ordinalIndex[ordinal] {
                    baseSQL.append(":\(index+1)")
                } else {
                    baseValues.append(value.toBaseValue()!)
                    let index = baseValues.count - 1
                    ordinalIndex[ordinal] = index
                    baseSQL.append(":\(index+1)")
                }
            case .parameter, .expression, .list:
                try appendValue(
                    baseSQL: &baseSQL,
                    baseValues: &baseValues,
                    parameterIndices: &parameterIndices,
                    value: value
                )
            }
            continue
        }

        // is it a named placeholder? e.g. {name}, {age}, {email}
        if let index = parameterIndex[parameterName] {
            let value = values[index]
            try appendValue(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                value: value
            )
            continue
        }
        if parameterIndex.isEmpty {
            throw QueryBuildingError(
                errmsg:
                    "parameter name {\(parameterName)} not provided",
                sql: sql,
                values: values
            )
        }
        throw QueryBuildingError(
            errmsg:
                "parameter name {\(parameterName)} not provided (available names: \(parameterIndex.keys.joined(separator: ", "))",
            sql: sql,
            values: values
        )
    }
}

public struct Query: Sendable, Equatable {
    public let baseSQL: String
    public let baseValues: [BaseValue]
    public let parameterIndices: [String: [Int]]

    init(sql: String, values: [Value]) throws {
        try self.init(sql: sql, values: values, fetchExpressions: [])
    }

    internal init(
        sql: String,
        values: [Value],
        fetchExpressions: [Value]
    ) throws {
        var baseSQL = ""
        var baseValues: [BaseValue] = []
        var parameterIndices: [String: [Int]] = [:]
        var head = ""
        var tail = sql
        var found = false
        while !tail.isEmpty {
            if tail.hasPrefix("{*}") && head.last != "{" {
                tail = String(tail.dropFirst("{*}".count))
                found = true
                break
            }
            head.append(tail.removeFirst())
        }
        if !found {
            try appendSQL(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                sql: sql,
                values: values
            )
            self.baseSQL = baseSQL
            self.baseValues = baseValues
            self.parameterIndices = parameterIndices
            return
        }
        var anonymousIndex = 0
        var ordinalIndex: [Int: Int] = [:]
        try internalAppendSQL(
            baseSQL: &baseSQL,
            baseValues: &baseValues,
            parameterIndices: &parameterIndices,
            sql: head,
            values: values,
            anonymousIndex: &anonymousIndex,
            ordinalIndex: &ordinalIndex
        )
        for (i, expression) in fetchExpressions.enumerated() {
            if i > 0 {
                baseSQL += ", "
            }
            try appendValue(
                baseSQL: &baseSQL,
                baseValues: &baseValues,
                parameterIndices: &parameterIndices,
                value: expression
            )
        }
        try internalAppendSQL(
            baseSQL: &baseSQL,
            baseValues: &baseValues,
            parameterIndices: &parameterIndices,
            sql: tail,
            values: values,
            anonymousIndex: &anonymousIndex,
            ordinalIndex: &ordinalIndex
        )
        self.baseSQL = baseSQL
        self.baseValues = baseValues
        self.parameterIndices = parameterIndices
    }

    internal init(
        baseSQL: String,
        baseValues: [BaseValue],
        parameterIndices: [String: [Int]]
    ) {
        self.baseSQL = baseSQL
        self.baseValues = baseValues
        self.parameterIndices = parameterIndices
    }
}

public struct ConversionError: Error {
    public let expression: Value
    public let wantType: Any.Type
    public let gotType: Any.Type
    public let value: BaseValue
}

let timestampFormats: [String] = [
    "yyyy-MM-dd HH:mm:ss.SSSSSSSSSZZZZZ",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSZZZZZ",
    "yyyy-MM-dd HH:mm:ss.SSSSSSSSS",
    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd'T'HH:mm:ss",
    "yyyy-MM-dd HH:mm",
    "yyyy-MM-dd'T'HH:mm",
    "yyyy-MM-dd",
]

public struct Row {
    var statementPointer: OpaquePointer?
    var index: Int32 = 0
    var fetchExpressions: [Value] = []

    public mutating func data(_ sql: String, _ values: Value...) throws
        -> Data?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            return Data(
                bytes: sqlite3_column_blob(statementPointer, index),
                count: Swift.Int(
                    sqlite3_column_bytes(statementPointer, index)
                )
            )
        case SQLITE_TEXT:
            return Swift.String(
                cString: sqlite3_column_text(statementPointer, index)
            )
            .data(using: .utf8)
        case SQLITE_FLOAT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Data.self,
                gotType: Double.self,
                value: .double(
                    sqlite3_column_double(statementPointer, index)
                )
            )
        case SQLITE_INTEGER:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Data.self,
                gotType: Int64.self,
                value: .int64(sqlite3_column_int64(statementPointer, index))
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func bool(_ sql: String, _ values: Value...) throws
        -> Bool?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Bool.self,
                gotType: Data.self,
                value: .data(
                    Data(
                        bytes: sqlite3_column_blob(statementPointer, index),
                        count: Swift.Int(
                            sqlite3_column_bytes(statementPointer, index)
                        )
                    )
                )
            )
        case SQLITE_TEXT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Bool.self,
                gotType: String.self,
                value: .string(
                    Swift.String(
                        cString: sqlite3_column_text(
                            statementPointer,
                            index
                        )
                    )
                )
            )
        case SQLITE_FLOAT:
            return sqlite3_column_double(statementPointer, index) != 0
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statementPointer, index) != 0
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func double(_ sql: String, _ values: Value...) throws
        -> Double?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Double.self,
                gotType: Data.self,
                value: .data(
                    Data(
                        bytes: sqlite3_column_blob(statementPointer, index),
                        count: Swift.Int(
                            sqlite3_column_bytes(statementPointer, index)
                        )
                    )
                )
            )
        case SQLITE_TEXT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Double.self,
                gotType: String.self,
                value: .string(
                    Swift.String(
                        cString: sqlite3_column_text(
                            statementPointer,
                            index
                        )
                    )
                )
            )
        case SQLITE_FLOAT:
            return sqlite3_column_double(statementPointer, index)
        case SQLITE_INTEGER:
            return Swift.Double(sqlite3_column_int64(statementPointer, index))
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func int(_ sql: String, _ values: Value...) throws
        -> Int?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Int.self,
                gotType: Data.self,
                value: .data(
                    Data(
                        bytes: sqlite3_column_blob(statementPointer, index),
                        count: Swift.Int(
                            sqlite3_column_bytes(statementPointer, index)
                        )
                    )
                )
            )
        case SQLITE_TEXT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Int.self,
                gotType: String.self,
                value: .string(
                    Swift.String(
                        cString: sqlite3_column_text(
                            statementPointer,
                            index
                        )
                    )
                )
            )
        case SQLITE_FLOAT:
            return Swift.Int(sqlite3_column_double(statementPointer, index))
        case SQLITE_INTEGER:
            return Swift.Int(
                truncatingIfNeeded: sqlite3_column_int64(
                    statementPointer,
                    index
                )
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func int64(_ sql: String, _ values: Value...) throws
        -> Int64?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Int64.self,
                gotType: Data.self,
                value: .data(
                    Data(
                        bytes: sqlite3_column_blob(statementPointer, index),
                        count: Swift.Int(
                            sqlite3_column_bytes(statementPointer, index)
                        )
                    )
                )
            )
        case SQLITE_TEXT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Int64.self,
                gotType: String.self,
                value: .string(
                    Swift.String(
                        cString: sqlite3_column_text(
                            statementPointer,
                            index
                        )
                    )
                )
            )
        case SQLITE_FLOAT:
            return Swift.Int64(
                sqlite3_column_double(statementPointer, index)
            )
        case SQLITE_INTEGER:
            return Swift.Int64(
                sqlite3_column_int64(statementPointer, index)
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func string(_ sql: String, _ values: Value...) throws
        -> String?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            return Swift.String(
                data: Data(
                    bytes: sqlite3_column_blob(statementPointer, index),
                    count: Swift.Int(
                        sqlite3_column_bytes(statementPointer, index)
                    )
                ),
                encoding: .utf8
            )
        case SQLITE_TEXT:
            return Swift.String(
                cString: sqlite3_column_text(statementPointer, index)
            )
        case SQLITE_FLOAT:
            return Swift.String(
                sqlite3_column_double(statementPointer, index)
            )
        case SQLITE_INTEGER:
            return Swift.String(
                sqlite3_column_int64(statementPointer, index)
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func date(_ sql: String, _ values: Value...) throws
        -> Date?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Date.self,
                gotType: Data.self,
                value: .data(
                    Data(
                        bytes: sqlite3_column_blob(statementPointer, index),
                        count: Swift.Int(
                            sqlite3_column_bytes(statementPointer, index)
                        )
                    )
                )
            )
        case SQLITE_TEXT:
            let value = Swift.String(
                cString: sqlite3_column_text(statementPointer, index)
            )
            let valueWithoutZSuffix =
                value.hasSuffix("Z") ? String(value.dropLast()) : value
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            for format in timestampFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: valueWithoutZSuffix) {
                    return date
                }
            }
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: Date.self,
                gotType: String.self,
                value: .string(value)
            )
        case SQLITE_FLOAT:
            return Date(
                timeIntervalSince1970: sqlite3_column_double(
                    statementPointer,
                    index
                )
            )
        case SQLITE_INTEGER:
            return Date(
                timeIntervalSince1970: Double(
                    sqlite3_column_int64(statementPointer, index)
                )
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }

    public mutating func uuid(_ sql: String, _ values: Value...) throws
        -> UUID?
    {
        if statementPointer == nil {
            fetchExpressions.append(.expression(sql, values))
            return nil
        }
        defer {
            index += 1
        }
        switch sqlite3_column_type(statementPointer, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_BLOB:
            let value = Data(
                bytes: sqlite3_column_blob(statementPointer, index),
                count: Swift.Int(
                    sqlite3_column_bytes(statementPointer, index)
                )
            )
            if value.count != 16 {
                throw ConversionError(
                    expression: fetchExpressions[Int(index)],
                    wantType: UUID.self,
                    gotType: Data.self,
                    value: .data(value)
                )
            }
            return UUID(
                uuid: (
                    value[0], value[1], value[2], value[3],
                    value[4], value[5], value[6], value[7],
                    value[8], value[9], value[10], value[11],
                    value[12], value[13], value[14], value[15]
                )
            )
        case SQLITE_TEXT:
            let value = Swift.String(
                cString: sqlite3_column_text(statementPointer, index)
            )
            guard let uuid = UUID(uuidString: value) else {
                throw ConversionError(
                    expression: fetchExpressions[Int(index)],
                    wantType: UUID.self,
                    gotType: String.self,
                    value: .string(value)
                )
            }
            return uuid
        case SQLITE_FLOAT:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: UUID.self,
                gotType: Double.self,
                value: .double(
                    sqlite3_column_double(statementPointer, index)
                )
            )
        case SQLITE_INTEGER:
            throw ConversionError(
                expression: fetchExpressions[Int(index)],
                wantType: UUID.self,
                gotType: Int64.self,
                value: .int64(sqlite3_column_int64(statementPointer, index))
            )
        default:
            assertionFailure("unreachable")
            return nil
        }
    }
}

public struct SQLiteError: Error {
    public let errmsg: String
    public let errstr: String
    public let resultCode: Int32
    public var primaryResultCode: Int32 { resultCode & 0xFF }
    public let baseSQL: String?
    public let baseValues: [BaseValue]?
    public let errorOffset: Int32

    init(
        _ connectionPointer: OpaquePointer,
        _ baseSQL: String?,
        _ baseValues: [BaseValue]?
    ) {
        let resultCode = sqlite3_extended_errcode(connectionPointer)
        self.errmsg = String(cString: sqlite3_errmsg(connectionPointer))
        self.errstr = String(cString: sqlite3_errstr(resultCode))
        self.resultCode = resultCode
        self.baseSQL = baseSQL
        self.baseValues = baseValues
        self.errorOffset = {
            if #available(iOS 16.0, macOS 13.0, *) {
                return sqlite3_error_offset(connectionPointer)
            }
            return -1
        }()
    }
}

class Pool<T> {
    var elements: [T] = []
    let semaphore = DispatchSemaphore(value: 0)
    let queue = DispatchQueue(label: "SQL.Pool.queue")

    func get() -> T {
        semaphore.wait()
        return queue.sync {
            return elements.removeLast()
        }
    }

    func put(_ element: T) {
        queue.sync {
            elements.append(element)
        }
        semaphore.signal()
    }
}

public struct Cursor<T> {
    let connectionPointer: OpaquePointer
    let connectionPointerPool: Pool<OpaquePointer>
    var row: Row
    let rowmapper: (_ row: inout Row) throws -> T
    let query: Query
    let finalizeStatementPointerOnCursorClose: Bool
    let returnConnectionPointerOnCursorClose: Bool
    var isClosed = false

    mutating func next() throws -> T? {
        switch sqlite3_step(row.statementPointer) {
        case SQLITE_DONE:
            close()
            return nil
        case SQLITE_ROW:
            row.index = 0
            return try rowmapper(&row)
        default:
            close()
            throw SQLiteError(
                connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
    }

    mutating func close() {
        if isClosed {
            return
        }
        isClosed = true
        if finalizeStatementPointerOnCursorClose {
            sqlite3_finalize(row.statementPointer)
        } else {
            sqlite3_reset(row.statementPointer)
            sqlite3_clear_bindings(row.statementPointer)
        }
        if returnConnectionPointerOnCursorClose {
            connectionPointerPool.put(connectionPointer)
        }
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

func bindBaseValue(
    connectionPointer: OpaquePointer,
    statementPointer: OpaquePointer?,
    bindIndex: Int32,
    baseValue: BaseValue,
    recursing: Bool = false
) throws -> Int32 {
    switch baseValue {
    case .null:
        return sqlite3_bind_null(statementPointer, bindIndex)
    case .data(let data):
        return data.withUnsafeBytes { bytes in
            return sqlite3_bind_blob(
                statementPointer,
                bindIndex,
                bytes.baseAddress,
                Int32(bytes.count),
                SQLITE_TRANSIENT
            )
        }
    case .bool(let bool):
        return sqlite3_bind_int64(
            statementPointer,
            bindIndex,
            bool ? 1 : 0
        )
    case .double(let double):
        return sqlite3_bind_double(
            statementPointer,
            bindIndex,
            double
        )
    case .int(let int):
        return sqlite3_bind_int64(
            statementPointer,
            bindIndex,
            Int64(int)
        )
    case .int64(let int64):
        return sqlite3_bind_int64(
            statementPointer,
            bindIndex,
            int64
        )
    case .string(let string):
        return sqlite3_bind_text(
            statementPointer,
            bindIndex,
            string,
            -1,
            SQLITE_TRANSIENT
        )
    case .date(let date):
        return sqlite3_bind_int64(
            statementPointer,
            bindIndex,
            Int64(date.timeIntervalSince1970)
        )
    case .uuid(let uuid):
        var uuidBytes = uuid.uuid
        return sqlite3_bind_blob(
            statementPointer,
            bindIndex,
            &uuidBytes,
            Int32(MemoryLayout.size(ofValue: uuidBytes)),
            SQLITE_TRANSIENT
        )
    case .parameter(let name, let baseValue):
        let parameterIndex = sqlite3_bind_parameter_index(
            statementPointer,
            ":" + name
        )
        return try bindBaseValue(
            connectionPointer: connectionPointer,
            statementPointer: statementPointer,
            bindIndex: recursing
                ? bindIndex
                : parameterIndex,
            baseValue: baseValue,
            recursing: true
        )
    }
}

public struct Connection {
    public let connectionPointer: OpaquePointer
    let connectionPointerPool: Pool<OpaquePointer>
    let returnConnectionPointerOnCursorClose: Bool

    init(
        connectionPointer: OpaquePointer,
        connectionPointerPool: Pool<OpaquePointer>,
        returnConnectionPointerOnCursorClose: Bool
    ) {
        self.connectionPointer = connectionPointer
        self.connectionPointerPool = connectionPointerPool
        self.returnConnectionPointerOnCursorClose =
            returnConnectionPointerOnCursorClose
    }

    func fetchCursor<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        _ rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws -> Cursor<T> {
        var row = Row()
        try _ = rowmapper(&row)
        let query = try Query(
            sql: sql,
            values: values,
            fetchExpressions: row.fetchExpressions
        )
        var statementPointer: OpaquePointer?
        let resultCode = sqlite3_prepare_v2(
            connectionPointer,
            query.baseSQL,
            -1,
            &statementPointer,
            nil
        )
        if resultCode != SQLITE_OK {
            throw SQLiteError(
                connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
        row.statementPointer = statementPointer
        for (i, baseValue) in query.baseValues.enumerated() {
            let resultCode = try bindBaseValue(
                connectionPointer: connectionPointer,
                statementPointer: statementPointer,
                bindIndex: Int32(i + 1),
                baseValue: baseValue
            )
            if resultCode != SQLITE_OK {
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
        }
        return Cursor(
            connectionPointer: connectionPointer,
            connectionPointerPool: connectionPointerPool,
            row: row,
            rowmapper: rowmapper,
            query: query,
            finalizeStatementPointerOnCursorClose: true,
            returnConnectionPointerOnCursorClose:
                returnConnectionPointerOnCursorClose,
        )
    }

    func fetchOne<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws -> T? {
        var cursor = try fetchCursor(
            sql: sql,
            values: values,
            debug: debug,
            rowmapper
        )
        defer {
            cursor.close()
        }
        if let result = try cursor.next() {
            return result
        }
        return nil
    }

    func fetchAll<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws -> [T] {
        var cursor = try fetchCursor(
            sql: sql,
            values: values,
            debug: debug,
            rowmapper
        )
        defer {
            cursor.close()
        }
        var results: [T] = []
        while let result = try cursor.next() {
            results.append(result)
        }
        return results
    }

    func fetchExists(
        sql: String,
        values: [Value] = [],
        debug: Bool = false
    ) throws -> Bool {
        let query = try Query(sql: sql, values: values)
        var statementPointer: OpaquePointer?
        let resultCode = sqlite3_prepare_v2(
            connectionPointer,
            "SELECT EXISTS (" + query.baseSQL + ")",
            -1,
            &statementPointer,
            nil
        )
        if resultCode != SQLITE_OK {
            throw SQLiteError(
                connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
        for (i, baseValues) in query.baseValues.enumerated() {
            let resultCode = try bindBaseValue(
                connectionPointer: connectionPointer,
                statementPointer: statementPointer,
                bindIndex: Int32(i + 1),
                baseValue: baseValues
            )
            if resultCode != SQLITE_OK {
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
        }
        defer {
            sqlite3_finalize(statementPointer)
        }
        switch sqlite3_step(statementPointer) {
        case SQLITE_DONE:
            return false
        case SQLITE_ROW:
            return sqlite3_column_int64(statementPointer, 0) != 0
        default:
            throw SQLiteError(
                connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
    }

    func execute(_ sql: String) throws {
        _ = try execute(sql: sql, values: [], debug: false)
    }

    func execute(sql: String, values: [Value] = [], debug: Bool = false)
        throws -> (lastInsertId: Int64, rowsAffected: Int64)
    {
        let query = try Query(sql: sql, values: values)
        return try query.baseSQL.withCString { body in
            var zSql = body
            var statementPointer: OpaquePointer?
            var pzTail: UnsafePointer<CChar>?
            let resultCode = sqlite3_prepare_v2(
                connectionPointer,
                zSql,
                -1,
                &statementPointer,
                &pzTail
            )
            if resultCode != SQLITE_OK {
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
            for (i, baseValue) in query.baseValues.enumerated() {
                let resultCode = try bindBaseValue(
                    connectionPointer: connectionPointer,
                    statementPointer: statementPointer,
                    bindIndex: Int32(i + 1),
                    baseValue: baseValue
                )
                if resultCode != SQLITE_OK {
                    throw SQLiteError(
                        connectionPointer,
                        query.baseSQL,
                        query.baseValues
                    )
                }
            }
            switch sqlite3_step(statementPointer) {
            case SQLITE_DONE, SQLITE_ROW:
                sqlite3_finalize(statementPointer)
            default:
                sqlite3_finalize(statementPointer)
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
            let lastInsertId = sqlite3_last_insert_rowid(connectionPointer)
            let rowsAffected = {
                if #available(iOS 15.4, macOS 12.3, *) {
                    return sqlite3_changes64(connectionPointer)
                }
                return -1
            }()
            while pzTail != nil && pzTail!.pointee != 0 {
                zSql = pzTail!
                var statementPointer: OpaquePointer?
                let resultCode = sqlite3_prepare_v2(
                    connectionPointer,
                    zSql,
                    -1,
                    &statementPointer,
                    &pzTail
                )
                if resultCode != SQLITE_OK {
                    throw SQLiteError(
                        connectionPointer,
                        query.baseSQL,
                        query.baseValues
                    )
                }
                if statementPointer == nil {
                    continue
                }
                switch sqlite3_step(statementPointer) {
                case SQLITE_DONE, SQLITE_ROW:
                    sqlite3_finalize(statementPointer)
                default:
                    sqlite3_finalize(statementPointer)
                    throw SQLiteError(
                        connectionPointer,
                        query.baseSQL,
                        query.baseValues
                    )
                }
            }
            return (lastInsertId: lastInsertId, rowsAffected: rowsAffected)
        }
    }
}

public struct PreparedFetch<T> {
    var row: Row
    let rowmapper: (_ row: inout Row) throws -> T
    let debug: Bool
    let connectionPointer: OpaquePointer
    let connectionPointerPool: Pool<OpaquePointer>
    let returnConnectionPointerOnClose: Bool
    let query: Query

    init(
        connection: Connection,
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        _ rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws {
        self.row = Row()
        self.rowmapper = rowmapper
        self.debug = debug
        self.connectionPointer = connection.connectionPointer
        self.connectionPointerPool = connection.connectionPointerPool
        self.returnConnectionPointerOnClose =
            connection.returnConnectionPointerOnCursorClose
        try _ = rowmapper(&self.row)
        self.query = try Query(
            sql: sql,
            values: values,
            fetchExpressions: row.fetchExpressions
        )
        var statementPointer: OpaquePointer?
        let resultCode = sqlite3_prepare_v2(
            connectionPointer,
            query.baseSQL,
            -1,
            &statementPointer,
            nil
        )
        if resultCode != SQLITE_OK {
            throw SQLiteError(
                self.connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
        row.statementPointer = statementPointer!
    }

    func close() {
        sqlite3_finalize(row.statementPointer)
        if returnConnectionPointerOnClose {
            connectionPointerPool.put(connectionPointer)
        }
    }

    func fetchCursor(
        _ parameters: [String: BaseValue]
    ) throws -> Cursor<T> {
        var baseValues = query.baseValues
        for (name, baseValue) in parameters {
            guard let indices = query.parameterIndices[name] else {
                continue
            }
            for index in indices {
                switch query.baseValues[index] {
                case .null, .data, .bool, .double, .int, .int64, .string, .date,
                    .uuid:
                    baseValues[index] = baseValue
                case .parameter(let name, _):
                    baseValues[index] = .parameter(name, baseValue)
                }
            }
        }
        for (i, baseValue) in baseValues.enumerated() {
            let resultCode = try bindBaseValue(
                connectionPointer: connectionPointer,
                statementPointer: row.statementPointer,
                bindIndex: Int32(i + 1),
                baseValue: baseValue
            )
            if resultCode != SQLITE_OK {
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
        }
        return Cursor(
            connectionPointer: connectionPointer,
            connectionPointerPool: connectionPointerPool,
            row: row,
            rowmapper: rowmapper,
            query: query,
            finalizeStatementPointerOnCursorClose: false,
            returnConnectionPointerOnCursorClose: false
        )
    }

    func fetchOne(
        _ parameters: [String: BaseValue]
    ) throws -> T? {
        var cursor = try fetchCursor(parameters)
        defer {
            cursor.close()
        }
        if let result = try cursor.next() {
            return result
        }
        return nil
    }

    func fetchAll(_ parameters: [String: BaseValue]) throws -> [T] {
        var cursor = try fetchCursor(parameters)
        defer {
            cursor.close()
        }
        var results: [T] = []
        while let result = try cursor.next() {
            results.append(result)
        }
        return results
    }
}

public struct PreparedExecute {
    let connectionPointer: OpaquePointer
    let debug: Bool
    let query: Query
    let statementPointer: OpaquePointer

    init(
        connection: Connection,
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
    ) throws {
        self.debug = debug
        self.connectionPointer = connection.connectionPointer
        self.query = try Query(
            sql: sql,
            values: values,
            fetchExpressions: []
        )
        var statementPointer: OpaquePointer?
        let resultCode = sqlite3_prepare_v2(
            connectionPointer,
            query.baseSQL,
            -1,
            &statementPointer,
            nil
        )
        if resultCode != SQLITE_OK {
            throw SQLiteError(
                self.connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
        self.statementPointer = statementPointer!
    }

    func close() {
        sqlite3_finalize(statementPointer)
    }

    func execute(_ parameters: [String: BaseValue]) throws -> (
        lastInsertId: Int64, rowsAffected: Int64
    ) {
        defer {
            sqlite3_reset(statementPointer)
            sqlite3_clear_bindings(statementPointer)
        }
        var baseValues = query.baseValues
        for (name, baseValue) in parameters {
            guard let indices = query.parameterIndices[name] else {
                continue
            }
            for index in indices {
                switch query.baseValues[index] {
                case .null, .data, .bool, .double, .int, .int64, .string, .date,
                    .uuid:
                    baseValues[index] = baseValue
                case .parameter(let name, _):
                    baseValues[index] = .parameter(name, baseValue)
                }
            }
        }
        for (i, baseValue) in baseValues.enumerated() {
            let resultCode = try bindBaseValue(
                connectionPointer: connectionPointer,
                statementPointer: statementPointer,
                bindIndex: Int32(i + 1),
                baseValue: baseValue
            )
            if resultCode != SQLITE_OK {
                throw SQLiteError(
                    connectionPointer,
                    query.baseSQL,
                    query.baseValues
                )
            }
        }
        switch sqlite3_step(statementPointer) {
        case SQLITE_DONE, SQLITE_ROW:
            break
        default:
            throw SQLiteError(
                connectionPointer,
                query.baseSQL,
                query.baseValues
            )
        }
        let lastInsertId = sqlite3_last_insert_rowid(connectionPointer)
        let rowsAffected = {
            if #available(iOS 15.4, macOS 12.3, *) {
                return sqlite3_changes64(connectionPointer)
            }
            return -1
        }()
        return (lastInsertId: lastInsertId, rowsAffected: rowsAffected)
    }
}

public struct Database {
    let writeLock = NSLock()
    let writeConnectionPointer: OpaquePointer
    let connectionPointerPool = Pool<OpaquePointer>()

    init(
        filename: String,
        poolSize: Int = 2,
        connectionDidOpen: (
            (Connection) throws -> Void
        )? = nil,
    ) throws {
        var writeConnectionPointer: OpaquePointer?
        let resultCode = sqlite3_open_v2(
            filename,
            &writeConnectionPointer,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI,
            nil
        )
        if resultCode != SQLITE_OK {
            defer { sqlite3_close_v2(writeConnectionPointer) }
            throw SQLiteError(writeConnectionPointer!, nil, nil)

        }
        if let connectionDidOpen = connectionDidOpen {
            let writeConnection = Connection(
                connectionPointer: writeConnectionPointer!,
                connectionPointerPool: connectionPointerPool,
                returnConnectionPointerOnCursorClose: false,
            )
            try connectionDidOpen(writeConnection)
        }
        self.writeConnectionPointer = writeConnectionPointer!
        for _ in 0..<poolSize {
            var readConnectionPointer: OpaquePointer?
            let resultCode = sqlite3_open_v2(
                filename,
                &readConnectionPointer,
                SQLITE_OPEN_READONLY | SQLITE_OPEN_URI,
                nil
            )
            if resultCode != SQLITE_OK {
                defer { sqlite3_close_v2(readConnectionPointer) }
                throw SQLiteError(readConnectionPointer!, nil, nil)
            }
            if let connectionDidOpen = connectionDidOpen {
                let readConnection = Connection(
                    connectionPointer: readConnectionPointer!,
                    connectionPointerPool: connectionPointerPool,
                    returnConnectionPointerOnCursorClose: false,
                )
                try connectionDidOpen(readConnection)
            }
            connectionPointerPool.put(readConnectionPointer!)
        }
    }

    mutating func close() {
        sqlite3_close_v2(writeConnectionPointer)
        for readConnectionPointer in connectionPointerPool.elements {
            sqlite3_close_v2(readConnectionPointer)
        }
    }

    mutating public func fetchCursor<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        _ rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws -> Cursor<T> {
        let readConnectionPointer = connectionPointerPool.get()
        let readConnection = Connection(
            connectionPointer: readConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: true,
        )
        return try readConnection.fetchCursor(
            sql: sql,
            values: values,
            debug: debug,
            rowmapper
        )
    }

    mutating public func fetchOne<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        _ rowmapper: @escaping (_ row: inout Row) throws -> T
    ) throws -> T? {
        let readConnectionPointer = connectionPointerPool.get()
        defer {
            connectionPointerPool.put(readConnectionPointer)
        }
        let readConnection = Connection(
            connectionPointer: readConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try readConnection.fetchOne(
            sql: sql,
            values: values,
            debug: debug,
            rowmapper: rowmapper
        )
    }

    mutating public func fetchAll<T>(
        sql: String,
        values: [Value] = [],
        debug: Bool = false,
        _ rowmapper: @escaping (inout Row) throws -> T
    ) throws -> [T] {
        let readConnectionPointer = connectionPointerPool.get()
        defer {
            connectionPointerPool.put(readConnectionPointer)
        }
        let readConnection = Connection(
            connectionPointer: readConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try readConnection.fetchAll(
            sql: sql,
            values: values,
            debug: debug,
            rowmapper: rowmapper
        )
    }

    mutating public func fetchExists(
        _ sql: String,
        _ values: [Value] = [],
        debug: Bool = false
    ) throws -> Bool {
        let readConnectionPointer = connectionPointerPool.get()
        defer {
            connectionPointerPool.put(readConnectionPointer)
        }
        let readConnection = Connection(
            connectionPointer: readConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try readConnection.fetchExists(
            sql: sql,
            values: values,
            debug: debug
        )
    }

    mutating public func execute(_ sql: String) throws {
        _ = try execute(sql: sql, values: [], debug: false)
    }

    mutating public func execute(
        sql: String,
        values: [Value] = [],
        debug: Bool = false
    ) throws -> (lastInsertId: Int64, rowsAffected: Int64) {
        writeLock.lock()
        defer {
            writeLock.unlock()
        }
        let writeConnection = Connection(
            connectionPointer: writeConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try writeConnection.execute(
            sql: sql,
            values: values,
            debug: debug
        )
    }

    mutating public func read<T>(_ fn: @escaping (Connection) throws -> T)
        rethrows -> T
    {
        let readConnectionPointer = connectionPointerPool.get()
        defer {
            connectionPointerPool.put(readConnectionPointer)
        }
        let readConnection = Connection(
            connectionPointer: writeConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try fn(readConnection)
    }

    mutating public func write<T>(
        _ fn: @escaping (Connection) throws -> T
    ) rethrows -> T {
        writeLock.lock()
        defer {
            writeLock.unlock()
        }
        let writeConnection = Connection(
            connectionPointer: writeConnectionPointer,
            connectionPointerPool: connectionPointerPool,
            returnConnectionPointerOnCursorClose: false
        )
        return try fn(writeConnection)
    }
}
