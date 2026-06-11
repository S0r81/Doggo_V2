//
//  DoggoWidgetBundle.swift
//  DoggoWidget
//
//  Created by Sorest on 6/10/26.
//

import WidgetKit
import SwiftUI

@main
struct DoggoWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoggoWidgetControl()
        // The rest-timer countdown (DoggoActivityAttributes — what the app's
        // RestTimerManager actually starts).
        RestTimerLiveActivity()
    }
}
