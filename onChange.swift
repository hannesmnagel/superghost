//
//  onChange.swift
//  superghost
//
//  Created by Hannes Nagel on 8/5/24.
//

import SwiftUI
import Combine

extension View{
    @ViewBuilder
    func bcOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value, Value) -> Void) -> some View {
        if #available(iOS 17, tvOS 17, macOS 14, watchOS 7, *) {
            self.onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            self.modifier(ChangeModifier(value: value, action: action))
        }
    }
}
//@available(iOS, deprecated: 17)
private struct ChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value, Value) -> Void

    @State var oldValue: Value

    init(value: Value, action: @escaping (Value, Value) -> Void) {
        self.value = value
        self.action = action
        _oldValue = .init(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onReceive(Just(value)) { newValue in
                guard newValue != oldValue else { return }
                action(oldValue,newValue)
                oldValue = newValue
            }
    }
}
