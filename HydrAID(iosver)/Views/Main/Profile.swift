import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
                            .scaleEffect(2.0)
                        Text("Loading profile...")
                            .font(.system(size: 20))
                            .padding(.top, 24)
                    }
                } else if let data = isEditing ? editedData : profileData {
                    if isEditing {
                        editView(data: data)
                    } else {
                        profileDetailView(data: data)
                    }
                } else {
                    Text("Unable to load profile data")
                        .font(.system(size: 20))
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "My Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: !isEditing ?
                Button(action: {
                    isEditing = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                } : nil
            )
            .onAppear {
                fetchProfileData()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle).font(.system(size: 20, weight: .bold)),
                    message: Text(alertMessage).font(.system(size: 18)),
                    dismissButton: .default(Text("OK").font(.system(size: 18, weight: .medium)))
                )
            }
        }
    }
    
    private func profileDetailView(data: ProfileData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Edit profile button at the top for easier access
                Button(action: {
                    isEditing = true
                }) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 20))
                        Text("Edit Profile")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.bottom, 10)
                
                // Profile info sections with larger text and better contrast
                profileInfoSection(icon: "person.fill", title: "Name", value: data.name)
                profileInfoSection(icon: "person.fill.questionmark", title: "Gender", value: data.gender.capitalized)
                profileInfoSection(icon: "scalemass.fill", title: "Weight", value: "\(data.weight) kg")
                profileInfoSection(icon: "calendar", title: "Age", value: "\(data.age) years")
                profileInfoSection(icon: "figure.walk", title: "Activity Level", value: data.activityLevel)
                
                // Health conditions section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        Text("Health Conditions")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    if data.healthConditions.isEmpty {
                        Text("None specified")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    } else {
                        ForEach(data.healthConditions, id: \.self) { condition in
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                Text(condition)
                                    .font(.system(size: 18))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
                .background(Color.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                
                // Medications section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        Text("Medications")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    if data.medications.isEmpty {
                        Text("None specified")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    } else {
                        ForEach(data.medications, id: \.self) { medication in
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text(medication)
                                    .font(.system(size: 18))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
                .background(Color.cardBackground)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                
                // Sign out button
                Button(action: {
                    authService.signOut()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                        Text("Sign Out")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.top, 24)
            }
            .padding(24)
            // Support for system text size adjustments
        }
    }
    
    private func profileInfoSection(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            // Icon for visual aid
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value.isEmpty ? "Not set" : value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    private func editView(data: ProfileData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Name input
                editField(
                    icon: "person.fill",
                    title: "Name",
                    placeholder: "Your Name",
                    value: Binding(
                        get: { self.editedData?.name ?? "" },
                        set: { self.editedData?.name = $0 }
                    )
                )
                
                // Gender picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                        
                        Text("Gender")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Picker("Select Gender", selection: Binding(
                        get: { self.editedData?.gender ?? "" },
                        set: { self.editedData?.gender = $0 }
                    )) {
                        Text("Select Gender").tag("")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .font(.system(size: 18))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Weight input
                editField(
                    icon: "scalemass.fill",
                    title: "Weight (kg)",
                    placeholder: "Your Weight",
                    keyboardType: .decimalPad,
                    value: Binding(
                        get: { self.editedData?.weight ?? "" },
                        set: { self.editedData?.weight = $0 }
                    )
                )
                
                // Age input
                editField(
                    icon: "calendar",
                    title: "Age",
                    placeholder: "Your Age",
                    keyboardType: .numberPad,
                    value: Binding(
                        get: { self.editedData?.age ?? "" },
                        set: { self.editedData?.age = $0 }
                    )
                )
                
                // Activity level picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                        
                        Text("Activity Level")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Menu {
                        ForEach(activityLevels, id: \.self) { level in
                            Button(action: {
                                self.editedData?.activityLevel = level
                            }) {
                                Text(level)
                                    .font(.system(size: 18))
                            }
                        }
                    } label: {
                        HStack {
                            Text(editedData?.activityLevel.isEmpty ?? true ? "Select Activity Level" : editedData?.activityLevel ?? "")
                                .font(.system(size: 18))
                                .foregroundColor(editedData?.activityLevel.isEmpty ?? true ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Health conditions
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                        
                        Text("Health Conditions")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Text("Tap conditions that apply to you:")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(healthConditionOptions, id: \.self) { condition in
                            Button(action: {
                                toggleHealthCondition(condition)
                            }) {
                                HStack {
                                    if editedData?.healthConditions.contains(condition) ?? false {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 20))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 20))
                                    }
                                    
                                    Text(condition)
                                        .font(.system(size: 18))
                                        .foregroundColor(editedData?.healthConditions.contains(condition) ?? false ? .white : .primary)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(editedData?.healthConditions.contains(condition) ?? false ? Color.red : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Medications
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                        
                        Text("Medications")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Text("Tap medications that apply to you:")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(medicationOptions, id: \.self) { medication in
                            Button(action: {
                                toggleMedication(medication)
                            }) {
                                HStack {
                                    if editedData?.medications.contains(medication) ?? false {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 20))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 20))
                                    }
                                    
                                    Text(medication)
                                        .font(.system(size: 18))
                                        .foregroundColor(editedData?.medications.contains(medication) ?? false ? .white : .primary)
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(editedData?.medications.contains(medication) ?? false ? Color.blue : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: handleSave) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Save Changes")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isEditing = false
                        editedData = profileData
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Cancel")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .cornerRadius(12)
                    }
                }
                .padding(.top, 32)
            }
            .padding(24)
            // Support for system text size adjustments
        }
    }
    
    private func editField(icon: String, title: String, placeholder: String, keyboardType: UIKeyboardType = .default, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
            }
            
            TextField(placeholder, text: value)
                .font(.system(size: 18))
                .keyboardType(keyboardType)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
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
