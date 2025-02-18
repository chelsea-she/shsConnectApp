//
//  NewConversationTableViewCell.swift
//  schoolApp1
//
//  Created by Matthias Park 2025 on 6/16/23.
//

import Foundation
import SDWebImage

class NewConversationTableViewCell: UITableViewCell {
    
    static let identifier = "NewConversationTableViewCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        userNameLabel.frame = CGRect(x: userImageView.frame.width + 20, y: 20, width: contentView.width - 20 - userImageView.width, height: 50)
    }
    
    public func configure(with model: SearchResult) {
        if !model.displayName.isEmpty {
            userNameLabel.text = model.displayName
        }
        else {
            userNameLabel.text = model.name
        }
        
        let pathKey = Utilities.makeSafe(unsafeString: model.key)
        let path = "profile_pictures/\(pathKey)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }
            case .failure(let error):
                print("Failed to get image url: \(error)")
            }
        })
    }
}
