//
//  ViewController.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/16.
//  Copyright © 2020 maqianzheng. All rights reserved.
//

import UIKit
import StoreKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    fileprivate var products: [SKProduct] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let fetchButton = UIBarButtonItem(title: "Fetch Products", style: .plain, target: self, action: #selector(fetchProducts))
        navigationItem.rightBarButtonItem = fetchButton
    }
    
    @objc
    fileprivate func fetchProducts() {
        let productIds = ["pay_test_amount_6",
                          "pay_test_amount_12",
                          "pay_test_amount_18",
                          "pay_subscription_test_amount_8",
                          "pay_subscription_test_amount_30"]
        StoreManager.shared.delegate = self
        StoreManager.shared.startProductRequest(with: productIds)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let product = products[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
        cell.textLabel?.text = product.productIdentifier
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let product = products[indexPath.row]
        /// 此处将uid 与 orderId 与商品关联
        let orderItem = OrderItem(uid: "uid", orderId: "orderId", productId: product.productIdentifier)
        // 调用支付
        StoreObserver.shared.delegate = self
        StoreObserver.shared.buy(product, orderItem: orderItem)
    }
    
}

extension ViewController: StoreManagerDelegate {
    func storeManagerDidReceiveResponse(_ response: [Section]) {
        for section in response {
            switch section.type {
            case .availableProducts:
                products = section.elements.map{ $0 as! SKProduct }
                tableView.reloadData()
            default:
                break
            }
        }
    }
    
    func storeManagerDidReceiveMessage(_ message: String) {
        alert("StoreManager", message: message)
    }
}

extension ViewController: StoreObserverDelegate {
    func storeObserverUpdated(_ response: [Section], completedHandler: @escaping (([Section]) -> Void)) {
        var purchasedSection = Section(type: .purchased)
        var failedSection = Section(type: .failed)
        var restoredSection = Section(type: .restored)
        for section in response {
            switch section.type {
            case .purchased:
                for transaction in section.elements {
                    /// 此处应去服务端验证，demo随机返回了
                    let val = arc4random() % 3
                    if val == 0 { // 假设服务端成功
                        purchasedSection.elements.append(transaction)
                    } else if val == 1 { // 假设服务端失败
                        failedSection.elements.append(transaction)
                    } else { // 假设服务端无法确认
                        alert("StoreObserver", message: "无法确认\nproductId:\((transaction as! SKPaymentTransaction).payment.productIdentifier)")
                    }
                }
            case .restored:
                for transaction in section.elements {
                    /// 此处应去服务端验证，demo随机返回了
                    let val = arc4random() % 3
                    if val == 0 { // 假设服务端成功
                        restoredSection.elements.append(transaction)
                    } else if val == 1 { // 假设服务端失败
                        failedSection.elements.append(transaction)
                    } else { // 假设服务端无法确认
                        alert("StoreObserver", message: "无法确认\nproductId:\((transaction as! SKPaymentTransaction).payment.productIdentifier)")
                    }
                }
            default:
                break
            }
        }
        completedHandler([purchasedSection, failedSection, restoredSection])
    }
    
    func storeObserverDidReceiveMessage(_ message: String) {
        alert("StoreObserver", message: message)
    }
    
    
}

extension ViewController {
    func alert(_ title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let action = UIAlertAction(title: "OK",
                                   style: .default, handler: nil)
        alertController.addAction(action)
        self.navigationController?.present(alertController, animated: true, completion: nil)
    }
}
