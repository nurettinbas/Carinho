import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let storeFileName = "Carinho.store"
    private static let schemaVersionKey = "carinho.swiftdata.schemaVersion"
    static let currentSchemaVersion = 7

    static var storeURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(storeFileName)
    }

    static func makeSafe() -> ModelContainer {
        if let container = try? makeWithMigration() {
            markSchemaCurrent()
            return container
        }

        #if DEBUG
        print("SwiftData: migration open failed, attempting store recovery")
        #endif
        deleteStoreFiles()

        if let container = try? makeWithMigration() {
            markSchemaCurrent()
            return container
        }

        if let container = try? makeInMemory() {
            #if DEBUG
            print("SwiftData: disk store başarısız, bellek içi store kullanılıyor.")
            #endif
            return container
        }

        return emergencyContainer()
    }

    static func makeWithMigration() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CarinhoSchemaV7.self)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: config)
    }

    static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CarinhoSchemaV7.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    static func makeInMemoryV5() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CarinhoSchemaV5.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func markSchemaCurrent() {
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    private static func deleteStoreFiles() {
        let base = storeURL
        for url in [base, URL(fileURLWithPath: base.path + "-shm"), URL(fileURLWithPath: base.path + "-wal")] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func emergencyContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: CarinhoSchemaV7.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}
