//
//  IntakeCalculator.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.06.
//

import Foundation

struct IntakeCalculator {
    // Calculate water intake based on multiple factors
    
    static func calculateWaterIntake(
        weatherData: WeatherData?,
        profileData: ProfileData
    ) -> IntakeRecommendations.WaterRecommendation {
        guard !profileData.weight.isEmpty,
              let weight = Double(profileData.weight),
              weight > 0 && weight < 300,
              !profileData.age.isEmpty,
              let age = Int(profileData.age),
              age > 0 && age < 120 else {
            return IntakeRecommendations.WaterRecommendation(
                recommendedLiters: 2.0,
                adjustmentFactors: ["Invalid profile data"]
            )
        }
        
        var adjustmentFactors: [String] = []
        var baseIntake: Double = weight * 0.03  // Back to 30ml per kg
        
        let MAX_RECOMMENDED_INTAKE = 2.5
        let MIN_RECOMMENDED_INTAKE = 1.5
        
        // Age adjustment
        if age > 50 {
            baseIntake *= 0.9  // Moderate reduction
            adjustmentFactors.append("Senior age adjustment")
        }
        
        // Activity level adjustment
        switch profileData.activityLevel {
        case "Sedentary":
            baseIntake *= 0.9
            adjustmentFactors.append("Sedentary lifestyle reduction")
        case "Lightly Active":
            baseIntake *= 1.0
        case "Moderately Active":
            baseIntake *= 1.1
            adjustmentFactors.append("Moderate activity boost")
        case "Very Active":
            baseIntake *= 1.2
            adjustmentFactors.append("High activity boost")
        case "Extra Active":
            baseIntake *= 1.3
            adjustmentFactors.append("Extra activity boost")
        default:
            break
        }
        
        // Weather temperature adjustment
        if let temp = weatherData?.temperature {
            if temp > 30 {
                baseIntake *= 1.2
                adjustmentFactors.append("High temperature increase")
            } else if temp > 25 {
                baseIntake *= 1.1
                adjustmentFactors.append("Warm temperature increase")
            }
        }
        
        // Humidity adjustment
        if let humidity = weatherData?.humidity {
            if humidity > 70 {
                baseIntake *= 1.1
                adjustmentFactors.append("High humidity increase")
            }
        }
        
        // Health conditions adjustment (use a flag to prevent duplicate adjustments)
        var hasKidneyCondition = false
        for condition in profileData.healthConditions {
            switch condition {
            case "Kidney Disease" where !hasKidneyCondition:
                baseIntake *= 0.9
                adjustmentFactors.append("Kidney condition adjustment")
                hasKidneyCondition = true
            case "Urinary Incontinence" where !hasKidneyCondition:
                baseIntake *= 0.9
                adjustmentFactors.append("Urinary condition adjustment")
                hasKidneyCondition = true
            case "Diabetes":
                baseIntake *= 1.0
                adjustmentFactors.append("Diabetes hydration consideration")
            default:
                break
            }
        }
        
        // Medications adjustment
        for medication in profileData.medications {
            switch medication {
            case "Blood Pressure Medications":
                baseIntake *= 0.9
                adjustmentFactors.append("Blood pressure medication adjustment")
            default:
                break
            }
        }
        
        // Ensure intake is within reasonable limits
        let roundedIntake = max(MIN_RECOMMENDED_INTAKE,
                                 min(baseIntake, MAX_RECOMMENDED_INTAKE))
        
        return IntakeRecommendations.WaterRecommendation(
            recommendedLiters: round(roundedIntake * 10) / 10,
            adjustmentFactors: adjustmentFactors
        )
    }
    
    // Calculate sugar intake based on multiple factors
    static func calculateSugarIntake(
        profileData: ProfileData
    ) -> IntakeRecommendations.SugarRecommendation {
        print("💧 Water Intake Calculation Input:")
        print("Weight: \(profileData.weight)")
        print("Age: \(profileData.age)")
        
        guard let weight = Double(profileData.weight),
              !profileData.age.isEmpty,
              let age = Int(profileData.age) else {
            // Default recommendation if data is incomplete
            return IntakeRecommendations.SugarRecommendation(
                recommendedGrams: 25,
                adjustmentFactors: ["Default recommendation"]
            )
        }
        
        var adjustmentFactors: [String] = []
        var baseIntake: Double = 25 // WHO recommended daily limit
        
        // Age adjustment
        if age < 30 {
            baseIntake *= 1.1
            adjustmentFactors.append("Young metabolism adjustment")
        } else if age > 50 {
            baseIntake *= 0.9
            adjustmentFactors.append("Age metabolism reduction")
        }
        
        // Activity level adjustment
        switch profileData.activityLevel {
        case "Sedentary":
            baseIntake *= 0.8
            adjustmentFactors.append("Sedentary lifestyle reduction")
        case "Lightly Active":
            baseIntake *= 0.9
            adjustmentFactors.append("Lightly active reduction")
        case "Moderately Active":
            baseIntake *= 1.0
        case "Very Active":
            baseIntake *= 1.1
            adjustmentFactors.append("Active lifestyle increase")
        case "Extra Active":
            baseIntake *= 1.2
            adjustmentFactors.append("High activity increase")
        default:
            break
        }
        
        // Health conditions adjustment
        for condition in profileData.healthConditions {
            switch condition {
            case "Diabetes", "Pre-diabetes", "Obesity":
                baseIntake *= 0.7
                adjustmentFactors.append("Diabetes/Obesity sugar reduction")
            case "High Blood Pressure", "Heart Conditions":
                baseIntake *= 0.8
                adjustmentFactors.append("Cardiovascular health reduction")
            default:
                break
            }
        }
        
        // Medications adjustment
        for medication in profileData.medications {
            switch medication {
            case "Diabetes Medications":
                baseIntake *= 0.6
                adjustmentFactors.append("Diabetes medication sugar reduction")
            default:
                break
            }
        }
        
        // Round to nearest 1 and ensure minimum and maximum limits
        let roundedIntake = max(10, min(40, round(baseIntake)))
        
        return IntakeRecommendations.SugarRecommendation(
            recommendedGrams: roundedIntake,
            adjustmentFactors: adjustmentFactors
        )
    }
}
