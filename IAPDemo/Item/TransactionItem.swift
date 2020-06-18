//
//  TransactionItem.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/10.
//  Copyright © 2020 maqianzheng. All rights reserved.
//

import Foundation

struct TransactionItem: Codable {
    // 订单信息
    var orderItem: OrderItem
    // 交易id
    var transactionId: String
}
