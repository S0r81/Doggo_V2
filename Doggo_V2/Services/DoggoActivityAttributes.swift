//
//  DoggoActivityAttributes.swift
//  Doggo_V2
//
//  Created by Sorest on 2/5/26.
//


import ActivityKit
import Foundation

struct DoggoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
    }
}