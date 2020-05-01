import Vapor


extension DirectoryConfiguration {
    var checkouts: String {
        workingDirectory + "SPI-checkouts"
    }

    func checkoutPath(for package: Package) -> String? {
        guard let basename = package.localCacheDirectory else { return nil }
        return checkouts + "/" + basename
    }
}
