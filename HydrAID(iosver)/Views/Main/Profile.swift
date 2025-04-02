//
//  Profile.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var profileData: ProfileData?
    @State private var editedData: ProfileData?
    @State private var isEditing = false
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
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
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading profile...")
                            .padding()
                    }
                } else if let data = isEditing ? editedData : profileData {
                    if isEditing {
                        editView(data: data)
                    } else {
                        profileDetailView(data: data)
                    }
                } else {
                    Text("Unable to load profile data")
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "My Profile")
            .navigationBarItems(trailing: !isEditing ?
                Button(action: {
                    isEditing = true
                }) {
                    Text("Edit")
                } : nil
            )
            .onAppear {
                fetchProfileData()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func profileDetailView(data: ProfileData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Edit profile button at the top for easier access
                Button(action: {
                    isEditing = true
                }) {
                    Text("Edit Profile")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.bottom, 10)
                
                // Profile info sections
                profileInfoSection(title: "Name", value: data.name)
                profileInfoSection(title: "Gender", value: data.gender.capitalized)
                profileInfoSection(title: "Weight (kg)", value: data.weight)
                profileInfoSection(title: "Age", value: data.age)
                profileInfoSection(title: "Activity Level", value: data.activityLevel)
                
                // Health conditions section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health Conditions")
                        .font(.headline)
                    
                    if data.healthConditions.isEmpty {
                        Text("None specified")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(data.healthConditions, id: \.self) { condition in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(condition)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Medications section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medications")
                        .font(.headline)
                    
                    if data.medications.isEmpty {
                        Text("None specified")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(data.medications, id: \.self) { medication in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(medication)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Sign out button
                Button(action: {
                    authService.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
    
    private func profileInfoSection(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func editView(data: ProfileData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name input
                VStack(alignment: .leading) {
                    Text("Name")
                        .font(.headline)
                    TextField("Name", text: Binding(
                        get: { self.editedData?.name ?? "" },
                        set: { self.editedData?.name = $0 }
                    ))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Gender picker
                VStack(alignment: .leading) {
                    Text("Gender")
                        .font(.headline)
                    Picker("Select Gender", selection: Binding(
                        get: { self.editedData?.gender ?? "" },
                        set: { self.editedData?.gender = $0 }
                    )) {
                        Text("Select Gender").tag("")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Weight input
                VStack(alignment: .leading) {
                    Text("Weight (kg)")
                        .font(.headline)
                    TextField("Weight", text: Binding(
                        get: { self.editedData?.weight ?? "" },
                        set: { self.editedData?.weight = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Age input
                VStack(alignment: .leading) {
                    Text("Age")
                        .font(.headline)
                    TextField("Age", text: Binding(
                        get: { self.editedData?.age ?? "" },
                        set: { self.editedData?.age = $0 }
                    ))
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Activity level picker
                VStack(alignment: .leading) {
                    Text("Activity Level")
                        .font(.headline)
                    Picker("Select Activity Level", selection: Binding(
                        get: { self.editedData?.activityLevel ?? "" },
                        set: { self.editedData?.activityLevel = $0 }
                    )) {
                        Text("Select Activity Level").tag("")
                        ForEach(activityLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
                                        .foregroundColor(editedData?.healthConditions.contains(condition) ?? false ? .white : .primary)
                                    Spacer()
                                }
                                .padding()
                                .background(editedData?.healthConditions.contains(condition) ?? false ? Color.blue : Color(.systemGray6))
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
                                        .foregroundColor(editedData?.medications.contains(medication) ?? false ? .white : .primary)
                                    Spacer()
                                }
                                .padding()
                                .background(editedData?.medications.contains(medication) ?? false ? Color.blue : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Buttons
                HStack {
                    Button(action: {
                        isEditing = false
                        editedData = profileData
                    }) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(8)
                    }
                    
                    Button(action: handleSave) {
                        Text("Save Changes")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
    
    private func fetchProfileData() {
        isLoading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to load profile: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                alertTitle = "Error"
                alertMessage = "Profile data not found"
                showAlert = true
                return
            }
            
            guard let data = snapshot.data() else {
                return
            }
            
            var profile = ProfileData()
            profile.name = data["name"] as? String ?? ""
            profile.gender = data["gender"] as? String ?? ""
            profile.weight = data["weight"] as? String ?? ""
            profile.age = data["age"] as? String ?? ""
            profile.activityLevel = data["activityLevel"] as? String ?? ""
            profile.healthConditions = data["healthConditions"] as? [String] ?? []
            profile.medications = data["medications"] as? [String] ?? []
            
            self.profileData = profile
            self.editedData = profile
        }
    }
    
    private func toggleHealthCondition(_ condition: String) {
        guard var editedData = editedData else { return }
        
        if editedData.healthConditions.contains(condition) {
            editedData.healthConditions.removeAll { $0 == condition }
        } else {
            editedData.healthConditions.append(condition)
        }
        
        self.editedData = editedData
    }
    
    private func toggleMedication(_ medication: String) {
        guard var editedData = editedData else { return }
        
        if editedData.medications.contains(medication) {
            editedData.medications.removeAll { $0 == medication }
        } else {
            editedData.medications.append(medication)
        }
        
        self.editedData = editedData
    }
    
    private func handleSave() {
        guard let editedData = editedData else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            alertTitle = "Error"
            alertMessage = "User not authenticated"
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "name": editedData.name,
            "gender": editedData.gender,
            "weight": editedData.weight,
            "age": editedData.age,
            "activityLevel": editedData.activityLevel,
            "healthConditions": editedData.healthConditions,
            "medications": editedData.medications,
            "updatedAt": Date().ISO8601Format()
        ]
        
        db.collection("users").document(userId).updateData(userData) { error in
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to update profile: \(error.localizedDescription)"
                showAlert = true
            } else {
                self.profileData = editedData
                self.isEditing = false
                alertTitle = "Success"
                alertMessage = "Profile updated successfully"
                showAlert = true
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService())
    }
}
