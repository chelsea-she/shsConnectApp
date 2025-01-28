//
//  StatusViewController.swift
//  schoolApp1
//
//  Created by Matthias Park 2025 on 7/14/23.
//

import UIKit//TODO: When enter on keyboard pressed, run confirm function

final class StatusViewController: UIViewController {
    private let promptLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter the verification code:"
        label.textAlignment = .center
        label.textColor = .label
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    private let verificationCodeField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Enter Code..."
        field.leftView = UIView(frame:CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    private let confirmButton: UIButton = {
        let button = UIButton()
        button.setTitle("Confirm", for: .normal)
        button.setTitle("Pressed", for: .application)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.red, for: .application)
        button.titleLabel!.font = .systemFont(ofSize: 21, weight: .medium)
        button.layer.cornerRadius = 12
        button.backgroundColor = #colorLiteral(red: 0.227152288, green: 0.5381186008, blue: 0.3243650198, alpha: 1)
        return button
    }()
    
    private let studentButton: UIButton = {
        let button = UIButton()
        button.setTitle("Student", for: .normal)
        button.backgroundColor = #colorLiteral(red: 0.227152288, green: 0.5381186008, blue: 0.3243650198, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.isHidden = true
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private let deanButton: UIButton = {
        let button = UIButton()
        button.setTitle("Dean", for: .normal)
        button.backgroundColor = #colorLiteral(red: 0.227152288, green: 0.5381186008, blue: 0.3243650198, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.isHidden = true
        button.isUserInteractionEnabled = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        confirmButton.addTarget(self, action: #selector(didTapConfirmButton), for: .touchUpInside)
        studentButton.addTarget(self, action: #selector(didTapStudent), for: .touchUpInside)
        deanButton.addTarget(self, action: #selector(didTapDean), for: .touchUpInside)
        view.addSubview(promptLabel)
        view.addSubview(verificationCodeField)
        view.addSubview(confirmButton)
        view.addSubview(studentButton)
        view.addSubview(deanButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        promptLabel.frame = CGRect(x: 30, y: view.height / 4, width: view.width - 60, height: 52)
        verificationCodeField.frame = CGRect(x: 30, y: promptLabel.bottom + 20, width: view.width - 60, height: 52)
        confirmButton.frame = CGRect(x: 30, y: verificationCodeField.bottom + 20, width: view.width - 60, height: 52)
        studentButton.frame = CGRect(x: 30, y: promptLabel.bottom + 20, width: view.width - 60, height: 52)
        deanButton.frame = CGRect(x: 30, y: studentButton.bottom + 20, width: view.width - 60, height: 52)
    }
    
    @objc private func didTapConfirmButton() {
        verificationCodeField.resignFirstResponder()
        DatabaseManager.shared.getDataFor(path: "codes/verification_code", completion: { [weak self] result in
            switch result {
            case .success(let code):
                guard let strongSelf = self,
                      let verificationCode = code as? String else {
                    return
                }
                guard let enteredCode = strongSelf.verificationCodeField.text,
                enteredCode == verificationCode else {
                    let alert = UIAlertController(title: "Oops!", message: "Invalid code entered. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    strongSelf.present(alert, animated: true)
                    return
                }
                strongSelf.promptLabel.text = "Who are you registering as?"
                strongSelf.verificationCodeField.isHidden = true
                strongSelf.verificationCodeField.isUserInteractionEnabled = false
                strongSelf.confirmButton.isHidden = true
                strongSelf.confirmButton.isUserInteractionEnabled = false
                strongSelf.studentButton.isHidden = false
                strongSelf.studentButton.isUserInteractionEnabled = true
                strongSelf.deanButton.isHidden = false
                strongSelf.deanButton.isUserInteractionEnabled = true
            case .failure(let error):
                print(error)
            }
        })
    }
    
    @objc private func didTapStudent() {
        let vc = StudentRegisterViewController()
        vc.title = "Student"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func didTapDean() {
        let vc = DeanRegisterViewController()
        vc.title = "Dean"
        navigationController?.pushViewController(vc, animated: true)
    }
}
