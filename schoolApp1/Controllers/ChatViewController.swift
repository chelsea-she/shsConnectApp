//
//  ChatViewController.swift
//  schoolApp1
//
//  Created by Matthias Park 2025 on 5/28/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation
import FirebaseFunctions

final class ChatViewController: MessagesViewController {
    lazy var functions = Functions.functions()
    
    private var userPhotoURLs: [String: URL?] = [:]
    
    private let otherUserKeys: [String]
    private let otherUserNames: [String]
    private var conversationId: String?
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let key = UserDefaults.standard.value(forKey: "key") as? String else {
            return nil
        }
        
        return Sender(photoURL: "", senderId: key, displayName: "Me")
    }
    
    private let newConversationLabel: UILabel = {
        let label = UILabel()
        label.text = "To make a new conversation, send your first message!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    init(with keys: [String], names: [String], id: String?) {
        self.conversationId = id
        self.otherUserKeys = keys
        self.otherUserNames = names
        
        super.init(nibName: nil, bundle: nil)
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(newConversationLabel)
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setUpInputButton()
        
        newConversationLabel.isHidden = !isNewConversation
        
        if let url = UserDefaults.standard.value(forKeyPath: "profile_picture_url") as? URL,
           let currentKey = UserDefaults.standard.value(forKeyPath: "key") as? String {
            userPhotoURLs.updateValue(url, forKey: currentKey)
        }
    }
    
    private func setUpInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionsheet()
        }))
//        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self]  _ in
//            self?.presentVideoInputActionsheet()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self]  _ in
//            self?.presentLocationPicker()
//        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        actionSheet.popoverPresentationController?.sourceView = view
        actionSheet.popoverPresentationController?.sourceRect = CGRect(x: 0, y: view.height - 100, width: view.width, height: 10)
        
        present(actionSheet, animated: true)
    }
    
    private func presentPhotoInputActionsheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "Where would you like to attach a photo from",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        actionSheet.popoverPresentationController?.sourceView = view
        actionSheet.popoverPresentationController?.sourceRect = CGRect(x: 0, y: view.height - 100, width: view.width, height: 10)
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionsheet() {
        let actionSheet = UIAlertController(title: "Attach Video",
                                            message: "Where would you like to attach a video from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Video Library", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        actionSheet.popoverPresentationController?.sourceView = view
        actionSheet.popoverPresentationController?.sourceRect = CGRect(x: 0, y: view.height - 100, width: view.width, height: 10)
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoorindates in
            
            guard let strongSelf = self else {
                return
            }
            
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let selfSender = strongSelf.selfSender else {
                return
            }
            
            let longitude: Double = selectedCoorindates.longitude
            let latitude: Double = selectedCoorindates.latitude
            
            print("long=\(longitude) | lat= \(latitude)")
            
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                    size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            DatabaseManager.shared.getFCMTokens(fcmTokens: [], otherUserKeys: strongSelf.otherUserKeys, completion: { result in
                switch result {
                case .success(let fcmTokens):
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserKeys: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, fcmTokens: fcmTokens, newMessage: message, completion: { success in
                        if success {
                            print("Sent location message")
                        }
                        else {
                            print("Failed to send location message")
                        }
                    })
                case .failure(let error):
                    print("Failed to get FCM Tokens: \(error)")
                }
            })
            
            
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard let latestMessage = messages.last, !messages.isEmpty else {return}
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
                
                switch latestMessage.kind {
                    
                case .text(let messageText):
                    break
                case .attributedText(_):
                    break
                case .photo(_):
                    break
                case .video(_):
                    break
                case .location(_):
                    break
                case .emoji(_):
                    break
                case .audio(_):
                    break
                case .contact(_):
                    break
                case .custom(_), .linkPreview(_):
                    break
                }
                
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        newConversationLabel.frame = CGRect(x: 10, y: (view.height - 100) / 2, width: view.width - 20, height: 100)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = createMessageId(),
              let selfSender = selfSender else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // Upload image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Photo: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "photo") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    if strongSelf.isNewConversation {
                        //create convo in database
                        DatabaseManager.shared.createNewConversation(with: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, firstMessage: message, completion: { success in
                            if success {
                                print("Message sent")
                                strongSelf.isNewConversation = false
                                strongSelf.newConversationLabel.isHidden = true
                                let newConversationId = "conversation_\(message.messageId)"
                                strongSelf.conversationId = newConversationId
                                strongSelf.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                            }
                            else {
                                print("Failed to send")
                            }
                        })
                    }
                    else {
                        guard let conversationId = strongSelf.conversationId else {
                            print("Failed to send photo message")
                            return
                        }
                        DatabaseManager.shared.getFCMTokens(fcmTokens: [], otherUserKeys: strongSelf.otherUserKeys, completion: { result in
                            switch result {
                            case .success(let fcmTokens):
                                DatabaseManager.shared.sendMessage(to: conversationId, otherUserKeys: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, fcmTokens: fcmTokens, newMessage: message, completion: { success in
                                    
                                    if success {
                                        print("Sent photo message")
                                    }
                                    else {
                                        print("Failed to send photo message")
                                    }
                                    
                                })
                            case .failure(let error):
                                print("Failed to get FCM Tokens: \(error)")
                            }
                        })
                    }
                case .failure(let error):
                    print("Message photo upload error: \(error)")
                }
            })
        }
        else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            // Upload Video

            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Video: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "display") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    if strongSelf.isNewConversation {
                        //create convo in database
                        DatabaseManager.shared.createNewConversation(with: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, firstMessage: message, completion: { success in
                            if success {
                                print("Message sent")
                                strongSelf.isNewConversation = false
                                strongSelf.newConversationLabel.isHidden = true
                                let newConversationId = "conversation_\(message.messageId)"
                                strongSelf.conversationId = newConversationId
                                strongSelf.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                            }
                            else {
                                print("Failed to send")
                            }
                        })
                    }
                    else {
                        guard let conversationId = strongSelf.conversationId else {
                            print("Failed to send video message")
                            return
                        }
                        DatabaseManager.shared.getFCMTokens(fcmTokens: [], otherUserKeys: strongSelf.otherUserKeys, completion: { result in
                            switch result {
                            case .success(let fcmTokens):
                                DatabaseManager.shared.sendMessage(to: conversationId, otherUserKeys: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, fcmTokens: fcmTokens, newMessage: message, completion: { success in
                                    
                                    if success {
                                        print("Sent video message")
                                    }
                                    else {
                                        print("Failed to send video message")
                                    }
                                    
                                })
                            case .failure(let error):
                                print("Failed to get FCM Tokens: \(error)")
                            }
                        })
                    }
                case .failure(let error):
                    print("Message video upload error: \(error)")
                }
            })
        }
    }
    
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let selfSender = self.selfSender, let messageId = createMessageId() else {return}
        print("Sending: \(text)")
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        
        //Send Message
        if isNewConversation {
            //create convo in database
            DatabaseManager.shared.createNewConversation(with: otherUserKeys, otherUserNames: otherUserNames, firstMessage: message, completion: { [weak self] success in
                if success {
                    print("Message sent")
                    self?.isNewConversation = false
                    self?.newConversationLabel.isHidden = true
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                }
                else {
                    print("Failed to send")
                }
            })
        }
        else {
            guard let conversationId = conversationId else {
                return
            }
//            functions.httpsCallable("sendNotification").call([]) { result, error in
//                if let error = error as NSError? {
//                    print("failed..........................")
//                    if error.domain == FunctionsErrorDomain {
//                        let code = FunctionsErrorCode(rawValue: error.code)
//                        let message = error.localizedDescription
//                        let details = error.userInfo[FunctionsErrorDetailsKey]
//                    }
//                    // ...
//                }
//                else {
//                    print("Succeeded...........................")
//                }
//            }
//            //append to existing conversation data
            DatabaseManager.shared.getFCMTokens(fcmTokens: [], otherUserKeys: otherUserKeys, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let fcmTokens):
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserKeys: strongSelf.otherUserKeys, otherUserNames: strongSelf.otherUserNames, fcmTokens: fcmTokens, newMessage: message, completion: { [weak self] success in
                        if success {
                            self?.messageInputBar.inputTextView.text = nil
                            print("Message sent")
                        }
                        else {
                            print("Failed to send")
                        }
                    })
                case .failure(let error):
                    print("Failed to get FCM Tokens: \(error)")
                }
            })
        }
    }
    //MARK: Dean priority in message id
    private func createMessageId() -> String? { //user emails, date
        guard let currentUserKey = UserDefaults.standard.value(forKey: "key") as? String else {
            return nil
        }
        var otherKeysString = ""
        for email in otherUserKeys {
            otherKeysString += email + "_"
        }
        let dateString = Utilities.dateFormatter.string(from: Date())
        let newIdentifier = "\(currentUserKey)_\(otherKeysString)\(dateString)"
        print("Created Message ID: \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> MessageKit.SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil, key should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func messageFooterView(for indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageReusableView {
        let messageView = MessageReusableView(frame: CGRect(x: view.width / 2, y: view.height / 2, width: 100, height: 100))
        let messageLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 75, height: 50))
        messageLabel.text = "read"
        messageLabel.textColor = .black
        messageView.addSubview(messageLabel)
        return messageView
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
            print("Photot")
        default:
            break
        }
    }
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId { // Our message that we've sent
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let senderKey = message.sender.senderId
        if userPhotoURLs[senderKey] == nil {
            let pathKey = Utilities.makeSafe(unsafeString: senderKey)
            let path = "profile_pictures/\(pathKey)_profile_picture.png"
            StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                switch result {
                case .success(let url):
                    self?.userPhotoURLs.updateValue(url, forKey: senderKey)
                    DispatchQueue.main.async {
                        avatarView.sd_setImage(with: url, completed: nil)
                    }
                case .failure(let error):
                    print("\(error)")
                }
            })
        }
        else {
            avatarView.sd_setImage(with: userPhotoURLs[senderKey]!)
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default:
            break
        }
    }
}
