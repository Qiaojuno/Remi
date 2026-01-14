//
//  TimePickerSheet.swift
//  Halloo
//
//  Time picker sheet for selecting habit/task times
//

import SwiftUI

struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    @Binding var selectedTimes: [Date]
    @Binding var isPresented: Bool

    // MARK: - Allowed Time Range (6 AM - 9 PM, TCPA Compliant)

    /// Earliest allowed time: 6:00 AM
    private var minTime: Date {
        Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date()
    }

    /// Latest allowed time: 9:00 PM (21:00) - TCPA quiet hours start at 9 PM
    private var maxTime: Date {
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    }

    /// Clamps selected time to allowed range on appear
    private func clampedTime(_ time: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)

        if hour < 6 {
            return minTime
        } else if hour >= 21 {
            return maxTime
        }
        return time
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.gray)

                Spacer()

                Text("Select Time")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button("Done") {
                    // Check for duplicates
                    let calendar = Calendar.current
                    let newHour = calendar.component(.hour, from: selectedTime)
                    let newMinute = calendar.component(.minute, from: selectedTime)

                    let isDuplicate = selectedTimes.contains { existingTime in
                        let existingHour = calendar.component(.hour, from: existingTime)
                        let existingMinute = calendar.component(.minute, from: existingTime)
                        return existingHour == newHour && existingMinute == newMinute
                    }

                    if !isDuplicate {
                        selectedTimes.append(selectedTime)
                    }
                    isPresented = false
                }
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Time Picker - Wheel style, restricted to 6 AM - 11 PM
            DatePicker(
                "Select Time",
                selection: $selectedTime,
                in: minTime...maxTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Hint text explaining the restriction
            Text("Reminders can be scheduled between 6 AM and 9 PM")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .padding(.bottom, 16)
        }
        .presentationDetents([.fraction(0.45)]) // Slightly taller to fit hint
        .presentationDragIndicator(.visible)
        .onAppear {
            // Clamp initial time to allowed range
            selectedTime = clampedTime(selectedTime)
        }
    }
}
