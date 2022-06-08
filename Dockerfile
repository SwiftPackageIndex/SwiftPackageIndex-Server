# Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ================================
# Build image
# ================================
FROM registry.gitlab.com/finestructure/spi-base:0.7.1 as build
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused 
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Compile with optimizations
RUN swift build \
    -c release \
    -Xswiftc -g

# ================================
# Run image
# ================================
# we need a special base image so that we can run `swift dump-package`
FROM registry.gitlab.com/finestructure/spi-base:0.7.1

WORKDIR /run

# Copy build artifacts
COPY --from=build /build/.build/release /run
# Copy Swift runtime libraries
COPY --from=build /usr/lib/swift/ /usr/lib/swift/
# Copy static resources
# Ridiculous hack for a docker bug: https://stackoverflow.com/a/62409523/1444152
# https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1235
RUN true
# end hack
COPY --from=build /build/Public /run/Public
COPY --from=build /build/Resources /run/Resources

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
