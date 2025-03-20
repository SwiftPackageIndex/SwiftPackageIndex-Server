// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ShellOut


extension ShellOutCommand {
    static func launchDB(port: Int) -> ShellOutCommand {
        .init(command: "docker", arguments: [
            "run", "--name", "spi_test_\(port)",
            "-e", "POSTGRES_DB=spi_test",
            "-e", "POSTGRES_USER=spi_test",
            "-e", "POSTGRES_PASSWORD=xxx",
            "-e", "PGDATA=/pgdata",
            "--tmpfs", "/pgdata:rw,noexec,nosuid,size=1024m",
            "-p", "\(port):5432",
            "-d",
            "postgres:16-alpine"
        ])
    }

    static func removeDB(port: Int) -> ShellOutCommand {
        .init(command: "docker", arguments: [
            "rm", "-f", "spi_test_\(port)"
        ])
    }
}
