//
//  CloudStoragePropertyWrapper.swift
//  superghost
//
//  Created by Hannes Nagel on 7/25/24.
//

import SwiftUI
import Combine

// A simple class to handle synchronization with NSUbiquitousKeyValueStore
private final class UbiquitousStorageObserver<Value: Codable>: ObservableObject {
    @Published var value: Value
    private var key: String
    private var cancellable: AnyCancellable?
    private var sendFromSelf = false

    init(initialValue: Value, key: String) {
        self.key = key

        // Load initial value from NSUbiquitousKeyValueStore
        let data = NSUbiquitousKeyValueStore.default.data(forKey: key) ?? Data()
        let storedValue = try? JSONDecoder().decode(Value.self, from: data)
        self.value = storedValue ?? initialValue

        // Observe changes from NSUbiquitousKeyValueStore
        
        self.cancellable = NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .merge(with: NotificationCenter.default.publisher(for: Notification.Name(rawValue: "\(key) will change")))
            .sink { [weak self] notification in
                guard let self = self else { return }
                if !self.sendFromSelf{
                    if let newValue = notification.object as? Value {
                        self.value = newValue
                    }
                }
                if let userInfo = notification.userInfo,
                   let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
                   reasonForChange == NSUbiquitousKeyValueStoreServerChange,
                   let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                   keys.contains(self.key) {
                    if let data = NSUbiquitousKeyValueStore.default.data(forKey: self.key),
                       let newValue = try? JSONDecoder().decode(Value.self, from: data) {
                        self.value = newValue
                    }
                }
            }
    }

    func updateValue(_ newValue: Value) {
        value = newValue
        
        if let data = try? JSONEncoder().encode(newValue) {
            NSUbiquitousKeyValueStore.default.set(data, forKey: key)
        }
        sendFromSelf = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: "\(key) will change"), object: newValue)
        sendFromSelf = false
    }
}

@propertyWrapper
struct CloudStorage<Value: Codable>: DynamicProperty {
    @ObservedObject private var observer: UbiquitousStorageObserver<Value>

    init(wrappedValue defaultValue: Value, _ key: String) {
        _observer = .init(wrappedValue: UbiquitousStorageObserver(initialValue: defaultValue, key: key))
    }

    var wrappedValue: Value {
        get { observer.value }
        nonmutating set { observer.updateValue(newValue) }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { observer.value },
            set: { observer.updateValue($0) }
        )
    }
}
