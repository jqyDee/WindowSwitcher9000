//
//  NotificationService.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.01.26.
//


import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    // A generic function that takes any title and body
    func dispatch(title: String, message: String, identifier: String = UUID().uuidString) {
        guard UserDefaults.standard.bool(forKey: "IsDebugMode") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = nil

        // We use an identifier so we can update or replace specific notifications if needed
        let request = UNNotificationRequest(
            identifier: identifier, 
            content: content, 
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification Error: \(error.localizedDescription)")
            }
        }
    }
}
