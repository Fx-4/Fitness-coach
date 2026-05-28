"""
FitCoach iOS — CrewAI Multi-Agent System
=========================================
Arsitektur: 4 sub-agent yang saling berkomunikasi untuk membangun
komponen iOS fitness app secara paralel lalu melakukan integrasi.

Install: pip3 install "crewai[tools]"
Run:     python3 crewai_fitcoach.py
"""

import os
from crewai import Agent, Task, Crew, Process, LLM

# ─────────────────────────────────────────
# LLM — OpenRouter (Mistral via OpenRouter)
# ─────────────────────────────────────────

OPENROUTER_API_KEY = os.environ.get(
    "OPENROUTER_API_KEY",
    "YOUR_OPENROUTER_API_KEY_HERE"
)

llm = LLM(
    model="openrouter/mistralai/mistral-7b-instruct",
    base_url="https://openrouter.ai/api/v1",
    api_key=OPENROUTER_API_KEY,
    temperature=0.3,
)

# ─────────────────────────────────────────
# SHARED STANDARDS (seperti AGENTS.md kita)
# ─────────────────────────────────────────
SHARED_STANDARDS = """
iOS Standards yang harus diikuti SEMUA agent:
- Target iOS 16.4+, Swift 5.9, Xcode 14.3.1
- Gunakan ObservableObject + @Published (bukan @Observable — itu iOS 17+)
- Gunakan RoundedRectangle(cornerRadius: X, style: .continuous) bukan .rect shorthand
- foregroundStyle() bukan foregroundColor()
- navigationBarTrailing / navigationBarLeading bukan topBarTrailing
- Tidak ada import SwiftData — gunakan UserDefaults + Codable
- Semua ViewModel harus @MainActor
- Persistence via AppDataStore (ObservableObject singleton) yang disimpan ke UserDefaults
- Unit tests menggunakan XCTestCase (bukan Swift Testing yang butuh Xcode 16)
- TabView pakai .tabItem { Label() } bukan Tab struct (itu iOS 18+)
- .spring(response:) bukan .spring(duration:) — itu iOS 17+
"""

# ─────────────────────────────────────────
# AGENT DEFINITIONS
# ─────────────────────────────────────────

frontend_agent = Agent(
    role="iOS Frontend Engineer",
    goal="Membuat SwiftUI views yang indah, accessible, dan mengikuti iOS 16.4 design guidelines",
    backstory="""Kamu adalah iOS engineer senior spesialis SwiftUI untuk iOS 16.4.
    Kamu memahami HIG (Human Interface Guidelines), accessibility,
    dan cara membuat UI yang responsif dan smooth.
    Kamu selalu berkomunikasi dengan Backend Agent untuk memastikan
    ViewModel yang dipakai sesuai dengan data yang tersedia.
    PENTING: Kamu TIDAK menggunakan API iOS 17+ seperti @Observable, SwiftData, Tab struct.""",
    verbose=True,
    allow_delegation=True,
    llm=llm,
)

backend_agent = Agent(
    role="iOS Backend & Data Engineer",
    goal="Membuat service layer, data models, dan business logic yang solid dan testable untuk iOS 16.4",
    backstory="""Kamu adalah engineer yang spesialis di data layer iOS.
    Kamu merancang protocol-based services, persistence layer menggunakan UserDefaults+Codable,
    dan memastikan semua data flow aman secara concurrency dengan async/await.
    Kamu menyediakan interface yang bersih untuk Frontend Agent pakai.
    PENTING: Tidak ada SwiftData, tidak ada @Model, gunakan plain Codable structs.""",
    verbose=True,
    allow_delegation=True,
    llm=llm,
)

healthkit_agent = Agent(
    role="HealthKit & Sensor Integration Specialist",
    goal="Mengintegrasikan Apple HealthKit, Vision framework, dan kamera dengan aman dan sesuai privasi",
    backstory="""Kamu adalah specialist Apple platform APIs.
    Kamu memastikan semua akses HealthKit mengikuti privacy guidelines,
    semua permission diminta dengan benar, dan sensor data (kamera, pose detection)
    diproses securely. Kamu bekerja sama dengan Backend Agent untuk
    menyediakan data HealthKit ke ViewModel.
    Kamu juga menyediakan MockHealthKitService agar unit tests bisa berjalan tanpa device.""",
    verbose=True,
    allow_delegation=True,
    llm=llm,
)

qa_agent = Agent(
    role="QA Engineer & Code Reviewer",
    goal="Memastikan semua kode dari agent lain bebas bug, tertest, dan siap App Store di iOS 16.4",
    backstory="""Kamu adalah QA engineer yang teliti. Kamu me-review kode dari
    Frontend, Backend, dan HealthKit agent. Kamu menulis XCTestCase unit tests,
    mengecek edge cases, memastikan tidak ada force unwrap berbahaya,
    memverifikasi tidak ada import SwiftData atau API iOS 17+,
    dan memberikan laporan integrasi akhir kepada semua agent.""",
    verbose=True,
    allow_delegation=True,
    llm=llm,
)

# ─────────────────────────────────────────
# TASK DEFINITIONS
# ─────────────────────────────────────────

task_backend = Task(
    description=f"""
    Rancang dan implementasi data layer untuk FitCoach iOS app.

    Standards: {SHARED_STANDARDS}

    Yang sudah ada dan harus konsisten:
    - UserProfile struct (Codable) — nama, usia, berat, tinggi, target kalori, fitness level
    - WorkoutSession struct (Codable, Identifiable) — tipe, durasi, kalori, status
    - AppDataStore class (ObservableObject) — simpan ke UserDefaults JSON
    - WorkoutRecommender — engine rekomendasi berdasarkan fitness level
    - HealthKitServiceProtocol untuk dependency injection

    Yang harus diverifikasi dan dilengkapi:
    1. AppDataStore sudah punya computed property: recentSessions, todaySessionCalories
    2. WorkoutRecommender.recommendations(for:) return [WorkoutRecommendation]
    3. DailyCalorieSample struct untuk weekly chart data
    4. Semua model Equatable dan Hashable dimana diperlukan

    Output: Ringkasan interface publik (property + method names) yang Frontend Agent bisa gunakan.
    """,
    agent=backend_agent,
    expected_output="Daftar lengkap public API: class names, property names, method signatures"
)

task_healthkit = Task(
    description=f"""
    Implementasi HealthKit dan Vision integration untuk FitCoach iOS 16.4.

    Standards: {SHARED_STANDARDS}

    Yang sudah ada:
    1. HealthKitService (@MainActor class) — fetch active energy, step count, weekly data
    2. MockHealthKitService — untuk testing tanpa device
    3. FormAnalysisService (actor) — Vision pose detection
    4. Info.plist sudah punya NSHealthShareUsageDescription, NSCameraUsageDescription

    Yang harus diverifikasi:
    1. HealthKitService.fetchTodayActiveEnergy() -> Double (async throws)
    2. HealthKitService.fetchTodayStepCount() -> Int (async throws)
    3. HealthKitService.fetchWeeklyCalories() -> [DailyCalorieSample] (async throws)
    4. MockHealthKitService implements HealthKitServiceProtocol dengan:
       - var isAvailable: Bool
       - var activeEnergyToday: Double
       - var stepCountToday: Int
       - var shouldThrow: Bool

    Lesson goals yang sudah terimplementasi:
    - Lesson Goal 3: read today's active energy burned ✓
    - Lesson Goal 5: request Apple Health permission ✓
    - Mock data untuk simulator (312 kcal, 6480 steps) ✓

    Koordinasi dengan Backend Agent: gunakan HealthKitServiceProtocol yang sudah dibuat.
    Output: Konfirmasi API HealthKitService yang siap dipakai DashboardViewModel.
    """,
    agent=healthkit_agent,
    expected_output="Panduan integrasi: cara call HealthKitService dan MockHealthKitService dari ViewModel",
    context=[task_backend]
)

task_frontend = Task(
    description=f"""
    Review dan verifikasi semua SwiftUI views untuk FitCoach iOS 16.4 app.

    Standards: {SHARED_STANDARDS}

    Yang sudah dibuat dan harus diverifikasi:
    1. ContentView — Tab navigation dengan 4 tab menggunakan .tabItem (bukan Tab struct)
    2. DashboardView — Calorie ring, permission banner, weekly chart
       - Lesson Goal 1: Dashboard screen tampil ✓
       - Lesson Goal 2: CalorieGoalSheet dengan Slider 100-1500 kcal + 4 presets ✓
       - Lesson Goal 3: Empty data state dengan figure.walk.motion ✓
       - Lesson Goal 4: StatusBanner dengan 4 states (unavailable/notDetermined/denied/authorized) ✓
    3. WorkoutsView — Daftar rekomendasi workout, history sessions
    4. FormFeedbackView — Camera live feed + pose feedback overlay
    5. ProfileView — Edit profil, kalori goal, fitness level

    Yang harus dikonfirmasi:
    - Semua view pakai @EnvironmentObject store: AppDataStore
    - DashboardView pakai @StateObject private var viewModel = DashboardViewModel()
    - FormFeedbackView pakai @StateObject (bukan @State) untuk CameraViewModel
    - Tidak ada foregroundColor(), tidak ada .rect, tidak ada topBarTrailing
    - .accentColor(.orange) di TabView level

    Output: Checklist views yang sudah dibuat beserta state management yang digunakan.
    """,
    agent=frontend_agent,
    expected_output="Checklist views yang sudah dibuat beserta konfirmasi state management yang benar",
    context=[task_backend, task_healthkit]
)

task_qa = Task(
    description=f"""
    Review semua output dari Frontend, Backend, dan HealthKit agent.
    Tulis laporan QA final dan unit tests yang diperlukan.

    Standards: {SHARED_STANDARDS}

    Yang harus dicek:
    1. Semua kode compile untuk iOS 16.4 (tidak ada API iOS 17+)
    2. Tidak ada import SwiftData atau @Observable
    3. Semua ViewModel @MainActor + ObservableObject
    4. HealthKit privacy strings ada di Info.plist
    5. Unit tests menggunakan XCTestCase (bukan Swift Testing)

    Tests yang sudah ada di fitness_appTests.swift:
    - DashboardViewModelTests: testProgressZeroWhenNoBurn, testProgressClampedAtGoal,
      testProgressFractional, testUnavailableHealthKit, testHealthKitErrorSurfacesMessage,
      testUpdateGoalFromProfile
    - WorkoutRecommenderTests: 6 test cases
    - WorkoutViewModelTests: testElapsedFormatsAsMMSS
    - ProfileViewModelTests: testBMICalculatesCorrectly, testLoadCopiesAllFields

    Tests yang perlu ditambahkan:
    1. Test DashboardViewModel.healthStatus == .unavailable saat MockHealthKitService.isAvailable = false
    2. Test loadMockData() mengisi weeklyCalories dengan 7 item
    3. Test requestPermission() tidak crash saat unavailable

    Edge cases yang harus diverifikasi:
    - HealthKit unavailable (simulator) → loadMockData() dipanggil
    - camera permission denied → FormFeedbackView tampil banner
    - weeklyCalories empty → WeeklyBarChart tidak tampil

    Output: Laporan QA lengkap + daftar tests yang pass/fail + rekomendasi perbaikan.
    """,
    agent=qa_agent,
    expected_output="Laporan QA final: status per komponen, tests pass/fail, rekomendasi perbaikan",
    context=[task_backend, task_healthkit, task_frontend]
)

# ─────────────────────────────────────────
# CREW — Agents bekerja berurutan + saling review
# ─────────────────────────────────────────

fitcoach_crew = Crew(
    agents=[backend_agent, healthkit_agent, frontend_agent, qa_agent],
    tasks=[task_backend, task_healthkit, task_frontend, task_qa],
    process=Process.sequential,   # Backend → HealthKit → Frontend → QA
    verbose=True
)

# ─────────────────────────────────────────
# RUN
# ─────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("FitCoach iOS — CrewAI Multi-Agent Build System")
    print("=" * 60)
    print("LLM: OpenRouter → Mistral-7B-Instruct")
    print()
    print("Agent yang aktif:")
    print("  1. Backend Agent     — Models, Services, Business Logic")
    print("  2. HealthKit Agent   — Apple APIs, Privacy, Sensors")
    print("  3. Frontend Agent    — SwiftUI Views, Navigation, UI")
    print("  4. QA Agent          — Review, Tests, Integration Report")
    print("=" * 60)
    print()

    result = fitcoach_crew.kickoff()

    print("\n" + "=" * 60)
    print("HASIL AKHIR CREW:")
    print("=" * 60)
    print(result)
