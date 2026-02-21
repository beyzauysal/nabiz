import SwiftUI

struct ContentView: View {
    private let accent = Color(red: 46/255, green: 196/255, blue: 182/255)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 22) {

                    Spacer()

                    Image("nabizLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 230)
                        .padding(.bottom, 10)

                    Text("Measure your heart rate instantly")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.gray)

                    Spacer()

                    VStack(spacing: 14) {

                        NavigationLink(destination: MeasurementView()) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Start Measuring")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .opacity(0.9)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
                        }

                        NavigationLink(destination: HistoryView()) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("History")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .opacity(0.7)
                            }
                            .foregroundColor(accent)
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(accent.opacity(0.45), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.horizontal, 18)

                    Spacer()

                    Text("Nabız")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

