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

            // Time Picker - Keep as wheel but limit space
            DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.4)]) // Only pop up 40% of screen
        .presentationDragIndicator(.visible)
    }
}
