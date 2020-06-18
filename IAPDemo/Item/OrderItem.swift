//
//  OrderItem.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/9.
//  Copyright © 2020 maqianzheng. All rights reserved.
//

import Foundation

struct OrderItem: Codable {
    // 用户id
    var uid: String
    // 订单id
    var orderId: String
    // 商品id
    var productId: String
}
