//
//  ChatAppUser.swift
//  schoolApp1
//
//  Created by Matthias Park 2025 on 7/17/23.
//

import Foundation

struct ChatAppUser
{
    let firstName: String
    let lastName: String
    let displayName: String?
    let emailAddress: String
    let isDean: Bool
    let grade: Int?
    let fcmToken: String?
    
    var profilePictureFileName: String {
        let pathEmail = Utilities.makeSafe(unsafeString: emailAddress)
        return "\(pathEmail)_profile_picture.png"
    }
}
