//
//  AppConstants.swift
//  Doggo_V2
//

import Foundation

/// 4-pt spacing scale. Rules of thumb:
/// - Cards pad `.lg`
/// - Title → content gap is `.md`
/// - Metadata sits `.xs` below its parent line
/// - Sections are separated by `.xl`
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}
