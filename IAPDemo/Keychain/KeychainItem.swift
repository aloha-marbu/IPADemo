//
//  KeychainItem.swift
//  IAPDemo
//
//  Created by ycgame on 2020/6/9.
//  Copyright © 2020 maqianzheng. All rights reserved.
//

import Foundation

struct KeychainItem<O: Codable> {
    
    // MARK: Types
    enum KeychainError: Error {
        case noItem
        case unexpectedPasswordData
        case unexpectedItemData
        case decodeError
        case encodeError
        case unhandledError
    }
    
    // MARK: Properties
    let service: String
    let accessGroup: String?
    private(set) var account: String
    
    // MARK: Intialization
    init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
    
    // MARK: Keychain access
    func readItem() throws -> O {
        // Build a query to find the item that matches the service, account and access group.
        var query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        // Try to fetch the existing keychain item that matches the query.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate.
        guard status != errSecItemNotFound else { throw KeychainError.noItem }
        guard status == noErr else { throw KeychainError.unhandledError }
        
        
        // Parse the password string from the query result.
        guard let existingItem = queryResult as? [String: AnyObject],
            let itemData = existingItem[kSecValueData as String] as? Data
            else {
                throw KeychainError.unexpectedPasswordData
        }
        
        let decoder = JSONDecoder()
        guard let item = try? decoder.decode(O.self, from: itemData) else {
            throw KeychainError.decodeError
        }
        return item
    }
    
    func saveItem(_ item: O) throws {
        let encoder = JSONEncoder()
        // Encode the item into an Data object.
        guard let encodedItem = try? encoder.encode(item) else {
            throw KeychainError.encodeError
        }
        
        do {
            // Check for an existing item in the keychain.
            try _ = readItem()
            
            // Update the existing item with the new password.
            var attributesToUpdate = [String: AnyObject]()
            attributesToUpdate[kSecValueData as String] = encodedItem as AnyObject?
            
            let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError }
        } catch KeychainError.noItem {
            //No password was found in the keychain. Create a dictionary to save as a new keychain item.
            var newItem = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = encodedItem as AnyObject?
            
            // Add a the new item to the keychain.
            let status = SecItemAdd(newItem as CFDictionary, nil)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.unhandledError }
        }
    }
    
    func deleteItem() throws {
        // Delete the existing item from the keychain.
        let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        // Throw an error if an unexpected status was returned.
        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.unhandledError }
    }
    
    // MARK: Convenience
    private static func keychainQuery(withService service: String, account: String? = nil, accessGroup: String? = nil) -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject?
        
        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject?
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }
        
        return query
    }
}

//Mark - OrderItem
extension KeychainItem where O == OrderItem {
    static var orderService: String {
        return Bundle.main.bundleIdentifier ?? "com.aloha-marbu.orderItem"
    }
    
    static func setOrderItem(_ key: String, item: OrderItem) {
        let query = KeychainItem(service: orderService, account: key)
        do {
            try query.saveItem(item)
        } catch {
            print("Keychain Save Error: Order Item - \(error.localizedDescription)")
        }
    }
    
    static func deleteOrderItem(_ key: String) {
        let query = KeychainItem(service: orderService, account: key)
        do {
            try query.deleteItem()
        } catch {
            print("Keychain Delete Error: Order Item - \(error.localizedDescription)")
        }
    }
    
    static func orderItem(_ key: String) -> OrderItem? {
        let query = KeychainItem(service: orderService, account: key)
        do {
            return try query.readItem()
        } catch {
            print("Keychain Read Error: Order Item - \(error.localizedDescription)")
            return nil
        }
    }
}

//Mark - TransactionItem
extension KeychainItem where O == TransactionItem {
    static var transactionService: String {
        return Bundle.main.bundleIdentifier ?? "com.aloha-marbu.transactionItem"
    }
    
    static func setTransactionItem(_ key: String, item: TransactionItem) {
        let query = KeychainItem(service: transactionService, account: key)
        do {
            try query.saveItem(item)
        } catch {
            print("Keychain Save Error: Order Item - \(error.localizedDescription)")
        }
    }
    
    static func deleteTransactionItem(_ key: String) {
        let query = KeychainItem(service: transactionService, account: key)
        do {
            try query.deleteItem()
        } catch {
            print("Keychain Delete Error: Order Item - \(error.localizedDescription)")
        }
    }
    
    static func transactionItem(_ key: String) -> TransactionItem? {
        let query = KeychainItem(service: transactionService, account: key)
        do {
            return try query.readItem()
        } catch {
            print("Keychain Read Error: Order Item - \(error.localizedDescription)")
            return nil
        }
    }
}
