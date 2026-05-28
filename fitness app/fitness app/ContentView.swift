//
//  ContentView.swift
//  fitness app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                mainTabs
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isAuthenticated)
    }

    private var mainTabs: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "flame.fill") }

            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }

            AIChatView()
                .tabItem { Label("AI Coach", systemImage: "brain.head.profile") }

            FormFeedbackView()
                .tabItem { Label("Form Coach", systemImage: "camera.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .accentColor(.orange)
    }
}
