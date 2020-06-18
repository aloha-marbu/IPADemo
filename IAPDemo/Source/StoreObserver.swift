
//
//  StoreManager.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/9.
//  Copyright © 2020 maqianzheng. All rights reserved.
//
import StoreKit
import Foundation
import WebKit

class StoreObserver: NSObject {
    // MARK: - Types

    static let shared = StoreObserver()

    // MARK: - Properties

    /**
    Indicates whether the user is allowed to make payments.
    - returns: true if the user is allowed to make payments and false, otherwise. Tell StoreManager to query the App Store when the user is
    allowed to make payments and there are product identifiers to be queried.
    */
    var isAuthorizedForPayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }

    /// Keeps track of all purchases.
    var purchased = [SKPaymentTransaction]()

    /// Keeps track of all restored purchases.
    var restored = [SKPaymentTransaction]()

    /// Indicates whether there are restorable purchases.
    fileprivate var hasRestorablePurchases = false

    weak var delegate: StoreObserverDelegate?

    // MARK: - Initializer

    private override init() {}

    // MARK: - Submit Payment Request

    /// Create and add a payment request to the payment queue.
    func buy(_ product: SKProduct, orderItem: OrderItem) {
        guard isAuthorizedForPayments else {
            print("No payment allowed.")
            return
        }
        
        if let _ = KeychainItem.orderItem(product.productIdentifier) {
            /// 钥匙串存有orderItem，说明当前有一笔完成的订单
            /// 同个productId商品，未完成苹果不会重复发起支付，只会回调支付结果，所以在回调结果中拿到未完成的订单信息即可
        } else {
            /// 记录有一笔订单添加到支付队列
            KeychainItem.setOrderItem(product.productIdentifier, item: orderItem)
        }
        
        let payment = SKMutablePayment(product: product)
        /// 将orderItem记录在payment.applicationUsername，优先使用，丢失则使用钥匙串数据
        payment.applicationUsername = encode(obj: orderItem)
        /// 添加到支付队列
        SKPaymentQueue.default().add(payment)
    }
    
    // MARK: - Observer
    func becomePaymentQueueObserver() {
        SKPaymentQueue.default().add(self)
    }
    
    func resignPaymentQueueObserver() {
        
        SKPaymentQueue.default().remove(self)
    }

    // MARK: - Restore All Restorable Purchases

    /// Restores all previously completed purchases.
    func restore() {
        if !restored.isEmpty {
            restored.removeAll()
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - 将交易对象转化有包含用户信息的TransactionItem
    static func transactionItem(_ transaction: SKPaymentTransaction) -> TransactionItem? {
        /// 交易id不存在，则不认为是有效订单
        guard let transactionId = transaction.transactionIdentifier else { return nil }
        if let item = KeychainItem.transactionItem(transactionId) {
            return item
        }
        /// 如果钥匙串查找不到，则为未知掉单，目前我们会使用当前登录`用户id`生成一个新的TransactionItem
        /// 服务器会根据`用户id`查找最近订单，校验发货
        // FIX: - uid
        let uid = "uuuuuuid"
        let orderItem = OrderItem(uid: uid, orderId: "", productId: transaction.payment.productIdentifier)
        return TransactionItem(orderItem: orderItem, transactionId: transactionId)
    }
    
    // MARK: - OrderItem 与 TransactionItem 相关
    // 查找对应OrderItem
      fileprivate func readOrderItem(_ transaction: SKPaymentTransaction) -> OrderItem? {
          
          if let applicationUsername = transaction.payment.applicationUsername,
              let item = decode(tyep: OrderItem.self, string: applicationUsername) {
              return item
          }
          
          if let item = KeychainItem.orderItem(transaction.payment.productIdentifier) {
              return item
          }
          
          return nil
      }
      
      fileprivate func createTransactionItem(_ transaction: SKPaymentTransaction) -> TransactionItem? {
          
          guard let transactionId = transaction.transactionIdentifier else { return nil }
          
          /// 查找到orderItem说明还未收到苹果支付结果（收到会删除对应orderItem，创建transactionItem）则创建transactionItem。
          if let orderItem = readOrderItem(transaction) {
              return TransactionItem(orderItem: orderItem, transactionId: transactionId)
          }
          
          /// 无orderItem则为补单，去钥匙串查询
          if let item = KeychainItem.transactionItem(transactionId) {
              return item
          }
          
          return nil
      }
      
      /// 转化钥匙串OrderItem对象为TransactionItem，存储TransactionItem后，将对应OrderItem删除
      /// 在苹果返回支付成功后调用
      fileprivate func transformKeychainOrder(_ transaction: SKPaymentTransaction) {
          guard let transactionItem = createTransactionItem(transaction) else { return }
          KeychainItem.setTransactionItem(transactionItem.transactionId, item: transactionItem)
          KeychainItem.deleteOrderItem(transaction.payment.productIdentifier)
      }

    // MARK: - Handle Payment Transactions
    
    /// 处理苹果返回交易失败，直接完成交易
    fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
        // 删除钥匙串中订单信息
        KeychainItem.deleteOrderItem(transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
        DispatchQueue.main.async {
            self.delegate?.storeObserverDidReceiveMessage("\(transaction.error?.localizedDescription ?? " Apple Error")\nproductId: \(transaction.payment.productIdentifier)")
        }
    }

    /// Handles successful purchase transactions.
    fileprivate func handleDelegateResponsePurchased(_ transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            purchased.append(transaction)
            print("Store purchased \(transaction.payment.productIdentifier).")
            // Finish the successful transaction.
            SKPaymentQueue.default().finishTransaction(transaction)
            //  并移除钥匙串TransactionItem
            if let transactionId = transaction.transactionIdentifier {
                KeychainItem.deleteTransactionItem(transactionId)
            }
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("验证成功\nproductId: \(transaction.payment.productIdentifier)")
            }
        }
    }

    /// Handles failed purchase transactions.
    fileprivate func handleDelegateResponseFailed(_ transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("Store failed \(transaction.payment.productIdentifier).")
            // Finish the failed transaction.
            SKPaymentQueue.default().finishTransaction(transaction)
            if let transactionId = transaction.transactionIdentifier {
                KeychainItem.deleteTransactionItem(transactionId)
            }
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("验证失败\nproductId: \(transaction.payment.productIdentifier)")
            }
        }
    }

    /// Handles restored purchase transactions.
    fileprivate func handleDelegateResponseRestored(_ transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            hasRestorablePurchases = true
            restored.append(transaction)
            print("Store restored \(transaction.payment.productIdentifier).")
            
            // Finishes the restored transaction.
            SKPaymentQueue.default().finishTransaction(transaction)
            if let transactionId = transaction.transactionIdentifier {
                KeychainItem.deleteTransactionItem(transactionId)
            }
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("恢复购买\nproductId: \(transaction.payment.productIdentifier)")
            }
        }
    }
}

// MARK: - SKPaymentTransactionObserver

/// Extends StoreObserver to conform to SKPaymentTransactionObserver.
extension StoreObserver: SKPaymentTransactionObserver {
    /// Called when there are transactions in the payment queue.
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        var purchasedSection = Section(type: .purchased)
        var restoredSection = Section(type: .restored)
        var failedSection = Section(type: .purchased)
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing: break
            // Do not block your UI. Allow the user to continue using your app.
            case .deferred: print("Deferred")
            // The purchase was successful.
            case .purchased:
                purchasedSection.elements.append(transaction)
                // 将钥匙串中OrderItem转化为TransactionItem
                transformKeychainOrder(transaction)
            // The transaction failed.
            case .failed:
                failedSection.elements.append(transaction)
                /// 处理失败
                handleFailed(transaction)
            // There are restored products.
            case .restored:
                restoredSection.elements.append(transaction)
                // 将钥匙串中OrderItem转化为TransactionItem
                transformKeychainOrder(transaction)
            @unknown default: fatalError("unknownDefault")
            }
        }
        
        if purchasedSection.elements.count > 0 || restoredSection.elements.count > 0 {
            DispatchQueue.main.async {
                /// 回调代理苹果返回的支付结果
                self.delegate?.storeObserverUpdated([purchasedSection, restoredSection, failedSection]) { sections in
                    for section in sections {
                        guard let transactions = section.elements as? [SKPaymentTransaction] else { continue }
                        switch section.type {
                        case .purchased:
                            self.handleDelegateResponsePurchased(transactions)
                        case .restored:
                            self.handleDelegateResponseRestored(transactions)
                        case .failed:
                            self.handleDelegateResponseFailed(transactions)
                        default:
                            break
                        }
                    }
                }
            }
        }
        
    }

    /// Logs all transactions that have been removed from the payment queue.
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print ("\(transaction.payment.productIdentifier) Removed!")
        }
    }

    /// Called when an error occur while restoring purchases. Notify the user about the error.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let error = error as? SKError, error.code != .paymentCancelled {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage(error.localizedDescription)
            }
        }
    }

    /// Called when all restorable transactions have been processed by the payment queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("All restorable transactions have been processed by the payment queue.")

        if !hasRestorablePurchases {
            DispatchQueue.main.async {
                let msg = "没有可恢复的购买，只能恢复以前购买的非消耗性产品和自动可续订的订阅。"
                self.delegate?.storeObserverDidReceiveMessage(msg)
            }
        }
    }
}

extension StoreObserver {
    fileprivate func encode<O: Encodable>(obj: O) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(obj) else { return "" }
        let result = data.base64EncodedString()
        return result
    }
    
    fileprivate func decode<O: Decodable>(tyep: O.Type, string: String) -> O? {
        guard let data = Data(base64Encoded: string) else { return nil }
        let decoder = JSONDecoder()
        let obj = try? decoder.decode(O.self, from: data)
        return obj
    }
}
