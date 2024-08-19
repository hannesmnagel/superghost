//
//  TopViewController.swift
//  superghost
//
//  Created by Hannes Nagel on 8/19/24.
//

#if os(macOS)
import AppKit

func topViewController() -> NSViewController {
    NSApplication.shared.topViewController() ?? NSViewController()
}

extension NSApplication {
    func topWindowController(base: NSWindowController? = NSApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowController) -> NSWindowController? {
        if let presented = base?.window?.contentViewController?.presentedViewControllers?.last {
            return topWindowController(base: presented.view.window?.windowController)
        }
        return base
    }

    func topViewController(base: NSViewController? = NSApplication.shared.windows.first(where: { $0.isKeyWindow })?.contentViewController) -> NSViewController? {
        if let splitVC = base as? NSSplitViewController {
            return topViewController(base: splitVC.splitViewItems.last?.viewController)
        }

        if let presented = base?.presentedViewControllers?.last {
            return topViewController(base: presented)
        }

        return base
    }
}
#else
import UIKit

func topViewController() -> UIViewController {
    UIApplication.shared.topViewController() ?? UIViewController()
}

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
