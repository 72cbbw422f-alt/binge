import Foundation
import SwiftData

/// Runs one detail-screen mutation in its own context so a failed save
/// cannot roll back unrelated edits made through the app's view context.
enum DetailViewPersistence {
    enum Failure: LocalizedError {
        case entryNotFound

        var errorDescription: String? {
            "Titeln finns inte längre i samlingen."
        }
    }

    @MainActor
    static func perform(
        in container: ModelContainer,
        _ operation: (ModelContext) throws -> Void
    ) throws {
        let transactionContext = ModelContext(container)
        transactionContext.autosaveEnabled = false

        do {
            try operation(transactionContext)
            try transactionContext.save()
        } catch {
            transactionContext.rollback()
            throw error
        }
    }
}
