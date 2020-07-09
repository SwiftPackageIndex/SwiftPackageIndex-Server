# ================================
# Build image
# ================================
FROM swiftlang/swift@sha256:5c038060f9feeb49ded30695e7062f0066a31e12feb80aba1a2779cd1fab6a73 as build
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
    --enable-test-discovery \
    -c release \
    -Xswiftc -g

# ================================
# Run image
# ================================
# we need a swift base image so that we can run `swift dump-package`
FROM swiftlang/swift@sha256:5c038060f9feeb49ded30695e7062f0066a31e12feb80aba1a2779cd1fab6a73
WORKDIR /run

# install git so we can run clone/pull/etc
RUN apt-get update && apt-get install -y git

# Copy build artifacts
COPY --from=build /build/.build/release /run
# Copy Swift runtime libraries
COPY --from=build /usr/lib/swift/ /usr/lib/swift/
# Copy static resources
COPY --from=build /build/Public /run/Public
COPY --from=build /build/Resources /run/Resources

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
