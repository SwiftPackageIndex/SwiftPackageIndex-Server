import Vapor
import Fluent
import SQLKit


// TODO: sas 2020-04-25: revisit if there's not a built-in way to do this - seems like there should be
// https://discordapp.com/channels/431917998102675485/684159753189982218/698839807652266015
func createIndex(database: Database, model: String, field: String) {
    let db = database as! SQLDatabase  // rather crash out than miss creating the index
    _ = db.create(index: "idx_\(model)_\(field)").on(model).column("\(field)").run()
}
