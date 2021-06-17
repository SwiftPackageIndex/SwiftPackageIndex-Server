import Fluent
import SQLKit

struct UpdateVersionAddReleaseNotesHTML: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .field("release_notes_html", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("versions")
            .deleteField("release_notes_html")
            .update()
    }
}
