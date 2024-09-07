//
//  SharedTopViewController.swift
//  superghost
//
//  Created by Hannes Nagel on 9/7/24.
//
import SwiftUI

#if os(macOS)
typealias ViewController = NSViewController
#else
typealias ViewController = UIViewController
#endif

extension EnvironmentValues{
    @Entry var topViewController : () -> ViewController? = {nil}
}
