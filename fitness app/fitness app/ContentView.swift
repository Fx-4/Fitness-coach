//
//  ContentView.swift
//  fitness app
//
//  Created by 26 on 2026/5/8.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "flame.fill")
                }

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell.fill")
                }

            AIChatView()
                .tabItem {
                    Label("AI Coach", systemImage: "brain.head.profile")
                }

            FormFeedbackView()
                .tabItem {
                    Label("Form Coach", systemImage: "camera.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.orange)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
