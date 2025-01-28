//
//  Utilities.swift
//  shsConnect
//
//  Created by Matthias Park 2025 on 6/30/24.
//

import Foundation

final class Utilities {
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    static func makeSafe(unsafeString: String) -> String {
        let safeString = unsafeString.replacingOccurrences(of: ".", with: "-")
        return safeString
    }
    
    static func formatNames(names: [String]) -> String {
        var namesString = ""
        if names.isEmpty {
            return ""
        }
        else if names.count > 2 {
            namesString = "\(names[0]), \(names[1]) + \(names.count - 2) more"
        }
        else {
            for index in 0...names.count - 1 {
                namesString += "\(names[index])"
                if index != names.count - 1 {
                    namesString += ", "
                }
            }
        }
        return namesString
    }
    
    static func formatGrade(grade: Int) -> String {
        if grade == 9 {
            return "Freshman"
        }
        else if grade == 10 {
            return "Sophomore"
        }
        else if grade == 11 {
            return "Junior"
        }
        else if grade == 12 {
            return "Senior"
        }
        return "Unknown"
    }
}
