//
//  NotificationCenterTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class NotificationCenterTests: XCTestCase {

    func testRequestingDemand() {

        let initialDemands: [Subscribers.Demand?] = [
            nil,
            .max(1),
            .max(2),
            .max(10),
            .unlimited
        ]

        let subsequentDemands: [[Subscribers.Demand]] = [
            Array(repeating: .max(0), count: 5),
            Array(repeating: .max(1), count: 10),
            [.max(1), .max(0), .max(1), .max(0)],
            [.max(0), .max(1), .max(2)],
            [.unlimited, .max(1)]
        ]

        var numberOfInputsHistory: [Int] = []
        let expectedNumberOfInputsHistory = [
            0, 0, 0, 0, 0, 1, 11, 2, 1, 20, 2, 12, 4, 5, 20, 10, 20, 12, 13, 20, 20,
            20, 20, 20, 20
        ]

        for initialDemand in initialDemands {
            for subsequentDemand in subsequentDemands {

                var i = 0

                let center = TestNotificationCenter()
                let name = Notification.Name(rawValue: "testName")
                let publisher = makePublisher(center, for: name, object: nil)

                let subscriber = TrackingSubscriberBase<Notification, Never>(
                    receiveSubscription: { initialDemand.map($0.request) },
                    receiveValue: { _ in
                        defer { i += 1 }
                        return i < subsequentDemand.endIndex ? subsequentDemand[i] : .none
                    }
                )

                XCTAssertEqual(subscriber.subscriptions.count, 0)
                XCTAssertEqual(subscriber.inputs.count, 0)
                XCTAssertEqual(subscriber.completions.count, 0)

                publisher.subscribe(subscriber)

                XCTAssertEqual(subscriber.subscriptions.count, 1)
                XCTAssertEqual(subscriber.inputs.count, 0)
                XCTAssertEqual(subscriber.completions.count, 0)

                for _ in 0..<20 {
                    center.post(name: name, object: TestObject.two)
                }

                XCTAssertEqual(subscriber.subscriptions.count, 1)
                XCTAssertEqual(subscriber.completions.count, 0)

                numberOfInputsHistory.append(subscriber.inputs.count)
            }
        }

        XCTAssertEqual(numberOfInputsHistory, expectedNumberOfInputsHistory)
    }

    func testBasicBehavior() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let publisher = makePublisher(center, for: name, object: TestObject.one)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Notification, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        XCTAssertEqual(center.history, [])

        publisher.subscribe(tracking)

        XCTAssertEqual(center.history,
                       [.addObserver(name, TestObject.one, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer")])

        let note = Notification(name: name, object: TestObject.one, userInfo: nil)
        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, TestObject.one, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer")])

        try XCTUnwrap(downstreamSubscription).request(.max(3))

        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, TestObject.one, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note)])

        let unrelatedNote1 = Notification(name: Notification.Name("unrelatedNote1"),
                                          object: TestObject.one,
                                          userInfo: nil)
        center.post(unrelatedNote1)

        let unrelatedNote2 = Notification(name: name,
                                          object: TestObject.two,
                                          userInfo: nil)
        center.post(unrelatedNote2)
        center.post(name: name, object: nil)
        center.post(name: name, object: nil)
        center.post(name: name, object: TestObject.one)
        center.post(name: name, object: TestObject.one)

        XCTAssertEqual(center.history,
                       [.addObserver(name, TestObject.one, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note),
                        .value(note),
                        .value(note)])

        try XCTUnwrap(downstreamSubscription).request(.unlimited)

        try XCTUnwrap(center.block)(note)

        try XCTUnwrap(downstreamSubscription).cancel()

        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, TestObject.one, nil),
                        .removeObserver,
                        .removeObserverForName(nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note),
                        .value(note),
                        .value(note),
                        .value(note)])
    }

    func testBasicBehaviorNilObject() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let publisher = makePublisher(center, for: name, object: nil)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Notification, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        XCTAssertEqual(center.history, [])

        publisher.subscribe(tracking)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer")])

        let note = Notification(name: name, object: TestObject.one, userInfo: nil)
        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer")])

        try XCTUnwrap(downstreamSubscription).request(.max(3))

        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note)])

        let unrelatedNote = Notification(name: Notification.Name("unrelatedNote1"),
                                         object: TestObject.one,
                                         userInfo: nil)
        center.post(unrelatedNote)
        center.post(name: name, object: nil)
        center.post(name: name, object: nil)
        center.post(name: name, object: TestObject.one)
        center.post(name: name, object: TestObject.one)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note),
                        .value(Notification(name: name)),
                        .value(Notification(name: name))])

        try XCTUnwrap(downstreamSubscription).request(.unlimited)

        try XCTUnwrap(center.block)(note)

        try XCTUnwrap(downstreamSubscription).cancel()

        center.post(note)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil),
                        .removeObserver,
                        .removeObserverForName(nil, nil)])
        XCTAssertEqual(tracking.history,
                       [.subscription("NotificationCenter Observer"),
                        .value(note),
                        .value(Notification(name: name)),
                        .value(Notification(name: name)),
                        .value(note)])
    }

    func testRecursivelyReceiveValue() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let publisher = makePublisher(center, for: name, object: nil)
        let tracking = TrackingSubscriberBase<Notification, Never>(
            receiveSubscription: { $0.request(.max(3)) },
            receiveValue: { _ in .unlimited }
        )
        publisher.subscribe(tracking)

        let note = Notification(name: name)
        var recursionCounter = 7
        tracking.onValue = { _ in
            if recursionCounter == 0 { return }
            recursionCounter -= 1
            center.post(note)
        }

        try XCTUnwrap(center.block)(note)

        XCTAssertEqual(tracking.history, [.subscription("NotificationCenter Observer"),
                                          .value(note),
                                          .value(note),
                                          .value(note)])

        try XCTUnwrap(center.block)(note)

        XCTAssertEqual(tracking.history, [.subscription("NotificationCenter Observer"),
                                          .value(note),
                                          .value(note),
                                          .value(note),
                                          .value(note),
                                          .value(note),
                                          .value(note),
                                          .value(note),
                                          .value(note)])
    }

    func testCancelAlreadyCancelled() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let publisher = makePublisher(center, for: name, object: nil)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Notification, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(tracking.history, [.subscription("NotificationCenter Observer")])
        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil),
                        .removeObserver,
                        .removeObserverForName(nil, nil)])
    }

    func testCancellingReleasesNotificationCenter() throws {
        var centerDestroyed = false
        var downstreamSubscription: Subscription?
        do {
            let center = TestNotificationCenter()
            center.onDeinit = { centerDestroyed = true }
            let name = Notification.Name(rawValue: "testName")
            let publisher = makePublisher(center, for: name, object: nil)
            let tracking = TrackingSubscriberBase<Notification, Never>(
                receiveSubscription: { downstreamSubscription = $0 }
            )
            publisher.subscribe(tracking)
        }
        XCTAssertFalse(centerDestroyed)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertTrue(centerDestroyed)
    }

    func testZeroDemand() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let publisher = makePublisher(center, for: name, object: nil)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Notification, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).request(.none)

        XCTAssertEqual(center.history,
                       [.addObserver(name, nil, nil)])
        XCTAssertEqual(tracking.history, [.subscription("NotificationCenter Observer")])
    }

    func testNotificationCenterSubscriptionReflection() throws {
        let center = TestNotificationCenter()
        let name = Notification.Name(rawValue: "testName")
        let object = TestObject.one
        let publisher = makePublisher(center, for: name, object: object)

        try testSubscriptionReflection(
            description: "NotificationCenter Observer",
            customMirror: expectedChildren(
                ("center", .matches(String(describing: Optional(center)))),
                ("name", .contains(String(describing: name))),
                ("object", .matches(String(describing: Optional(object)))),
                ("demand", "max(0)")
            ),
            playgroundDescription: "NotificationCenter Observer",
            sut: publisher
        )
    }

    func testEquatable() {
        let center1 = NotificationCenter()
        let center2 = NotificationCenter()
        let name1 = Notification.Name(rawValue: "abcdefg")
        let name2 = Notification.Name(rawValue: "1234567")
        let object1 = TestObject.one
        let object2 = TestObject.two

        XCTAssertEqual(makePublisher(center1, for: name1, object: object1),
                       makePublisher(center1, for: name1, object: object1))
        XCTAssertEqual(makePublisher(center2, for: name2, object: object2),
                       makePublisher(center2, for: name2, object: object2))
        XCTAssertEqual(makePublisher(center1, for: name1, object: nil),
                       makePublisher(center1, for: name1, object: nil))
        XCTAssertNotEqual(makePublisher(center1, for: name1, object: object1),
                          makePublisher(center1, for: name1, object: nil))
        XCTAssertNotEqual(makePublisher(center1, for: name1, object: nil),
                          makePublisher(center1, for: name1, object: object2))
        XCTAssertNotEqual(makePublisher(center1, for: name1, object: object1),
                          makePublisher(center1, for: name1, object: object2))
        XCTAssertNotEqual(makePublisher(center1, for: name1, object: object1),
                          makePublisher(center1, for: name2, object: object1))
        XCTAssertNotEqual(makePublisher(center1, for: name1, object: object1),
                          makePublisher(center2, for: name1, object: object1))
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
@available(macOS 10.15, iOS 13.0, *)
private func makePublisher(
    _ center: NotificationCenter,
    for name: Notification.Name,
    object: AnyObject?
) -> NotificationCenter.Publisher {
    return center.publisher(for: name, object: object)
}
#else
private func makePublisher(
    _ center: NotificationCenter,
    for name: Notification.Name,
    object: AnyObject?
) -> NotificationCenter.OCombine.Publisher {
    return center.ocombine.publisher(for: name, object: object)
}
#endif

private final class TestNotificationCenter: NotificationCenter {

    enum Event {
        case addObserver(Notification.Name?, Any?, OperationQueue?)
        case removeObserver
        case removeObserverForName(Notification.Name?, Any?)
    }

    private(set) var history = [Event]()

    private(set) var block: ((Notification) -> Void)?

    var onDeinit: (() -> Void)?

    deinit {
        onDeinit?()
    }

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        self.block = block
        history.append(.addObserver(name, obj, queue))
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    override func removeObserver(_ observer: Any) {
        history.append(.removeObserver)
        super.removeObserver(observer)
    }

    override func removeObserver(_ observer: Any,
                                 name aName: NSNotification.Name?,
                                 object anObject: Any?) {
        history.append(.removeObserverForName(aName, anObject))
        super.removeObserver(observer, name: aName, object: anObject)
    }
}

private final class TestObject: NSObject {

    static let one = TestObject()

    static let two = TestObject()
}

extension TestNotificationCenter.Event: Equatable {
    fileprivate static func == (lhs: TestNotificationCenter.Event,
                                rhs: TestNotificationCenter.Event) -> Bool {
        switch (lhs, rhs) {
        case let (.addObserver(lhsName, lhsObject as TestObject?, lhsQueue),
                  .addObserver(rhsName, rhsObject as TestObject?, rhsQueue)):
            return lhsName == rhsName &&
                   lhsObject === rhsObject &&
                   lhsQueue == rhsQueue
        case (.removeObserver, .removeObserver):
            return true
        case let (.removeObserverForName(lhsName, lhsObject as TestObject?),
                  .removeObserverForName(rhsName, rhsObject as TestObject?)):
            return lhsName == rhsName && lhsObject === rhsObject
        default:
            return false
        }
    }
}
