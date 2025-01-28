//
//  DatabaseManager.swift
//  schoolApp1
//
//  Created by Matthias Park 2025 on 5/20/23.
//

//TODO: Memory leaks and security issues, good comments/documentation too
//TODO: failedToVerify when registering new account, cannot see convos or announcements because of it
//TODO: Simultaneous Database writes???!!!
//TODO: Enable conversation naming
//TODO: Look for database writes writing to larger amount of data than needed
//TODO: New convers prompt cut off on phones
//TODO: Change "dean" to faculty
//TODO: multiple convers made pressed 2ics]
//TODO: profiles not found aoutos
import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation
///Manager object to read and write data to real time firebase database
final class DatabaseManager {
    ///Shared instance of class
    public static let shared = DatabaseManager()
    private static var sessionProvided: Bool = false
    private let database = Database.database().reference()
}

extension DatabaseManager {
    /// Returns dictionary node at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                print("Failed to retrieve data at path \(path)")
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            print("Successfully retrieved data at path \(path)")
            completion(.success(value))
        }
    }
}

//MARK: - Account Management
extension DatabaseManager {
    /// Checks if user exists for given email
    /// Parameters
    /// - `email`:              Target email to be checked
    /// - `completion`:   Async closure to return with result
    
    public func userExists(with email: String, completion: @escaping((Bool) -> Void)) {
        getUserID(emailAddress: email, completion: { result in
            switch result {
            case .success(_):
                print("User \(email) found")
                completion(true)
            case .failure(_):
                print("User \(email) not found")
                completion(false)
            }
        })
    }
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child("profiles/\(Utilities.makeSafe(unsafeString: user.emailAddress))").setValue([
            "first_name": user.firstName,
            "last_name": user.lastName,
            "display_name": user.displayName as Any,
            "email": user.emailAddress,
            "is_dean": user.isDean,
            "grade": user.grade as Any,
            "fcm_token": user.fcmToken as Any
        ], withCompletionBlock: { error, _ in
            
            guard error == nil else {
                print("Failed to insert user to database")
                completion(false)
                return
            }
            completion(true)
//            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
//                if var usersCollection = snapshot.value as? [[String: Any]] {
//                    //append to user dictionary
//                    let newElement = [
//                        "first_name": user.firstName,
//                        "last_name": user.lastName,
//                        "display_name": user.displayName as Any,
//                        "email": user.emailAddress,
//                        "key": Utilities.makeSafe(unsafeString: user.emailAddress),
//                        "is_dean": user.isDean,
//                        "grade": user.grade as Any,
//                        "fcm_token": user.fcmToken as Any
//                    ]
//                    usersCollection.append(newElement)
//                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
//                        guard error == nil else {
//                            completion(false)
//                            return
//                        }
//                        print("Inserted user into database")
//                        completion(true)
//                    })
//                }
//                else {
//                    //create that array
//                    let newCollection: [[String: Any]] = [
//                        [
//                            "first_name": user.firstName,
//                            "last_name": user.lastName,
//                            "display_name": user.displayName as Any,
//                            "email": user.emailAddress,
//                            "key": Utilities.makeSafe(unsafeString: user.emailAddress),
//                            "is_dean": user.isDean,
//                            "grade": user.grade as Any,
//                            "fcm_token": user.fcmToken as Any
//                        ]
//                    ]
//                    
//                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
//                        guard error == nil else {
//                            print(error as Any)
//                            completion(false)
//                            return
//                        }
//                        completion(true)
//                    })
//                }
//            })
        })
    }
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[String: [String: Any]], Error>) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(.failure(DatabaseError.failedToVerify))
                return
            }
            
            strongSelf.database.child("profiles").observeSingleEvent(of: .value, with: { snapshot in
                guard let value = snapshot.value as? [String: [String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(value))
            })
        })
    }
    
    public func changeDisplayName(to newName: String?, from oldName: String?, completion: @escaping (String) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success,
                  let strongSelf = self,
                  let currentName = UserDefaults.standard.value(forKey: "name") as? String,
                  let currentKey = UserDefaults.standard.value(forKey: "key") as? String
            else {
                completion("Failed to verify.")
                return
            }
            
            let currentDisplayName = oldName ?? currentName
            
            strongSelf.database.child("profiles/\(currentKey)/display_name").setValue(newName, withCompletionBlock: { error, _ in
                guard error == nil else {
                    print("Failed to write to database")
                    completion("Failed to update display name.")
                    return
                }
                
                strongSelf.database.child("profiles/\(currentKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    if let conversations = snapshot.value as? [[String: Any]] {
                        var otherUserKeys: [String] = []
                        for conversation in conversations {
                            guard let otherConversationKeys = conversation["other_user_keys"] as? [String] else {return}
                            otherUserKeys.append(contentsOf: otherConversationKeys)
                        }
                        otherUserKeys = Array(Set(otherUserKeys))
                        
                        for otherUserKey in otherUserKeys {
                            strongSelf.database.child("profiles/\(otherUserKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                                guard let otherConversations = snapshot.value as? [[String: Any]] else {return}
                                for index in 0..<otherConversations.count {
                                    if var otherConversationUserNames = otherConversations[index]["other_user_names"] as? [String],
                                       let otherConversationUserKeys = otherConversations[index]["other_user_keys"] as? [String],
                                       otherConversationUserKeys.contains(currentKey) {
                                        var nameRemoved = false
                                        otherConversationUserNames.removeAll(where: {
                                            if $0 == currentDisplayName && !nameRemoved {
                                                nameRemoved = true
                                                return true
                                            }
                                            return false
                                        })
                                        otherConversationUserNames.append(newName ?? currentName)
                                        strongSelf.database.child("profiles/\(otherUserKey)/conversations/\(index)/other_user_names").setValue(otherConversationUserNames, withCompletionBlock: { error, _ in
                                            guard error == nil else {
                                                print("Failed to write to database")
                                                completion("Failed to apply to conversations.")
                                                return
                                            }
                                        })
                                        strongSelf.database.child("profiles/\(otherUserKey)/conversations/\(index)/conversation_name").setValue(Utilities.formatNames(names: otherConversationUserNames), withCompletionBlock: { error, _ in
                                            guard error == nil else {
                                                print("Failed to write to database")
                                                completion("Failed to apply to conversations.")
                                                return
                                            }
                                        })
                                    }
                                }
                            })
                        }
                    }
                    
//                    strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
//                        
//                        guard let usersCollection = snapshot.value as? [[String: Any]] else {
//                            completion("Failed to apply to search results.")
//                            return
//                        }
//                        
//                        var userIndex = -1
//                        for i in 0..<usersCollection.count {
//                            let user = usersCollection[i]
//                            if let email = user["email"] as? String, email == currentEmail {
//                                userIndex = i
//                            }
//                        }
//                        
//                        strongSelf.database.child("users/\(userIndex)/display_name").setValue(newName, withCompletionBlock: { error, _ in
//                            guard error == nil else {
//                                print(error as Any)
//                                completion("Failed to apply to search results.")
//                                return
//                            }
//                            
//                        })
//                    })
                })
                strongSelf.database.child("announcement_grades").observeSingleEvent(of: .value, with: { snapshot in
                    
                    guard let announcementGradesCollection = snapshot.value as? [[String: Any]] else {
                        completion("Failed to apply to announcements.")
                        return
                    }
                    
                    for index in 0..<announcementGradesCollection.count {
                        let announcementGrade = announcementGradesCollection[index]
                        guard let announcements = announcementGrade["announcements"] as? [[String: Any]], let latestAnnouncement = announcementGrade["latest_announcement"] as? [String: Any], let latestAnnouncementSenderKey = latestAnnouncement["sender_key"] as? String else {
                            completion("Failed to apply to announcements.")
                            return
                        }
                        
                        for index2 in 0..<announcements.count {
                            let announcement = announcements[index2]
                            guard let senderKey = announcement["sender_key"] as? String else {
                                completion("Failed to apply to announcements.")
                                return
                            }
                            if senderKey == currentKey {
                                strongSelf.database.child("announcement_grades/\(index)/announcements/\(index2)/sender_name").setValue(newName ?? currentName, withCompletionBlock: { error, _ in
                                    guard error == nil else {
                                        print(error as Any)
                                        completion("Failed to apply to announcements.")
                                        return
                                    }
                                })
                            }
                        }
                        
                        if latestAnnouncementSenderKey == currentKey {
                            strongSelf.database.child("announcement_grades/\(index)/latest_announcement/sender_name").setValue(newName ?? currentName, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    print(error as Any)
                                    completion("Failed to apply to announcements.")
                                    return
                                }
                            })
                        }
                    }
                })
            })
        })
    }
    
    public func getUserID(emailAddress: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("profiles").observeSingleEvent(of: .value, with: { snapshot in
            guard let profiles = snapshot.value as? [String: [String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            for profile in profiles {
                guard let profileEmail = profile.value["email"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                if profileEmail == emailAddress {
                    completion(.success(profile.key))
                    return
                }
            }
            completion(.failure(DatabaseError.failedToFetch))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
        case failedToVerify
        
        public var localizedDescription: String {
            switch self {
            case .failedToFetch:
                return "This error means that the retrieval of data from the database or client failed"
            case .failedToVerify:
                return "This error means that the verification of the user's session or status failed"
            }
        }
    }
    
    /*
     users => [
     [
     "name":
     "safe_email":
     ]
     [
     "name":
     "safe_email":
     ]
     ]
     */
}

//MARK: - Authentication and Verification
extension DatabaseManager {
    public func provideSession(for userKey: String, completion: (() -> Void)?) {
        if !DatabaseManager.sessionProvided {
            DatabaseManager.sessionProvided = true
            let newSessionID = generateSessionID()
            database.child("profiles/\(userKey)/session_id").setValue(newSessionID, withCompletionBlock: { error, _ in
                guard error == nil else {
                    print(error as Any)
                    fatalError("Failed to create new session")
                }
                UserDefaults.standard.set(newSessionID, forKey: "session_id")
                print("New session started")
                completion?()
            })
        }
        else {
            print("Could not start new session, previous session already started")
            completion?()
        }
    }
    
    private func generateSessionID() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map{ _ in characters.randomElement()!})
    }
    
    public func endSession(completion: @escaping (Bool) -> Void) {
        UserDefaults.standard.set(nil, forKey: "session_id")
        DatabaseManager.sessionProvided = false
        guard let currentKey = UserDefaults.standard.value(forKey: "key") as? String else {
            return
        }
        database.child("profiles/\(currentKey)/session_id").setValue(nil, withCompletionBlock: { error, _ in
            guard error == nil else {
                print(error as Any)
                print("Failed to end session properly")
                completion(false)
                return
            }
            print("Successfully ended session")
            completion(true)
        })
    }
    
    public func verifySession(completion: @escaping (Bool) -> Void) {
        guard let userKey = UserDefaults.standard.value(forKey: "key") as? String, let currentSessionID = UserDefaults.standard.value(forKey: "session_id") as? String else {
            print("Session information unavailable, session verification failed")
            completion(false)
            return
        }
        
        database.child("profiles/\(userKey)/session_id").observeSingleEvent(of: .value, with: { snapshot in
            guard let userSessionID = snapshot.value as? String else {
                print("Unable to retrieve session information, session verification failed")
                completion(false)
                return
            }
            
            if currentSessionID == userSessionID {
                print("Session verification successful")
                completion(true)
            }
            else {
                print("Invalid session, session verification failed")
                completion(false)
            }
        })
    }
    
    public func verifyDean(completion: @escaping (Bool) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self, let userKey = UserDefaults.standard.value(forKey: "key") as? String else {
                print("Status Verification Failed")
                completion(false)
                return
            }
            
            strongSelf.database.child("profiles/\(userKey)/is_dean").observeSingleEvent(of: .value, with: { snapshot in
                guard let isDean = snapshot.value as? Bool else {
                    print("Status Verification Failed")
                    completion(false)
                    return
                }
                
                if isDean {
                    print("Status Verification Successful")
                    completion(true)
                }
                else {
                    print("Status Verification Failed")
                    completion(false)
                }
            })
        })
    }
}

// MARK: - Messages and Conversations
extension DatabaseManager {
    /*
     "dfsdfdsfds" {
     "messages": [{
     "id": String,
     "type": text, photo, video,
     "content": String,
     "date": Date(),
     "sender_key": String,
     "isRead": true/false,
     }
     ]
     }
     
     conversation => [
     [
     "conversation_id": "dfsdfdsfds"
     "other_user_email":
     "latest_message": => {
     "date": Date()
     "latest_message": "message"
     "is_read": true/false
     }
     ],
     ]
     */
    
    /// Creates a new conversation with target user emails and first message sent
    public func createNewConversation(with otherUserKeys: [String], otherUserNames: [String], firstMessage: Message, completion: @escaping (Bool) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self, let currentKey = UserDefaults.standard.value(forKey: "key") as? String,
                  var currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                completion(false)
                return
            }
            
            if let displayName = UserDefaults.standard.value(forKey: "display_name") as? String {
                currentName = displayName
            }
            
            var allUserKeys = otherUserKeys
            allUserKeys.append(currentKey)
            
            strongSelf.database.child("profiles/\(currentKey)").observeSingleEvent(of: .value, with: { snapshot in
                guard var userNode = snapshot.value as? [String: Any] else {
                    completion(false)
                    print("User not found")
                    return
                }
                
                let messageDate = firstMessage.sentDate
                let dateString = Utilities.dateFormatter.string(from: messageDate)
                
                var message = ""
                
                switch firstMessage.kind {
                case .text(let messageText):
                    message = messageText
                case .photo(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                case .video(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                case .location(let locationData):
                    let location = locationData.location
                    message = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                case .attributedText(_), .emoji(_), .audio(_), .contact(_), .custom(_), .linkPreview(_):
                    break
                }
                
                let conversationId = "conversation_\(firstMessage.messageId)"
                
                let messageType = firstMessage.kind.messageKindString
                
                var latestMessage: [String: Any]
                if messageType == "photo" {
                    latestMessage = [
                        "date": dateString,
                        "message": "Photo Message",
                        "is_read": true
                    ]
                }
                else {
                    latestMessage = [
                        "date": dateString,
                        "message": message,
                        "is_read": true
                    ]
                }
                
                let newConversationData: [String: Any] = [
                    "id": conversationId,
                    "other_user_keys": otherUserKeys,
                    "other_user_names": otherUserNames,
                    "conversation_name": Utilities.formatNames(names: otherUserNames),
                    "latest_message": latestMessage
                ]
                //Update recipient conversation entry
                
                for index in 0...otherUserKeys.count - 1 {
                    let recipientKey = otherUserKeys[index]
                    let recipientName = otherUserNames[index]
                    
                    var otherKeysExcludingRecipient: [String] = []
                    otherKeysExcludingRecipient.append(currentKey)
                    for otherKey in otherUserKeys {
                        if otherKey != recipientKey {
                            otherKeysExcludingRecipient.append(otherKey)
                        }
                    }
                    
                    var otherNamesExcludingRecipient: [String] = []
                    otherNamesExcludingRecipient.append(currentName)
                    for otherName in otherUserNames {
                        if otherName != recipientName {
                            otherNamesExcludingRecipient.append(otherName)
                        }
                    }
                    
                    var recipientLatestMessage: [String: Any]
                    
                    if messageType == "photo" {
                        recipientLatestMessage = [
                            "date": dateString,
                            "message": "Photo Message",
                            "is_read": false
                        ]
                    }
                    else {
                        recipientLatestMessage = [
                            "date": dateString,
                            "message": message,
                            "is_read": false
                        ]
                    }
                    
                    let recipientNewConversationData: [String: Any] = [
                        "id": conversationId,
                        "other_user_keys": otherKeysExcludingRecipient,
                        "other_user_names": otherNamesExcludingRecipient,
                        "conversation_name": Utilities.formatNames(names: otherNamesExcludingRecipient),
                        "latest_message": recipientLatestMessage
                    ]
                    
                    strongSelf.database.child("profiles/\(recipientKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                        if var conversations = snapshot.value as? [[String: Any]] {
                            //append
                            conversations.append(recipientNewConversationData)
                            strongSelf.database.child("profiles/\(recipientKey)/conversations").setValue(conversations)
                        }
                        else {
                            //create
                            strongSelf.database.child("profiles/\(recipientKey)/conversations").setValue([recipientNewConversationData])
                        }
                    })
                }
                //Update current user conversation entry
                if var conversations = userNode["conversations"] as? [[String: Any]] {
                    // conversation array exists for current user
                    // you should append
                    
                    conversations.append(newConversationData)
                    userNode["conversations"] = conversations
                    strongSelf.database.child("profiles/\(currentKey)").setValue(userNode, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        strongSelf.finishCreatingConversation(conversationID: conversationId, userKeys: allUserKeys, firstMessage: firstMessage, completion: completion)
                    })
                }
                else {
                    // conversation array does NOT exist
                    // create it
                    userNode["conversations"] = [
                        newConversationData
                    ]
                    
                    strongSelf.database.child("profiles/\(currentKey)").setValue(userNode, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        strongSelf.finishCreatingConversation(conversationID: conversationId, userKeys: allUserKeys, firstMessage: firstMessage, completion: completion)
                    })
                }
            })
        })
    }
    
    private func finishCreatingConversation(conversationID: String, userKeys: [String], firstMessage: Message, completion: @escaping (Bool) -> Void) {
        //        {
        //            "id": String,
        //            "type": text, photo, video,
        //            "content": String,
        //            "date": Date(),
        //            "sender_key": String,
        //            "isRead": true/false,
        //        }
        
        let messageDate = firstMessage.sentDate
        let dateString = Utilities.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                message = targetUrlString
            }
        case .video(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                message = targetUrlString
            }
        case .location(let locationData):
            let location = locationData.location
            message = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
        case .attributedText(_), .emoji(_), .audio(_), .contact(_), .custom(_), .linkPreview(_):
            break
        }
        
        guard let myKey = UserDefaults.standard.value(forKey: "key") as? String,
              var currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            completion(false)
            return
        }
        
        if let displayName = UserDefaults.standard.value(forKey: "display_name") as? String {
            currentName = displayName
        }
        
        var otherUserKeys = userKeys
        otherUserKeys.removeAll(where: {$0 == myKey})
        
        getFCMTokens(fcmTokens: [], otherUserKeys: otherUserKeys, completion: { [weak self] result in
            switch result {
            case .success(let fcmTokens):
                guard let strongSelf = self else {
                    completion(false)
                    return
                }
                
                let collectionMessage: [String: Any] = [
                    "id": firstMessage.messageId,
                    "type": firstMessage.kind.messageKindString,
                    "content": message,
                    "date": dateString,
                    "sender_key": myKey,
                    "sender_name": currentName,
                    "fcm_tokens": fcmTokens,
                    "is_read": false,
                    "first": true
                ]
                
                let value: [String: Any] = [
                    "user_keys": userKeys,
                    "messages": [
                        collectionMessage
                    ]
                ]
                
                print("Adding conversation: \(conversationID)")
                
                strongSelf.database.child("conversations/\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    completion(true)
                })
            case .failure(let error):
                print("Failed to get FCM tokens when sending first message, error: \(error)")
                completion(false)
            }
        })
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for key: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(.failure(DatabaseError.failedToVerify))
                return
            }
            strongSelf.database.child("profiles/\(key)/conversations").observe(.value, with: { snapshot in
                guard let value = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                let conversations: [Conversation] = value.compactMap({ dictionary in
                    guard let conversationId = dictionary["id"] as? String, let conversationName = dictionary["conversation_name"] as? String, let otherUserKeys = dictionary["other_user_keys"] as? [String], let otherUserNames = dictionary["other_user_names"] as? [String], let latestMessage = dictionary["latest_message"] as? [String: Any], let date = latestMessage["date"] as? String, let message = latestMessage["message"] as? String, let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                    }
                    
                    let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                    return Conversation(id: conversationId, conversationName: conversationName, otherUserNames: otherUserNames, otherUserKeys: otherUserKeys, latestMessage: latestMessageObject)
                })
                completion(.success(conversations))
            })
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(.failure(DatabaseError.failedToVerify))
                return
            }
            strongSelf.database.child("conversations/\(id)/messages").observe(.value, with: { snapshot in
                guard let value = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                let messages: [Message] = value.compactMap({ dictionary in
                    guard let senderName = dictionary["sender_name"] as? String,
                          let isRead = dictionary["is_read"] as? Bool,
                          let messageID = dictionary["id"] as? String,
                          let content = dictionary["content"] as? String,
                          let senderKey = dictionary["sender_key"] as? String,
                          let type = dictionary["type"] as? String,
                          let dateString = dictionary["date"] as? String,
                          let date = Utilities.dateFormatter.date(from: dateString) else {
                        return nil
                    }
                    var kind: MessageKind?
                    if type == "photo" {
                        // photo
                        guard let imageUrl = URL(string: content),
                              let placeHolder = UIImage(systemName: "photo") else {
                            return nil
                        }
                        let media = Media(url: imageUrl,
                                          image: nil,
                                          placeholderImage: placeHolder,
                                          size: CGSize(width: 300, height: 300))
                        kind = .photo(media)
                    }
                    else if type == "video" {
                        // video
                        guard let videoUrl = URL(string: content),
                              let placeHolder = UIImage(systemName: "display") else {
                            return nil
                        }
                        
                        let media = Media(url: videoUrl,
                                          image: nil,
                                          placeholderImage: placeHolder,
                                          size: CGSize(width: 300, height: 300))
                        kind = .video(media)
                    }
                    else if type == "location" {
                        let locationComponents = content.components(separatedBy: ",")
                        guard let latitude = Double(locationComponents[0]),
                              let longitude = Double(locationComponents[1]) else {
                            return nil
                        }
                        print("Rendering location: long = \(longitude) | lat = \(latitude)")
                        let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                                size: CGSize(width: 300, height: 300))
                        kind = .location(location)
                    }
                    else {
                        kind = .text(content)
                    }
                    
                    guard let finalKind = kind else {
                        return nil
                    }
                    
                    let sender = Sender(photoURL: "",
                                        senderId: senderKey,
                                        displayName: senderName)
                    
                    return Message(sender: sender,
                                   messageId: messageID,
                                   sentDate: date,
                                   kind: finalKind)
                })
                
                completion(.success(messages))
            })
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserKeys: [String], otherUserNames: [String], fcmTokens: [String], newMessage: Message, completion: @escaping (Bool) -> Void) {
        //add new message to messages
        //update sender latest message
        //update recipient latest message
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self, let myKey = UserDefaults.standard.value(forKey: "key") as? String,
                  var currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                completion(false)
                return
            }
            
            if let displayName = UserDefaults.standard.value(forKey: "display_name") as? String {
                currentName = displayName
            }
            
            strongSelf.database.child("conversations/\(conversation)/messages").observeSingleEvent(of: .value, with: { snapshot in
                guard var currentMessages = snapshot.value as? [[String: Any]] else {
                    completion(false)
                    return
                }
                
                let messageDate = newMessage.sentDate
                let dateString = Utilities.dateFormatter.string(from: messageDate)
                
                var message = ""
                switch newMessage.kind {
                case .text(let messageText):
                    message = messageText
                case .photo(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                case .video(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                case .location(let locationData):
                    let location = locationData.location
                    message = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                case .attributedText(_), .emoji(_), .audio(_), .contact(_), .custom(_), .linkPreview(_):
                    break
                }
                
                let messageType = newMessage.kind.messageKindString
                
                print(fcmTokens)
                
                let newMessageEntry: [String: Any] = [
                    "id": newMessage.messageId,
                    "type": messageType,
                    "content": message,
                    "date": dateString,
                    "sender_key": myKey,
                    "sender_name": currentName,
                    "fcm_tokens": fcmTokens,
                    "is_read": false
                ]
                
                currentMessages.append(newMessageEntry)
                
                strongSelf.database.child("conversations/\(conversation)/messages").setValue(currentMessages) {error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    strongSelf.database.child("profiles/\(myKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                        var databaseEntryConversations = [[String: Any]]()
                        var updatedValue: [String: Any] = [:]
                        if messageType == "photo" {
                            updatedValue = [
                                "date": dateString,
                                "is_read": true,
                                "message": "Photo Message"
                            ]
                        }
                        else {
                            updatedValue = [
                                "date": dateString,
                                "is_read": true,
                                "message": message
                            ]
                        }

                        if var currentUserConversations = snapshot.value as? [[String: Any]] {
                            var targetConversation: [String: Any]?
                            
                            var position = 0
                            
                            for conversationDictionary in currentUserConversations {
                                if let currentId = conversationDictionary["id"] as? String,
                                   currentId == conversation {
                                    targetConversation = conversationDictionary
                                    
                                    break
                                }
                                position += 1
                            }
                            
                            if var targetConversation = targetConversation {
                                targetConversation["latest_message"] = updatedValue
                                currentUserConversations[position] = targetConversation
                                databaseEntryConversations = currentUserConversations
                            }
                            else {
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_keys": otherUserKeys,
                                    "other_user_names": otherUserNames,
                                    "conversation_name": Utilities.formatNames(names: otherUserNames),
                                    "latest_message": updatedValue
                                ]
                                currentUserConversations.append(newConversationData)
                                databaseEntryConversations = currentUserConversations
                            }
                        }
                        else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_keys": otherUserKeys,
                                "other_user_names": otherUserNames,
                                "conversation_name": Utilities.formatNames(names: otherUserNames),
                                "latest_message": updatedValue
                            ]
                            databaseEntryConversations = [
                                newConversationData
                            ]
                        }
                        
                        strongSelf.database.child("profiles/\(myKey)/conversations").setValue(databaseEntryConversations, withCompletionBlock: {error, _ in
                            guard error == nil else{
                                completion(false)
                                return
                            }
                            
                            // Update latest message for recipient user
                            
                            for index in 0...otherUserKeys.count - 1 {
                                let recipientKey = otherUserKeys[index]
                                let recipientName = otherUserNames[index]
                                
                                var otherKeysExcludingRecipient: [String] = []
                                otherKeysExcludingRecipient.append(myKey)
                                for otherKey in otherUserKeys {
                                    if otherKey != recipientKey {
                                        otherKeysExcludingRecipient.append(otherKey)
                                    }
                                }
                                
                                var otherNamesExcludingRecipient: [String] = []
                                otherNamesExcludingRecipient.append(currentName)
                                for otherName in otherUserNames {
                                    if otherName != recipientName {
                                        otherNamesExcludingRecipient.append(otherName)
                                    }
                                }
                                
                                strongSelf.database.child("profiles/\(recipientKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                                    var databaseEntryConversations = [[String: Any]]()
                                    let updatedValue: [String: Any] = [
                                        "date": dateString,
                                        "is_read": false,
                                        "message": message
                                    ]
                                    
                                    if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                        var targetConversation: [String: Any]?
                                        
                                        var position = 0
                                        
                                        for conversationDictionary in otherUserConversations {
                                            if let currentId = conversationDictionary["id"] as? String,
                                               currentId == conversation {
                                                targetConversation = conversationDictionary
                                                
                                                break
                                            }
                                            position += 1
                                        }
                                        if var targetConversation = targetConversation {
                                            targetConversation["latest_message"] = updatedValue
                                            otherUserConversations[position] = targetConversation
                                            databaseEntryConversations = otherUserConversations
                                        }
                                        else {
                                            // Failed to find in current collection
                                            let newConversationData: [String: Any] = [
                                                "id": conversation,
                                                "other_user_keys": otherKeysExcludingRecipient,
                                                "other_user_names": otherNamesExcludingRecipient,
                                                "conversation_name": Utilities.formatNames(names: otherNamesExcludingRecipient),
                                                "latest_message": updatedValue
                                            ]
                                            otherUserConversations.append(newConversationData)
                                            databaseEntryConversations = otherUserConversations
                                        }
                                    }
                                    else {
                                        // Current collection does not exist
                                        let newConversationData: [String: Any] = [
                                            "id": conversation,
                                            "other_user_keys": otherKeysExcludingRecipient,
                                            "other_user_names": otherNamesExcludingRecipient,
                                            "conversation_name": Utilities.formatNames(names: otherNamesExcludingRecipient),
                                            "latest_message": updatedValue
                                        ]
                                        databaseEntryConversations = [
                                            newConversationData
                                        ]
                                    }
                                    
                                    
                                    strongSelf.database.child("profiles/\(recipientKey)/conversations").setValue(databaseEntryConversations, withCompletionBlock: {error, _ in
                                        guard error == nil else{
                                            completion(false)
                                            return
                                        }
                                        completion(true)
                                    })
                                })
                            }
                        })
                    })
                }
            })
        })
    }
    
    public func updateLatestMessageIsRead(for conversation: String, completion: @escaping (Bool) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self, let currentKey = UserDefaults.standard.value(forKey: "key") as? String else {
                completion(false)
                return
            }
            
            strongSelf.database.child("profiles/\(currentKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                guard var conversationsCollection = snapshot.value as? [[String: Any]] else {
                    completion(false)
                    return
                }
                
                for index in 0...conversationsCollection.count - 1 {
                    guard let conversationID = conversationsCollection[index]["id"] as? String else {
                        completion(false)
                        return
                    }
                    
                    if conversationID == conversation {
                        guard var updatedLatestMessage = conversationsCollection[index]["latest_message"] as? [String: Any] else {
                            completion(false)
                            return
                        }
                        
                        updatedLatestMessage.updateValue(true, forKey: "is_read")
                        conversationsCollection[index].updateValue(updatedLatestMessage, forKey: "latest_message")
                    }
                    strongSelf.database.child("profiles/\(currentKey)/conversations").setValue(conversationsCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            print("Failed to write to database")
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                return
            }
            
            print("Deleting conversation with id: \(conversationId)")
            
            // Get all conversations for current user
            // delete conversation in collection with target id
            // reset those conversations for the user in database
            strongSelf.database.child("conversations/\(conversationId)").observeSingleEvent(of: .value, with: { snapshot in
                guard let conversation = snapshot.value as? [String : Any], let userKeys = conversation["user_keys"] as? [String] else {
                    completion(false)
                    return
                }
                strongSelf.database.child("archive/conversations/\(conversationId)").setValue(conversation, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        print("Failed to archive and delete conversation")
                        completion(false)
                        return
                    }
                    strongSelf.finishRemovingConversation(for: userKeys, with: conversationId, completion: completion)
                })
            })
        })
    }
    
    public func finishRemovingConversation(for userKeys: [String], with conversationId: String, completion: @escaping (Bool) -> Void) {
        let userKey = userKeys[0]
        let ref = database.child("profiles/\(userKey)/conversations")
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self, var conversations = snapshot.value as? [[String: Any]] else {
                print("Failed to remove conversation from user")
                completion(false)
                return
            }
            var positionToRemove = 0
            var foundConversation = false
            while !foundConversation {
                let conversation = conversations[positionToRemove]
                if let id = conversation["id"] as? String, id == conversationId {
                    foundConversation = true
                }
                else {
                    positionToRemove += 1
                }
            }
            
            conversations.remove(at: positionToRemove)
            ref.setValue(conversations, withCompletionBlock: { error, _  in
                guard error == nil else {
                    print("Failed to remove conversation from user")
                    completion(false)
                    return
                }
                var nextUserKeys = userKeys
                nextUserKeys.removeFirst()
                if !nextUserKeys.isEmpty {
                    strongSelf.finishRemovingConversation(for: nextUserKeys, with: conversationId, completion: completion)
                }
                else {
                    strongSelf.database.child("conversations").observeSingleEvent(of: .value, with: { snapshot in
                        guard let oldConversations = snapshot.value as? [String : [String : Any]] else {
                            completion(false)
                            return
                        }
                        var newConversations = oldConversations
                        newConversations.removeValue(forKey: conversationId)
                        strongSelf.database.child("conversations").setValue(newConversations, withCompletionBlock: { error, _  in
                            guard error == nil else {
                                print("Failed to remove conversation data")
                                completion(false)
                                return
                            }
                            print("Successfully deleted conversation")
                            completion(true)
                        })
                    })
                }
            })
        })
    }
    
    public func conversationExists(with targetRecipientKeys: [String], completion: @escaping (Result<String, Error>) -> Void) {
        guard let senderKey = UserDefaults.standard.value(forKey: "key") as? String else {
            return
        }
        
        database.child("profiles/\(senderKey)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            // Iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderKeys = $0["other_user_keys"] as? [String] else {
                    return false
                }
                return targetRecipientKeys.difference(from: targetSenderKeys).isEmpty
            }) {
                // Get id
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}

// MARK: - Announcements

extension DatabaseManager {
    public func createNewAnnouncementGrade(for grade: Int, completion: @escaping (Bool) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self, let currentKey = UserDefaults.standard.value(forKey: "key") as? String,
                  var currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                completion(false)
                return
            }
            
            if let displayName = UserDefaults.standard.value(forKey: "display_name") as? String {
                currentName = displayName
            }
            
            let newAnnouncementGrade = [[
                "grade": grade,
                "announcements": [[
                    "title": "Welcome!",
                    "body": "This is the \(Utilities.formatGrade(grade: grade)) announcements page.",
                    "links": nil,
                    "grade": grade,
                    "sent_date": Utilities.dateFormatter.string(from: Date().addingTimeInterval(-10)),
                    "sender_key": currentKey,
                    "sender_name": currentName,
                    "announcement_id": "grade_\(grade)_announcement_\(currentKey)_\(Utilities.dateFormatter.string(from: Date().addingTimeInterval(-10)))",
                    "pinned": false
                ]],
                "latest_announcement": [
                    "sent_date": Utilities.dateFormatter.string(from: Date().addingTimeInterval(-10)),
                    "title": "Welcome!",
                    "sender_name": currentName,
                    "sender_key": currentKey
                ]]] as [[String: Any]]
            
            strongSelf.database.child("announcement_grades").observeSingleEvent(of: .value, with: { snapshot in
                strongSelf.database.child("announcement_grades").setValue(newAnnouncementGrade, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                })
                
                if var announcementGrades = snapshot.value as? [[String: Any]] {
                    var gradeIndex: Int = 0
                    
                    for index in 0..<announcementGrades.count {
                        guard let compareGrade = announcementGrades[index]["grade"] as? Int else {
                            completion(false)
                            return
                        }
                        if compareGrade < grade {
                            gradeIndex = index + 1
                        }
                    }
                    
                    announcementGrades.insert(contentsOf: newAnnouncementGrade, at: gradeIndex)
                    strongSelf.database.child("announcement_grades").setValue(announcementGrades, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                    })
                }
                else {
                    strongSelf.database.child("announcement_grades").setValue(newAnnouncementGrade, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                    })
                }
                completion(true)
            })
        })
    }
    
    public func createNewAnnouncement(with newAnnouncement: Announcement, completion: @escaping (Bool) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(false)
                return
            }
            
            let newAnnouncementEntry = [
                "title": newAnnouncement.title,
                "body": newAnnouncement.body,
                "links": newAnnouncement.links as Any,
                "grade": newAnnouncement.grade,
                "sent_date": newAnnouncement.sentDate,
                "sender_key": newAnnouncement.senderKey,
                "sender_name": newAnnouncement.senderName,
                "announcement_id": newAnnouncement.announcementId,
                "pinned": newAnnouncement.pinned
            ] as [String : Any]
            
            strongSelf.database.child("announcement_grades").observeSingleEvent(of: .value, with: { snapshot in
                if var announcementGrades = snapshot.value as? [[String: Any]] {
                    for index in 0...announcementGrades.count - 1 {
                        guard let checkGrade = announcementGrades[index]["grade"] as? Int else {
                            completion(false)
                            return
                        }
                        
                        if checkGrade == newAnnouncement.grade {
                            guard var announcements = announcementGrades[index]["announcements"] as? [[String: Any]] else {
                                completion(false)
                                return
                            }
                            announcements.append(newAnnouncementEntry)
                            announcementGrades[index].updateValue(announcements, forKey: "announcements")
                            
                            let newLatestAnnouncementEntry = [
                                "sent_date": newAnnouncement.sentDate,
                                "title": newAnnouncement.title,
                                "sender_name": newAnnouncement.senderName,
                                "sender_key": newAnnouncement.senderKey
                            ]
                            announcementGrades[index].updateValue(newLatestAnnouncementEntry, forKey: "latest_announcement")
                        }
                    }
                    strongSelf.database.child("announcement_grades").setValue(announcementGrades, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                else {
                    completion(false)
                }
            })
        })
    }
    
    public func getAllAnnouncementGrades(completion: @escaping (Result<[AnnouncementGrade], Error>) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(.failure(DatabaseError.failedToVerify))
                return
            }
            strongSelf.database.child("announcement_grades").observe(.value, with: { snapshot in
                guard let value = snapshot.value as? [[String: Any]], let userGrade = UserDefaults.standard.value(forKey: "grade") as? Int? else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                let announcementGrades: [AnnouncementGrade] = value.compactMap({ dictionary in
                    guard let grade = dictionary["grade"] as? Int, let latestAnnouncement = dictionary["latest_announcement"] as? [String: Any], let date = latestAnnouncement["sent_date"] as? String, let title = latestAnnouncement["title"] as? String, let sender = latestAnnouncement["sender_name"] as? String, let senderKey = latestAnnouncement["sender_key"] as? String, userGrade == grade || userGrade == nil else {
                        return nil
                    }
                    
                    let latestAnnouncementObject = LatestAnnouncement(sentDate: date, title: title, senderName: sender, senderKey: senderKey)
                    return AnnouncementGrade(grade: grade, latestAnnouncement: latestAnnouncementObject)
                })
                completion(.success(announcementGrades))
            })
        })
    }
    public func getAllAnnouncements(for grade: Int, completion: @escaping (Result<[Announcement], Error>) -> Void) {
        verifySession(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(.failure(DatabaseError.failedToVerify))
                return
            }
            strongSelf.database.child("announcement_grades").observe(.value, with: { snapshot in
                guard let announcementGrades = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                var announcementsList: [[String: Any]] = []
                for index in 0...announcementGrades.count - 1 {
                    guard let checkGrade = announcementGrades[index]["grade"] as? Int else {
                        completion(.failure(DatabaseError.failedToFetch))
                        return
                    }
                    
                    if checkGrade == grade {
                        guard let announcementsCollection = announcementGrades[index]["announcements"] as? [[String: Any]] else {
                            completion(.failure(DatabaseError.failedToFetch))
                            return
                        }
                        announcementsList = announcementsCollection
                    }
                }
                
                let announcements: [Announcement] = announcementsList.compactMap({ dictionary in
                    guard let announcementTitle = dictionary["title"] as? String, let announcementBody = dictionary["body"] as? String, let announcementLinks = dictionary["links"] as? [String]?, let announcementGrade = dictionary["grade"] as? Int, let announcementDate = dictionary["sent_date"] as? String, let announcementKey = dictionary["sender_key"] as? String, let announcementName = dictionary["sender_name"] as? String, let announcementId = dictionary["announcement_id"] as? String, let pinned = dictionary["pinned"] as? Bool else {
                        return nil
                    }
                    
                    return Announcement(title: announcementTitle, body: announcementBody, links: announcementLinks, grade: announcementGrade, sentDate: announcementDate, senderKey: announcementKey, senderName: announcementName, announcementId: announcementId, pinned: pinned)
                })
                
                completion(.success(announcements))
            })
        })
    }
    public func changeAnnouncementPinned(to pinned: Bool, announcementId: String, grade: Int, completion: @escaping (Bool) -> Void) {
        verifyDean(completion: { [weak self] success in
            guard success, let strongSelf = self else {
                completion(false)
                return
            }
            strongSelf.database.child("announcement_grades").observeSingleEvent(of: .value, with: { snapshot in
                guard let announcementGrades = snapshot.value as? [[String: Any]] else {
                    completion(false)
                    return
                }
                
                var newAnnouncementGrades: [[String: Any]] = []
                for announcementGrade in announcementGrades {
                    guard let checkGrade = announcementGrade["grade"] as? Int else {
                        completion(false)
                        return
                    }
                    
                    var newAnnouncementGrade = announcementGrade
                    
                    if checkGrade == grade {
                        guard let announcements = announcementGrade["announcements"] as? [[String: Any]] else {
                            completion(false)
                            return
                        }
                        
                        var newAnnouncements: [[String: Any]] = []
                        
                        for announcement in announcements {
                            guard let checkAnnouncementId = announcement["announcement_id"] as? String else {
                                completion(false)
                                return
                            }
                            
                            var newAnnouncement = announcement
                            if checkAnnouncementId == announcementId {
                                newAnnouncement.updateValue(pinned, forKey: "pinned")
                            }
                            newAnnouncements.append(newAnnouncement)
                        }
                        newAnnouncementGrade.updateValue(newAnnouncements, forKey: "announcements")
                    }
                    newAnnouncementGrades.append(newAnnouncementGrade)
                }
                strongSelf.database.child("announcement_grades").setValue(newAnnouncementGrades, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        print(error as Any)
                        completion(false)
                        return
                    }
                    completion(true)
                })
            })
        })
    }
}

// MARK: - Notifications

extension DatabaseManager {
    public func uploadFCMToken(token: String?, completion: @escaping (Bool) -> Void) {
        guard let userEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let userKey = UserDefaults.standard.value(forKey: "key") as? String
        else {
            completion(false)
            return
        }
        database.child("profiles/\(userKey)/fcm_token").setValue(token, withCompletionBlock: { error, _ in
            guard error == nil else {
                print("Failed to add FCM Token to user account info")
                completion(false)
                return
            }
        })
        completion(true)
//        database.child("users").observeSingleEvent(of: .value, with: { [weak self] snapshot in
//            guard let strongSelf = self, let userInfo = snapshot.value as? [[String: Any]] else {
//                completion(false)
//                return
//            }
//            var index = -1
//            for i in 0..<userInfo.count {
//                
//                let userIndex = userInfo[i]
//                if let userIndexEmail = userIndex["email"] as? String, userIndexEmail == userEmail {
//                    index = i
//                }
//            }
//            var newUserInfo = userInfo[index]
//            newUserInfo.updateValue(token as Any, forKey: "fcm_token")
//            strongSelf.database.child("users/\(index)").setValue(newUserInfo, withCompletionBlock: { error, _ in
//                guard error == nil else {
//                    print("Failed to add FCM Token to users account list info")
//                    completion(false)
//                    return
//                }
//            })
//        })
    }
    
    public func getFCMTokens(fcmTokens: [String], otherUserKeys: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        var fcmTokensTemp = fcmTokens
        database.child("profiles/\(otherUserKeys[fcmTokensTemp.count])/fcm_token").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            var newOtherKeys = otherUserKeys
            
            if let fcmToken = snapshot.value as? String {
                fcmTokensTemp.append(fcmToken)
            }
            else {
                newOtherKeys.remove(at: fcmTokens.count)
            }
            if (fcmTokensTemp.count == newOtherKeys.count){
                completion(.success(fcmTokensTemp))
            }
            else {
                strongSelf.getFCMTokens(fcmTokens: fcmTokensTemp, otherUserKeys: newOtherKeys, completion: completion)
            }
        })
    }
    
//    public func clearFCMToken(for userEmail: String) {
//        let safeEmail = Utilities.safeEmail(emailAddress: userEmail)
//        database.child("\(safeEmail)/fcm_token").setValue(nil, withCompletionBlock: { error, _ in
//            guard error == nil else {
//                print("Failed to clear FCM token")
//                return
//            }
//        })
//    }
}
