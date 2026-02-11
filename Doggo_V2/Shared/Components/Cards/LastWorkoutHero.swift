import SwiftUI

struct LastWorkoutHero: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.name)
                        .font(.title3).bold()
                        .foregroundStyle(.white)
                    Text(session.date.formatted(date: .complete, time: .shortened))
                        .font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Duration").font(.caption).foregroundStyle(.gray)
                    Text("\(Int(session.duration / 60)) min").bold().foregroundStyle(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Exercises").font(.caption).foregroundStyle(.gray)
                    Text("\(getUniqueExerciseCount(session))").bold().foregroundStyle(.white)
                }
                
                VStack(alignment: .leading) {
                    Text("Sets").font(.caption).foregroundStyle(.gray)
                    Text("\(session.sets.count)").bold().foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(uiColor: .secondarySystemBackground), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    func getUniqueExerciseCount(_ session: WorkoutSession) -> Int {
        let unique = Set(session.sets.compactMap { $0.exercise?.id })
        return unique.count
    }
}
