//
//  Date+Extensions.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation

extension Date {
    /// Returns a string like "Mon, Jan 5"
    var formattedDate: String {
        self.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Returns a string like "1:30 PM"
    var formattedTime: String {
        self.formatted(date: .omitted, time: .shortened)
    }
}

