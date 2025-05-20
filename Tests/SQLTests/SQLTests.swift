import Foundation
import SQLite3
import Testing

@testable import SQL

@Suite class TestQuery {
    @Test func empty() throws {
        let gotQuery = try Query(sql: "", values: [])
        let wantQuery = Query(
            baseSQL: "",
            baseValues: [],
            parameterIndices: [:]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func escapeCurlyBracket() throws {
        let gotQuery = try Query(
            sql: "SELECT {} = '{{}'",
            values: [.string("{}")]
        )
        let wantQuery = Query(
            baseSQL: "SELECT :1 = '{}'",
            baseValues: [.string("{}")],
            parameterIndices: [:]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func expression() throws {
        let gotQuery = try Query(
            sql:
                "(MAX(AVG({one}), AVG({two}), SUM({three})) + {incr}) IN ({list})",
            values: [
                .parameter("one", .expression("user_id")),
                .parameter("two", .expression("age")),
                .parameter("three", .expression("age")),
                .parameter("incr", .int(1)),
                .parameter("list", .toValues(1, 2, 3)!),
            ]
        )
        let wantQuery = Query(
            baseSQL:
                "(MAX(AVG(user_id), AVG(age), SUM(age)) + :incr) IN (:2, :3, :4)",
            baseValues: [
                .parameter("incr", .int(1)),
                .int(1),
                .int(2),
                .int(3),
            ],
            parameterIndices: ["incr": [0]]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func parameters() throws {
        let gotQuery = try Query(
            sql: """
                {parameter}, {parameter}
                , {data}, {data}
                , {bool}, {bool}
                , {int}, {int}
                , {int64}, {double}
                , {string}, {string}
                , {date}, {date}
                , {uuid}, {uuid}
                """,
            values: [
                .parameter("parameter", .null),
                .parameter("data", .data(Data([0xFF, 0xFF, 0xFF]))),
                .parameter("bool", .bool(true)),
                .parameter("int", .int(5)),
                .parameter("int64", .int64(7)),
                .parameter("double", .double(11.0)),
                .parameter("string", .string("lorem ipsum")),
                .parameter("date", .date(Date(timeIntervalSince1970: 0))),
                .parameter(
                    "uuid",
                    .uuid(
                        UUID(
                            uuidString: "a4f952f1-4c45-4e63-bd4e-159ca33c8e20"
                        )!
                    )
                ),
            ]
        )
        let wantQuery = Query(
            baseSQL: """
                :parameter, :parameter
                , :data, :data
                , :bool, :bool
                , :int, :int
                , :int64, :double
                , :string, :string
                , :date, :date
                , :uuid, :uuid
                """,
            baseValues: [
                .parameter("parameter", .null),
                .parameter("data", .data(Data([0xFF, 0xFF, 0xFF]))),
                .parameter("bool", .bool(true)),
                .parameter("int", .int(5)),
                .parameter("int64", .int64(7)),
                .parameter("double", .double(11.0)),
                .parameter("string", .string("lorem ipsum")),
                .parameter("date", .date(Date(timeIntervalSince1970: 0))),
                .parameter(
                    "uuid",
                    .uuid(
                        UUID(
                            uuidString: "a4f952f1-4c45-4e63-bd4e-159ca33c8e20"
                        )!
                    )
                ),
            ],
            parameterIndices: [
                "parameter": [0],
                "data": [1],
                "bool": [2],
                "int": [3],
                "int64": [4],
                "double": [5],
                "string": [6],
                "date": [7],
                "uuid": [8],
            ]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func duplicateParameters() throws {
        #expect(throws: (any Error).self) {
            try Query(
                sql: "{parameter}, {parameter}",
                values: [
                    .parameter("parameter", .int(1)),
                    .parameter("parameter", .int(2)),
                ]
            )
        }
    }

    @Test func anonymousParameters() throws {
        let gotQuery = try Query(
            sql: """
                SELECT {}
                FROM {}
                WHERE {} = {}
                AND {} <> {}
                AND {} IN ({})
                """,
            values: [
                .expression("name"),
                .expression("users"),
                .expression("age"),
                .int(5),
                .expression("email"),
                .string("bob@email.com"),
                .expression("name"),
                .toValues("tom", "dick", "harry")!,
            ]
        )
        let wantQuery = Query(
            baseSQL: """
                SELECT name
                FROM users
                WHERE age = :1
                AND email <> :2
                AND name IN (:3, :4, :5)
                """,
            baseValues: [
                .int(5),
                .string("bob@email.com"),
                .string("tom"),
                .string("dick"),
                .string("harry"),
            ],
            parameterIndices: [:]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func ordinalParameters() throws {
        let gotQuery = try Query(
            sql: """
                SELECT {}
                FROM {}
                WHERE {} = {5}
                AND {} <> {5}
                AND {1} IN ({6})
                AND {4} IN ({6})
                """,
            values: [
                .expression("name"),
                .expression("users"),
                .expression("age"),
                .expression("email"),
                .string("bob@email.com"),
                .toValues("tom", "dick", "harry")!,
            ]
        )
        let wantQuery = Query(
            baseSQL: """
                SELECT name
                FROM users
                WHERE age = :1
                AND email <> :1
                AND name IN (:2, :3, :4)
                AND email IN (:5, :6, :7)
                """,
            baseValues: [
                .string("bob@email.com"),
                .string("tom"),
                .string("dick"),
                .string("harry"),
                .string("tom"),
                .string("dick"),
                .string("harry"),
            ],
            parameterIndices: [:]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func namedParameters() throws {
        let gotQuery = try Query(
            sql: """
                SELECT {}
                FROM {}
                WHERE {3} = {age}
                AND {3} > {6}
                AND {4} <> {email}
                AND {1} IN ({names})
                AND {4} IN ({names})
                """,
            values: [
                .expression("name"),
                .expression("users"),
                .expression("age"),
                .expression("email"),
                .parameter("email", .string("bob@email.com")),
                .parameter("age", .int(5)),
                .parameter("names", .toValues("tom", "dick", "harry")!),
            ]
        )
        let wantQuery = Query(
            baseSQL: """
                SELECT name
                FROM users
                WHERE age = :age
                AND age > :age
                AND email <> :email
                AND name IN (:3, :4, :5)
                AND email IN (:6, :7, :8)
                """,
            baseValues: [
                .parameter("age", .int(5)),
                .parameter("email", .string("bob@email.com")),
                .string("tom"),
                .string("dick"),
                .string("harry"),
                .string("tom"),
                .string("dick"),
                .string("harry"),
            ],
            parameterIndices: ["age": [0], "email": [1]]
        )
        #expect(gotQuery.baseSQL == wantQuery.baseSQL)
        #expect(gotQuery.baseValues == wantQuery.baseValues)
        #expect(gotQuery.parameterIndices == wantQuery.parameterIndices)
    }

    @Test func missingClosingCurlyBrace() throws {
        #expect(throws: (any Error).self) {
            try Query(
                sql: "SELECT {field",
                values: [
                    .parameter("field", .int(1))
                ]
            )
        }
    }

    @Test func tooFewValuesPassedIn() throws {
        #expect(throws: (any Error).self) {
            try Query(
                sql: "SELECT {}, {}, {}, {}",
                values: [
                    .int(1),
                    .int(2),
                ]
            )
        }
    }

    @Test func ordinalParameterOutOfBounds() throws {
        #expect(throws: (any Error).self) {
            try Query(
                sql: "SELECT {1}, {2}, {99}",
                values: [
                    .int(1),
                    .int(2),
                    .int(3),
                ]
            )
        }
    }

    @Test func nonexistentParameterName() throws {
        #expect(throws: (any Error).self) {
            try Query(
                sql: "SELECT {A}, {B}, {C}",
                values: [
                    .parameter("A", .int(1)),
                    .parameter("B", .int(2)),
                    .parameter("E", .int(5)),
                ]
            )
        }
    }
}

@Suite class TestDatabase {
    @Test func openAndClose() throws {
        let poolSize = 3
        var database = try Database(
            filename: "file:/TestDatabase/openAndClose?vfs=memdb",
            poolSize: poolSize,
            connectionDidOpen: { connection in
                try connection.execute(
                    """
                    PRAGMA busy_timeout = 10000;
                    PRAGMA foreign_keys = 1;
                    PRAGMA journal_mode = WAL;
                    PRAGMA synchronous = NORMAL;
                    """
                )
            }
        )
        defer {
            database.close()
        }
        #expect(database.connectionPointerPool.elements.count == poolSize)
        let connectionPointer = database.connectionPointerPool.get()
        #expect(database.connectionPointerPool.elements.count == poolSize - 1)
        database.connectionPointerPool.put(connectionPointer)
        #expect(database.connectionPointerPool.elements.count == poolSize)
    }

    @Test func statements() throws {
        struct Item: Equatable {
            let data: Data?
            let bool: Bool?
            let double: Double?
            let int: Int?
            let int64: Int64?
            let string: String?
            let date: Date?
            let uuid: UUID?
        }
        var database = try Database(
            filename: "file:/TestDatabase/statements?vfs=memdb"
        )
        defer {
            database.close()
        }
        try database.execute(
            """
            DROP TABLE IF EXISTS items;
            CREATE TABLE items (data BLOB);
            ALTER TABLE items ADD COLUMN bool BOOLEAN;
            ALTER TABLE items ADD COLUMN double REAL;
            ALTER TABLE items ADD COLUMN int INT;
            ALTER TABLE items ADD COLUMN int64 BIGINT;
            ALTER TABLE items ADD COLUMN string TEXT;
            ALTER TABLE items ADD COLUMN date DATETIME;
            ALTER TABLE items ADD COLUMN uuid UUID;                
            """,
        )
        let items: [Item] = [
            Item(
                data: nil,
                bool: nil,
                double: nil,
                int: nil,
                int64: nil,
                string: nil,
                date: nil,
                uuid: nil
            ),
            Item(
                data: Data([0x00]),
                bool: false,
                double: 0.0,
                int: 0,
                int64: 0,
                string: "zero",
                date: Date(timeIntervalSince1970: 0.0),
                uuid: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000000"
                )!
            ),
            Item(
                data: Data([0x01]),
                bool: true,
                double: 1.0,
                int: 1,
                int64: 1,
                string: "one",
                date: Date(timeIntervalSince1970: 1.0),
                uuid: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000001"
                )!
            ),
        ]
        let (_, rowsAffected) = try database.execute(
            sql: """
                INSERT INTO items (data, bool, double, int, int64, string, date, uuid) 
                VALUES ({}), ({}), ({})
                """,
            values: [
                .values([
                    .optionalData(items[0].data),
                    .optionalBool(items[0].bool),
                    .optionalDouble(items[0].double),
                    .optionalInt(items[0].int),
                    .optionalInt64(items[0].int64),
                    .optionalString(items[0].string),
                    .optionalDate(items[0].date),
                    .optionalUUID(items[0].uuid),
                ]),
                .values([
                    .optionalData(items[1].data),
                    .optionalBool(items[1].bool),
                    .optionalDouble(items[1].double),
                    .optionalInt(items[1].int),
                    .optionalInt64(items[1].int64),
                    .optionalString(items[1].string),
                    .optionalDate(items[1].date),
                    .optionalUUID(items[1].uuid),
                ]),
                .values([
                    .optionalData(items[2].data),
                    .optionalBool(items[2].bool),
                    .optionalDouble(items[2].double),
                    .optionalInt(items[2].int),
                    .optionalInt64(items[2].int64),
                    .optionalString(items[2].string),
                    .optionalDate(items[2].date),
                    .optionalUUID(items[2].uuid),
                ]),
            ]
        )
        if #available(iOS 15.4, macOS 12.3, *) {
            #expect(rowsAffected == 3)
        }

        let fetchAllItems = try database.fetchAll(
            sql: "SELECT {*} FROM items ORDER BY rowid"
        ) {
            row in
            return Item(
                data: try row.optionalData("data"),
                bool: try row.optionalBool("bool"),
                double: try row.optionalDouble("double"),
                int: try row.optionalInt("int"),
                int64: try row.optionalInt64("int64"),
                string: try row.optionalString("string"),
                date: try row.optionalDate("date"),
                uuid: try row.optionalUUID("uuid")
            )
        }
        #expect(fetchAllItems == items)

        var cursor = try database.fetchCursor(
            sql: "SELECT {*} FROM items ORDER BY rowid"
        ) {
            row in
            return Item(
                data: try row.optionalData("data"),
                bool: try row.optionalBool("bool"),
                double: try row.optionalDouble("double"),
                int: try row.optionalInt("int"),
                int64: try row.optionalInt64("int64"),
                string: try row.optionalString("string"),
                date: try row.optionalDate("date"),
                uuid: try row.optionalUUID("uuid")
            )
        }
        defer {
            cursor.close()
        }
        var fetchCursorItems: [Item] = []
        while let item = try cursor.next() {
            fetchCursorItems.append(item)
        }
        #expect(fetchCursorItems == items)

        let fetchOneItem = try database.fetchOne(
            sql: """
                SELECT {*}
                FROM items
                WHERE data = {data}
                AND bool = {bool}
                AND double = {double}
                AND int = {int}
                AND int64 = {int64}
                AND string = {string}
                AND date = {date}
                AND uuid = {uuid}
                """,
            values: [
                .parameter("data", .optionalData(items[1].data)),
                .parameter("bool", .optionalBool(items[1].bool)),
                .parameter("double", .optionalDouble(items[1].double)),
                .parameter("int", .optionalInt(items[1].int)),
                .parameter("int64", .optionalInt64(items[1].int64)),
                .parameter("string", .optionalString(items[1].string)),
                .parameter("date", .optionalDate(items[1].date)),
                .parameter("uuid", .optionalUUID(items[1].uuid)),
            ]
        ) { row in
            return Item(
                data: try row.optionalData("data"),
                bool: try row.optionalBool("bool"),
                double: try row.optionalDouble("double"),
                int: try row.optionalInt("int"),
                int64: try row.optionalInt64("int64"),
                string: try row.optionalString("string"),
                date: try row.optionalDate("date"),
                uuid: try row.optionalUUID("uuid")
            )
        }
        #expect(fetchOneItem == items[1])
    }

    @Test func invalidParameterName() throws {
        var database = try Database(
            filename: "file:/TestDatabase/invalidParameterName?vfs=memdb"
        )
        defer {
            database.close()
        }
        #expect(throws: (any Error).self) {
            try database.fetchOne(
                sql: """
                    WITH tbl (a, b, c) AS (SELECT {foo}, {bar}, {baz})
                    SELECT {*} FROM tbl
                    """,
                values: [
                    .parameter("foo", .int(1)),
                    .parameter("bar", .int(2)),
                    .parameter("bazzzzz", .int(3)),
                ]
            ) { row in
                return (
                    a: try row.int("a"),
                    b: try row.int("b"),
                    c: try row.int("c"),
                )
            }
        }
    }

    @Test func readOnlyConnection() throws {
        var database = try Database(
            filename: "file:/TestDatabase/readOnlyConnection?vfs=memdb"
        )
        defer {
            database.close()
        }
        let result = try database.read { connection in
            return try connection.fetchOne(
                sql: """
                    WITH tbl (a, b, c) AS (SELECT {foo}, {bar}, {baz})
                    SELECT {*} FROM tbl
                    """,
                values: [
                    .parameter("foo", .int(1)),
                    .parameter("bar", .int(2)),
                    .parameter("baz", .int(3)),
                ]
            ) { row in
                return (
                    a: try row.int("a"),
                    b: try row.int("b"),
                    c: try row.int("c"),
                )
            }
        }
        #expect(result! == (a: 1, b: 2, c: 3))
    }

    @Test func preparedFetch() throws {
        var database = try Database(
            filename: "file:/TestDatabase/preparedFetch?vfs=memdb"
        )
        defer {
            database.close()
        }
        try database.execute(
            """
            CREATE TABLE names (id INT, name TEXT);
            INSERT INTO names (id, name) VALUES (1, 'foo'), (2, 'foobar'), (3, 'foobaz');
            """
        )
        try database.read { connection in
            let preparedFetch = try PreparedFetch(
                connection: connection,
                sql: "SELECT {*} FROM names WHERE name LIKE {name} ORDER BY id",
                values: [
                    .parameter("name", .null)
                ]
            ) { row in
                return try row.int("id")
            }
            defer {
                preparedFetch.close()
            }
            let fetchOneID = try preparedFetch.fetchOne([
                "name": .string("foo")
            ])
            #expect(fetchOneID == 1)
            let fetchAllIDs = try preparedFetch.fetchAll([
                "name": .string("foo%")
            ])
            #expect(fetchAllIDs == [1, 2, 3])
            var fetchCursorIDs: [Int] = []
            var cursor = try preparedFetch.fetchCursor([
                "name": .string("foo%")
            ])
            while let id = try cursor.next() {
                fetchCursorIDs.append(id)
            }
            #expect(fetchCursorIDs == [1, 2, 3])
        }
    }

    @Test func preparedExecute() throws {
        var database = try Database(
            filename: "file:/TestDatabase/preparedExecute?vfs=memdb"
        )
        defer {
            database.close()
        }
        try database.execute("CREATE TABLE names (id INT, name TEXT)")
        try database.write { connection in
            let preparedExecute = try PreparedExecute(
                connection: connection,
                sql: "INSERT INTO names (id, name) VALUES ({id}, {name})",
                values: [
                    .parameter("id", .null),
                    .parameter("name", .null),
                ]
            )
            defer {
                preparedExecute.close()
            }
            var rowsAffected: Int64
            (_, rowsAffected) = try preparedExecute.execute([
                "id": .int(1),
                "name": .string("foo"),
            ])
            if #available(iOS 15.4, macOS 12.3, *) {
                #expect(rowsAffected == 1)
            }
            (_, rowsAffected) = try preparedExecute.execute([
                "id": .int(2),
                "name": .string("foobar"),
            ])
            if #available(iOS 15.4, macOS 12.3, *) {
                #expect(rowsAffected == 1)
            }
            (_, rowsAffected) = try preparedExecute.execute([
                "id": .int(3),
                "name": .string("foobaz"),
            ])
            if #available(iOS 15.4, macOS 12.3, *) {
                #expect(rowsAffected == 1)
            }
            let fetchAllIDs = try connection.fetchAll(
                sql: "SELECT {*} FROM names WHERE name LIKE 'foo%'",
            ) { row in
                return try row.int("id")
            }
            #expect(fetchAllIDs == [1, 2, 3])
        }
    }

    // TODO: @Test func transactionPass() throws {}

    // TODO: @Test func transactionFail() throws {}
}
