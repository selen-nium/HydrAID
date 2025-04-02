//
//  Statistics.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct StatData {
    let date: Date
    let hydrationAmount: Int
    let sugarAmount: Int
}

struct StatisticsView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var statData: [StatData] = []
    @State private var dataType: DataType = .hydration
    
    // Constants for goal thresholds
    let HYDRATION_GOAL = 2000 // ml
    let SUGAR_GOAL_MAX = 25 // g
    let SUGAR_WARNING_THRESHOLD = 35 // g
    
    enum DataType {
        case hydration, sugar
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle between Hydration and Sugar data
                    HStack {
                        Button(action: { dataType = .hydration }) {
                            Text("Hydration")
                                .fontWeight(.medium)
                                .foregroundColor(dataType == .hydration ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(dataType == .hydration ? Color.blue : Color.clear)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { dataType = .sugar }) {
                            Text("Sugar")
                                .fontWeight(.medium)
                                .foregroundColor(dataType == .sugar ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(dataType == .sugar ? Color.blue : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Month navigation
                    HStack {
                        Button(action: goToPreviousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .padding(8)
                        }
                        
                        Spacer()
                        
                        Text(getMonthYearString(from: currentMonth))
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: goToNextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Calendar grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                        ForEach(getDaysInMonth(), id: \.self) { day in
                            let dayData = getDataForDay(day: day)
                            let dataValue = dataType == .hydration ?
                                dayData?.hydrationAmount :
                                dayData?.sugarAmount
                            let bgColor = getStatusColor(value: dataValue)
                            
                            Button(action: {
                                selectedDate = day
                            }) {
                                Text("\(getDay(from: day))")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .background(bgColor)
                                    .foregroundColor(getTextColor(for: bgColor))
                                    .cornerRadius(20)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelectedDay(day) ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Selected day details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(getDateString(from: selectedDate))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Hydration card
                        let selectedDayData = getDataForDay(day: selectedDate)
                        DayStatCard(
                            title: "Hydration",
                            value: selectedDayData?.hydrationAmount,
                            unit: "ml",
                            goal: HYDRATION_GOAL,
                            goalType: .minimum,
                            warningThreshold: Int(Double(HYDRATION_GOAL) * 0.7)
                        )
                        .padding(.horizontal)
                        
                        // Sugar card
                        DayStatCard(
                            title: "Sugar",
                            value: selectedDayData?.sugarAmount,
                            unit: "g",
                            goal: SUGAR_GOAL_MAX,
                            goalType: .maximum,
                            warningThreshold: SUGAR_WARNING_THRESHOLD
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
            .navigationTitle("Past Stats")
            .onAppear {
                loadStatData()
            }
        }
    }
    
    // MARK: - Helper functions
    
    private func loadStatData() {
        // Mock data - this would be replaced with Firebase Firestore data in a real app
        let mockData: [StatData] = [
            StatData(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, hydrationAmount: 2400, sugarAmount: 12),
            StatData(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, hydrationAmount: 1800, sugarAmount: 24),
            StatData(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, hydrationAmount: 3200, sugarAmount: 8),
            StatData(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, hydrationAmount: 2800, sugarAmount: 15),
            StatData(date: Calendar.current.date(byAdding: .day, value: -9, to: Date())!, hydrationAmount: 3000, sugarAmount: 18),
            StatData(date: Calendar.current.date(byAdding: .day, value: -11, to: Date())!, hydrationAmount: 1200, sugarAmount: 35),
        ]
        
        statData = mockData
    }
    
    private func getDaysInMonth() -> [Date] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        
        let year = Calendar.current.component(.year, from: currentMonth)
        let month = Calendar.current.component(.month, from: currentMonth)
        
        return range.compactMap { day -> Date? in
            let components = DateComponents(year: year, month: month, day: day)
            return Calendar.current.date(from: components)
        }
    }
    
    private func getDataForDay(day: Date) -> StatData? {
        return statData.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }
    
    private func getDay(from date: Date) -> Int {
        return Calendar.current.component(.day, from: date)
    }
    
    private func getMonthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func getDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func goToPreviousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func goToNextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func isSelectedDay(_ day: Date) -> Bool {
        return Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }
    
    private func getStatusColor(value: Int?) -> Color {
        guard let value = value else {
            return Color(.systemGray5)
        }
        
        if dataType == .hydration {
            if value >= HYDRATION_GOAL {
                return Color.green.opacity(0.5)
            } else if value >= Int(Double(HYDRATION_GOAL) * 0.7) {
                return Color.orange.opacity(0.5)
            } else {
                return Color.red.opacity(0.5)
            }
        } else { // Sugar
            if value <= SUGAR_GOAL_MAX {
                return Color.green.opacity(0.5)
            } else if value <= SUGAR_WARNING_THRESHOLD {
                return Color.orange.opacity(0.5)
            } else {
                return Color.red.opacity(0.5)
            }
        }
    }
    
    private func getTextColor(for backgroundColor: Color) -> Color {
        // For simplicity, always use black text
        return .black
    }
}

struct DayStatCard: View {
    let title: String
    let value: Int?
    let unit: String
    let goal: Int
    let goalType: GoalType
    let warningThreshold: Int
    
    enum GoalType {
        case minimum, maximum
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let value = value {
                Text("\(value) \(unit)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(getAchievementText(value: value))
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(getAchievementColor(value: value))
            } else {
                Text("No data")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text(goalType == .minimum ? "Aim for \(goal)\(unit) daily" : "Aim for under \(goal)\(unit) daily")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func getAchievementText(value: Int) -> String {
        if goalType == .minimum {
            if value >= goal {
                return "Daily goal achieved! 🎉"
            } else if value >= warningThreshold {
                return "Almost there! Keep drinking"
            } else {
                return "Below daily target"
            }
        } else { // maximum
            if value <= goal {
                return "Within healthy range! 👍"
            } else if value <= warningThreshold {
                return "Slightly over recommended limit"
            } else {
                return "High sugar intake detected"
            }
        }
    }
    
    private func getAchievementColor(value: Int) -> Color {
        if goalType == .minimum {
            if value >= goal {
                return .green
            } else if value >= warningThreshold {
                return .orange
            } else {
                return .red
            }
        } else { // maximum
            if value <= goal {
                return .green
            } else if value <= warningThreshold {
                return .orange
            } else {
                return .red
            }
        }
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
    }
}
