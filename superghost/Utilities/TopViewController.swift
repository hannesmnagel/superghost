//
//  TopViewController.swift
//  superghost
//
//  Created by Hannes Nagel on 8/19/24.
//

import SwiftUI

#if canImport(UIKit)

extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
        .first) -> UIViewController? {
            if let nav = base as? UINavigationController {
                return topViewController(base: nav.visibleViewController)
            }

            if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }

            if let presented = base?.presentedViewController {
                return topViewController(base: presented)
            }

            return base
        }
}
#endif
