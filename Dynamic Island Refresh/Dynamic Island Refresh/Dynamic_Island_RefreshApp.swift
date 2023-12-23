//
//  Dynamic_Island_RefreshApp.swift
//  Dynamic Island Refresh
//
//  Created by Kimlong Hor on 12/22/23.
//

import SwiftUI

@main
struct Dynamic_Island_RefreshApp: App {
    var body: some Scene {
        WindowGroup {
            DynamicIslandRefreshView(showIndicator: false) {
                // ...
            } onRefresh: {}
        }
    }
}
