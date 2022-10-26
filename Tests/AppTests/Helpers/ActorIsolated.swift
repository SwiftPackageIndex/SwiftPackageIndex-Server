// MIT License
//
// Copyright (c) 2020 Point-Free, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Extracted from https://github.com/pointfreeco/swift-composable-architecture/blob/ed3a380f09a81e72636d7b0699bf2dd2e6313780/Sources/ComposableArchitecture/Effects/ConcurrencySupport.swift#L297
// Add any changes via extensions in a new file rather than making changes here.

/// A generic wrapper for isolating a mutable value to an actor.
///
/// This type is most useful when writing tests for when you want to inspect what happens inside
/// an effect. For example, suppose you have a feature such that when a button is tapped you
/// track some analytics:
///
/// ```swift
/// @Dependency(\.analytics) var analytics
///
/// func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
///   switch action {
///   case .buttonTapped:
///     return .fireAndForget { try await self.analytics.track("Button Tapped") }
///   }
/// }
/// ```
///
/// Then, in tests we can construct an analytics client that appends events to a mutable array
/// rather than actually sending events to an analytics server. However, in order to do this in
/// a safe way we should use an actor, and ``ActorIsolated`` makes this easy:
///
/// ```swift
/// @MainActor
/// func testAnalytics() async {
///   let store = TestStore(…)
///
///   let events = ActorIsolated<[String]>([])
///   store.dependencies.analytics = AnalyticsClient(
///     track: { event in
///       await events.withValue { $0.append(event) }
///     }
///   )
///
///   await store.send(.buttonTapped)
///
///   await events.withValue { XCTAssertEqual($0, ["Button Tapped"]) }
/// }
/// ```
@dynamicMemberLookup
public final actor ActorIsolated<Value: Sendable> {
  /// The actor-isolated value.
  public var value: Value

  /// Initializes actor-isolated state around a value.
  ///
  /// - Parameter value: A value to isolate in an actor.
  public init(_ value: Value) {
    self.value = value
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  /// Perform an operation with isolated access to the underlying value.
  ///
  /// Useful for inspecting an actor-isolated value for a test assertion:
  ///
  /// ```swift
  /// let didOpenSettings = ActorIsolated(false)
  /// store.dependencies.openSettings = { await didOpenSettings.setValue(true) }
  ///
  /// await store.send(.settingsButtonTapped)
  ///
  /// await didOpenSettings.withValue { XCTAssertTrue($0) }
  /// ```
  ///
  /// - Parameters: operation: An operation to be performed on the actor with the underlying value.
  /// - Returns: The result of the operation.
  public func withValue<T: Sendable>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }

  /// Overwrite the isolated value with a new value.
  ///
  /// Useful for setting an actor-isolated value when a tested dependency runs.
  ///
  /// ```swift
  /// let didOpenSettings = ActorIsolated(false)
  /// store.dependencies.openSettings = { await didOpenSettings.setValue(true) }
  ///
  /// await store.send(.settingsButtonTapped)
  ///
  /// await didOpenSettings.withValue { XCTAssertTrue($0) }
  /// ```
  ///
  /// - Parameter newValue: The value to replace the current isolated value with.
  public func setValue(_ newValue: Value) {
    self.value = newValue
  }
}

