//
//  ViewController.swift
//  schoolApp1
//
//  Created by Yash Jagtap on 5/14/23.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {
    //MARK: NO student deletion
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        table.isHidden = true
        return table
        
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {return}
            
            let currentConversations = strongSelf.conversations
            
            var otherKeys: [String] = []
            for searchResult in result {
                otherKeys.append(searchResult.key)
            }
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserKeys.difference(from: otherKeys).isEmpty
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserKeys, names: targetConversation.otherUserNames, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.conversationName
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
            else {
                strongSelf.createNewConversation(results: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    private func createNewConversation(results: [SearchResult]) {
        var names: [String] = []
        var keys: [String] = []
        
        for searchResult in results {
            if searchResult.displayName.isEmpty {
                names.append(searchResult.name)
            }
            else {
                names.append(searchResult.displayName)
            }
            keys.append(searchResult.key)
        }
        
        let namesString = Utilities.formatNames(names: names)
        
        // Check in database if conversation with these users exists
        // If it does, reuse conversation id
        // Otherwise use existing code
        
        DatabaseManager.shared.conversationExists(with: keys, completion: { [weak self] result in
            guard let strongSelf = self else {return}
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: keys, names: names, id: conversationId)
                vc.isNewConversation = false
                vc.title = namesString
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: keys, names: names, id: nil)
                vc.isNewConversation = true
                vc.title = namesString
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
            
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setUpTableView()
        if UserDefaults.standard.value(forKey: "is_dean") as? Bool ?? false {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        }
        else {
            navigationItem.rightBarButtonItem = nil
        }
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if UserDefaults.standard.value(forKey: "is_dean") as? Bool ?? false {
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(strongSelf.didTapComposeButton))
            }
            else {
                strongSelf.navigationItem.rightBarButtonItem = nil
            }
            strongSelf.startListeningForConversations()
        })
    }
    
    private func startListeningForConversations() {
        guard let key = UserDefaults.standard.value(forKey: "key") as? String else {return}
        print("Starting conversation fetch...")
        DatabaseManager.shared.getAllConversations(for: key, completion: { [weak self] result in
            switch result {
            case .success(let conversations):
                print("Successfully got conversation models")
                guard !conversations.isEmpty else {
                    self?.tableView.isHidden = true
                    self?.noConversationsLabel.isHidden = false
                    return
                }
                self?.tableView.isHidden = false
                self?.noConversationsLabel.isHidden = true
                self?.conversations = conversations
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationsLabel.isHidden = false
                print("Failed to get conversations: \(error)")
            }
        })
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    private func validateAuth() {
        if let currentUser = FirebaseAuth.Auth.auth().currentUser, let userKey = UserDefaults.standard.value(forKey: "key") as? String {
            DatabaseManager.shared.getDataFor(path: "profiles/\(userKey)", completion: { [weak self] result in
                switch result {
                case .success(let data):
                    guard let strongSelf = self, let profileData = data as? [String: Any], let emailFromKey = profileData["email"] as? String else {
                        self?.returnToLogin(logOut: true)
                        return
                    }
                    let emailFromAuth = currentUser.email
                    if emailFromKey != emailFromAuth {
                        strongSelf.returnToLogin(logOut: true)
                    }
                    else {
                        DatabaseManager.shared.provideSession(for: userKey, completion: {
                            strongSelf.startListeningForConversations()
                        })
                    }
                case .failure(let error):
                    self?.returnToLogin(logOut: false)
                }
            })
        }
        else {
            returnToLogin(logOut: false)
        }
    }
    
    private func returnToLogin(logOut: Bool) {
        UserDefaults.standard.set(nil, forKey: "key")
        do {
            try FirebaseAuth.Auth.auth().signOut()
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
        catch {
            fatalError("Failed to log out user. Please rerun the app and try again.")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(x: 10, y: (view.height - 100) / 2, width: view.width - 20, height: 100)
    }
    
    
    private func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return conversations.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.otherUserKeys, names: model.otherUserNames, id: model.id)
        vc.title =  model.conversationName
        vc.navigationItem.largeTitleDisplayMode = .never
        DatabaseManager.shared.updateLatestMessageIsRead(for: model.id, completion: { success in
            guard success else {
                print("Failed to update latest message's \"is read\" value")
                return
            }
        })
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let isDean = UserDefaults.standard.value(forKey: "is_dean") as? Bool else {
            return .none
        }
        return isDean ? .delete : .none
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // begin deletion
            let alert = UIAlertController(title: "Delete this conversation?", message: "This action cannot be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { [weak self] _ in
                guard let strongSelf = self else {
                    let alert = UIAlertController(title: "Error", message: "Failed to Delete Conversation", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }
                let conversationId = strongSelf.conversations[indexPath.row].id
                
                DatabaseManager.shared.deleteConversation(conversationId: conversationId, completion: { [weak self] success in
                    guard let strongSelf = self else {return}
                    guard success else {
                        //show error alert
                        let alert = UIAlertController(title: "Error", message: "Failed to Delete Conversation", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        strongSelf.present(alert, animated: true)
                        return
                    }
                })
            }))
            present(alert, animated: true)
        }
    }
}
