import ShellOut


enum Git {

    static func tag(at path: String) throws -> [Reference] {
        let tags = try Current.shell.run(command: .init(string: "git tag"), at: path)
        return tags.split(separator: "\n")
            .map(String.init)
            .compactMap(SemVer.init)
            .map { Reference.tag($0) }
    }

}
