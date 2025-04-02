//
//  ProfileSetup.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileData {
    var name: String = ""
    var gender: String = ""
    var weight: String = ""
    var age: String = ""
    var activityLevel: String = ""
    var healthConditions: [String] = []
    var medications: [String] = []
}

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var profileData = ProfileData()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var errors: [String: String] = [:]
    let onComplete: () -> Void
    
    let healthConditionOptions = [
        "Heart Conditions",
        "Diabetes",
        "Pre-diabetes",
        "Kidney Disease",
        "Urinary Incontinence",
        "High Blood Pressure",
        "High Cholesterol",
        "Fatty Liver",
        "Obesity"
    ]
    
    let medicationOptions = [
        "Diabetes Medications",
        "Blood Pressure Medications",
        "Cholesterol Medications"
    ]
    
    let activityLevels = [
        "Sedentary",
        "Lightly Active",
        "Moderately Active",
        "Very Active",
        "Extra Active"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Profile Setup")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Name input
                    VStack(alignment: .leading) {
                        TextField("Name", text: $profileData.name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(errors["name"] != nil ? Color.red : Color.clear, lineWidth: 1)
                            )
                        
                        if let error = errors["name"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Gender picker
                    VStack(alignment: .leading) {
                        Text("Gender")
                            .font(.headline)
                        
                        Picker("Select Gender", selection: $profileData.gender) {
                            Text("Select Gender").tag("")
                            Text("Male").tag("male")
                            Text("Female").tag("female")
                            Text("Other").tag("other")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(errors["gender"] != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        
                        if let error = errors["gender"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Weight input
                    VStack(alignment: .leading) {
                        TextField("Weight (kg)", text: $profileData.weight)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(errors["weight"] != nil ? Color.red : Color.clear, lineWidth: 1)
                            )
                        
                        if let error = errors["weight"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Age input
                    VStack(alignment: .leading) {
                        TextField("Age", text: $profileData.age)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(errors["age"] != nil ? Color.red : Color.clear, lineWidth: 1)
                            )
                        
                        if let error = errors["age"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Activity level picker
                    VStack(alignment: .leading) {
                        Text("Activity Level")
                            .font(.headline)
                        
                        Picker("Select Activity Level", selection: $profileData.activityLevel) {
                            Text("Select Activity Level").tag("")
                            ForEach(activityLevels, id: \.self) { level in
                                Text(level).tag(level)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(errors["activityLevel"] != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        
                        if let error = errors["activityLevel"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    // Health conditions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Health Conditions")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(healthConditionOptions, id: \.self) { condition in
                                Button(action: {
                                    toggleHealthCondition(condition)
                                }) {
                                    HStack {
                                        Text(condition)
                                            .font(.subheadline)
                                            .foregroundColor(profileData.healthConditions.contains(condition) ? .white : .primary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(profileData.healthConditions.contains(condition) ? Color.blue : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Medications
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Medications")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(medicationOptions, id: \.self) { medication in
                                Button(action: {
                                    toggleMedication(medication)
                                }) {
                                    HStack {
                                        Text(medication)
                                            .font(.subheadline)
                                            .foregroundColor(profileData.medications.contains(medication) ? .white : .primary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(profileData.medications.contains(medication) ? Color.blue : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Save button
                    Button(action: handleSubmit) {
                        Text("Save Profile")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitle("Profile Setup", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func toggleHealthCondition(_ condition: String) {
        if profileData.healthConditions.contains(condition) {
            profileData.healthConditions.removeAll { $0 == condition }
        } else {
            profileData.healthConditions.append(condition)
        }
    }
    
    private func toggleMedication(_ medication: String) {
        if profileData.medications.contains(medication) {
            profileData.medications.removeAll { $0 == medication }
        } else {
            profileData.medications.append(medication)
        }
    }
    
    private func validateForm() -> Bool {
        var newErrors: [String: String] = [:]
        
        if profileData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newErrors["name"] = "Name is required"
        }
        
        if profileData.gender.isEmpty {
            newErrors["gender"] = "Gender is required"
        }
        
        if profileData.weight.isEmpty {
            newErrors["weight"] = "Weight is required"
        }
        
        if profileData.age.isEmpty {
            newErrors["age"] = "Age is required"
        }
        
        if profileData.activityLevel.isEmpty {
            newErrors["activityLevel"] = "Activity level is required"
        }
        
        errors = newErrors
        return newErrors.isEmpty
    }
    
    private func handleSubmit() {
        if !validateForm() {
            alertTitle = "Error"
            alertMessage = "Please fill in all required fields"
            showAlert = true
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            alertTitle = "Error"
            alertMessage = "User not authenticated"
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "name": profileData.name,
            "gender": profileData.gender,
            "weight": profileData.weight,
            "age": profileData.age,
            "activityLevel": profileData.activityLevel,
            "healthConditions": profileData.healthConditions,
            "medications": profileData.medications,
            "setupCompleted": true,
            "createdAt": Date().ISO8601Format(),
            "updatedAt": Date().ISO8601Format()
        ]
        
        db.collection("users").document(userId).setData(userData) { error in
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to save profile data: \(error.localizedDescription)"
                showAlert = true
            } else {
                // Profile setup completed successfully
                alertTitle = "Success"
                alertMessage = "Profile setup completed successfully!"
                showAlert = true
                
                // Navigate to main app
                onComplete()
            }
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(onComplete: {})
            .environmentObject(AuthenticationService())
    }
}
