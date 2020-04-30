import Vapor


extension DirectoryConfiguration {
    var checkouts: String {
        workingDirectory + "SPI-checkouts"
    }
}
