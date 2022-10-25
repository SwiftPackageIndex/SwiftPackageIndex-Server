// Copyright 2020-2023 Dave Verwer, Sven A. Schmidt, and other contributors.
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


// From https://github.com/pointfreeco/swift-composable-architecture/blob/ed3a380f09a81e72636d7b0699bf2dd2e6313780/Sources/ComposableArchitecture/Effects/ConcurrencySupport.swift#L297

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

