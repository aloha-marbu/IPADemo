//
//  AppProtocols.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/15.
//  Copyright © 2020 maqianzheng. All rights reserved.
//

import Foundation

// MARK: - StoreManagerDelegate
protocol StoreManagerDelegate: AnyObject {
    /// Provides the delegate with the App Store's response.
    func storeManagerDidReceiveResponse(_ response: [Section])

    /// Provides the delegate with the error encountered during the product request.
    func storeManagerDidReceiveMessage(_ message: String)
}

// MARK: - StoreObserverDelegate

protocol StoreObserverDelegate: AnyObject {
    /// Tells the delegate
    func storeObserverUpdated(_ response: [Section], completedHandler:(@escaping ([Section])->Void))

    /// Provides the delegate with messages.
    func storeObserverDidReceiveMessage(_ message: String)
}
