# Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

# This file is based on the Vapor project's template:
# https://github.com/vapor/template-bare/blob/main/Dockerfile

# ================================
# Build image
# ================================
FROM registry.gitlab.com/finestructure/spi-base:1.1.1 as build

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve --skip-update \
"$([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)"

# Copy entire repo into container
COPY . .

# Build everything, with optimizations, with static linking, and using jemalloc
# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
RUN swift build -c release \
                --static-swift-stdlib \
                -Xlinker -ljemalloc

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Run" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
# Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true


# ================================
# Run image
# ================================
FROM registry.gitlab.com/finestructure/spi-base:1.1.1

# NB sas 2022-09-23: We're not using a dedicated `vapor` user to run the executable, because it
# makes managing the data in the checkouts volume difficult. See
# https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/2038#issuecomment-1255999429
# for details.

# Create a vapor user and group with /app as its home directory
# RUN useradd --user-group --create-home --system --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
# NB sas 2022-09-23: See above why we're not using the `vapor` user
# COPY --from=build --chown=vapor:vapor /staging /app
COPY --from=build /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
# NB: SWIFT_BACKTRACE is being set via our environment variables so it can be changed without a rebuild
ENV SWIFT_ROOT=/usr

# Ensure all further commands run as the vapor user
# NB sas 2022-09-23: See above why we're not using the `vapor` user
# USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
