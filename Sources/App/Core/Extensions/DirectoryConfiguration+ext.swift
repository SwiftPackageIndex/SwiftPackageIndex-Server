import Vapor


extension DirectoryConfiguration {
    var checkouts: String {
        workingDirectory + "SPI-checkouts"
    }

    func cacheDirectoryPath(for package: Package) -> String? {
        guard let dirname = package.cacheDirectoryName else { return nil }
        return checkouts + "/" + dirname
    }
}
