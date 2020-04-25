import Vapor
import Fluent
import SQLKit


// https://discordapp.com/channels/431917998102675485/684159753189982218/698839807652266015
func createIndex(database: Database, model: String, field: String) {
    let db = database as! SQLDatabase  // rather crash out than miss creating the index
    _ = db.create(index: "idx_\(model)_\(field)").on(model).column("\(field)").run()
}
