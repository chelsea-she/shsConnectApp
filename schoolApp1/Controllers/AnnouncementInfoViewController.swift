//
//  AnnouncementInfoViewController.swift
//  shsConnect
//
//  Created by Matthias Park 2025 on 7/27/24.
//

import UIKit

class AnnouncementInfoViewController: UIViewController {
    
    private var announcement: Announcement
    
    private var isPinned: Bool = false

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        label.numberOfLines = 0
        label.backgroundColor = .clear
        return label
    }()
    private let pinnedButton: UIButton = {
        let button = UIButton()
        button.tintColor = .link
        return button
    }()
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .regular)
        label.numberOfLines = 0
        label.backgroundColor = .clear
        return label
    }()
    private let bodyLabel: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 19, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .clear
        return textView
    }()
    
    private let linksStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .equalCentering
        stackView.axis = .vertical
        stackView.backgroundColor = .clear
        return stackView
    }()
    
    init(announcement: Announcement) {
        self.announcement = announcement
        self.isPinned = announcement.pinned
        super.init(nibName: nil, bundle: nil)
        guard let isDean = UserDefaults.standard.value(forKey: "is_dean") as? Bool else {return}
        if !isDean {
            pinnedButton.isUserInteractionEnabled = false
        }
        
        if isPinned {
            pinnedButton.setImage(UIImage(systemName: "pin.fill"), for: .normal)
            pinnedButton.isHidden = false
        }
        else {
            pinnedButton.setImage(UIImage(systemName: "pin.slash"), for: .normal)
            if !isDean {
                pinnedButton.isHidden = true
            }
        }
        titleLabel.text = announcement.title
        infoLabel.text = "Sent by \(announcement.senderName) at \(announcement.sentDate)"
        bodyLabel.text = announcement.body
        if let announcementLinks = announcement.links {
            linksStackView.frame = CGRect(x: view.width / 32, y: view.height * 4 / 5 + 20, width: view.width * 15 / 16, height: CGFloat(announcementLinks.count * 25))
            for announcementLink in announcementLinks {
                let linkButton = createLinkButton(for: announcementLink)
                linksStackView.addArrangedSubview(linkButton)
                linkButton.addTarget(self, action: #selector(linkButtonTapped), for: .touchUpInside)
            }
        }
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func changePinned() {
        guard let isDean = UserDefaults.standard.value(forKey: "is_dean") as? Bool, isDean else {return}
        
        DatabaseManager.shared.changeAnnouncementPinned(to: !isPinned, announcementId: announcement.announcementId, grade: announcement.grade, completion: { [weak self] success in
            guard success else {
                print("Failed to change announcement pinned status")
                return
            }
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPinned = !strongSelf.isPinned
            if strongSelf.isPinned {
                strongSelf.pinnedButton.setImage(UIImage(systemName: "pin.fill"), for: .normal)
                strongSelf.pinnedButton.isHidden = false
            }
            else {
                strongSelf.pinnedButton.setImage(UIImage(systemName: "pin.slash"), for: .normal)
            }
        })
    }
    
    @objc private func linkButtonTapped(sender: UIButton) {
        guard let urlString = sender.titleLabel?.text, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            print("Invalid link pressed")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(titleLabel)
        view.addSubview(pinnedButton)
        view.addSubview(infoLabel)
        view.addSubview(bodyLabel)
        view.addSubview(linksStackView)
        view.backgroundColor = .systemBackground
        
        pinnedButton.addTarget(self, action: #selector(changePinned), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        titleLabel.frame = CGRect(x: view.width / 32, y: view.top + 100, width: view.width * 15 / 16, height: 25)
        pinnedButton.frame = CGRect(x: view.width - 40, y: view.top + 100, width: 20, height: 20)
        infoLabel.frame = CGRect(x: view.width / 32, y: titleLabel.bottom + 20, width: view.width * 15 / 16, height: 25)
        bodyLabel.frame = CGRect(x: view.width / 16, y: infoLabel.bottom + 20, width: view.width * 7 / 8, height: view.height * 3 / 4 - titleLabel.bottom - 40)
    }
    
    private func createLinkButton(for announcementLink: String) -> UIButton {
        let button = UIButton()
        button.contentHorizontalAlignment = .left
        button.setTitleColor(.link, for: .normal)
        button.setTitleColor(.clear, for: .application)
        button.titleLabel!.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitle(announcementLink, for: .normal)
        button.backgroundColor = .clear
        
        return button
    }
}
