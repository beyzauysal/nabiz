import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @Binding var bpm: Int
    @Binding var message: String
    @Binding var fingerDetected: Bool
    @Binding var isMeasuring: Bool

    init(bpm: Binding<Int>, message: Binding<String>, fingerDetected: Binding<Bool>, isMeasuring: Binding<Bool>) {
        self._bpm = bpm
        self._message = message
        self._fingerDetected = fingerDetected
        self._isMeasuring = isMeasuring
    }

    private let session = AVCaptureSession()

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer
        context.coordinator.configureCamera()

        guard context.coordinator.isCameraAuthorized else {
            return view
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                context.coordinator.turnOnTorch()
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds

        if context.coordinator.isCameraAuthorized {
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                context.coordinator.turnOnTorch()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            bpm: $bpm,
            message: $message,
            fingerDetected: $fingerDetected,
            isMeasuring: $isMeasuring,
            session: session
        )
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        @Binding var bpm: Int
        @Binding var message: String
        @Binding var fingerDetected: Bool
        @Binding var isMeasuring: Bool

        var previewLayer: AVCaptureVideoPreviewLayer?

        private let session: AVCaptureSession
        private var device: AVCaptureDevice?

        var isCameraAuthorized: Bool = false

        private var redValues: [CGFloat] = []
        private var smoothedValues: [CGFloat] = []
        private var bpmValues: [Int] = []
        private var lastPeakTime: CFTimeInterval = 0
        private var peaks: [CFTimeInterval] = []

        init(
            bpm: Binding<Int>,
            message: Binding<String>,
            fingerDetected: Binding<Bool>,
            isMeasuring: Binding<Bool>,
            session: AVCaptureSession
        ) {
            _bpm = bpm
            _message = message
            _fingerDetected = fingerDetected
            _isMeasuring = isMeasuring
            self.session = session
            super.init()
        }

        func configureCamera() {

            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .authorized:
                isCameraAuthorized = true
                break

            case .notDetermined:
                isCameraAuthorized = false
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        self.isCameraAuthorized = granted
                        if granted {
                            self.configureCamera()
                        } else {
                            self.message = "Camera permission is required to measure pulse."
                        }
                    }
                }
                return

            default:
                isCameraAuthorized = false
                DispatchQueue.main.async {
                    self.message = "Camera access is blocked. Please enable it in Settings."
                }
                return
            }

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            session.sessionPreset = .low

            guard let videoDevice = AVCaptureDevice.default(for: .video) else {
                return
            }
            device = videoDevice

            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            } catch {
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        }

        func turnOnTorch() {
            guard isCameraAuthorized else { return }

            if let device = device, device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .on
                    device.unlockForConfiguration()
                } catch { }
            }
        }

        private func resetSignal() {
            redValues.removeAll()
            smoothedValues.removeAll()
            bpmValues.removeAll()
            peaks.removeAll()
            lastPeakTime = 0
            bpm = 0
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard isMeasuring else { return }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

            var rTotal: CGFloat = 0
            var gTotal: CGFloat = 0
            var bTotal: CGFloat = 0
            var pixelCount: CGFloat = 0

            if let baseAddress = baseAddress {
                for y in stride(from: 0, to: height, by: 10) {
                    let row = baseAddress + y * bytesPerRow
                    for x in stride(from: 0, to: width * 4, by: 40) {
                        let pixel = row + x
                        let b = CGFloat(pixel.load(fromByteOffset: 0, as: UInt8.self))
                        let g = CGFloat(pixel.load(fromByteOffset: 1, as: UInt8.self))
                        let r = CGFloat(pixel.load(fromByteOffset: 2, as: UInt8.self))
                        rTotal += r
                        gTotal += g
                        bTotal += b
                        pixelCount += 1
                    }
                }
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            let denom = max(pixelCount, 1)
            let avgR = rTotal / denom
            let avgG = gTotal / denom
            let avgB = bTotal / denom

            DispatchQueue.main.async {
                let detected = (avgR > 110) && (avgR > avgG + 15) && (avgR > avgB + 15)
                self.fingerDetected = detected

                if !detected {
                    self.message = "Place your finger over the camera flash."
                    self.resetSignal()
                    return
                }

                self.redValues.append(avgR)
                if self.redValues.count > 20 { self.redValues.removeFirst() }

                let avg = self.redValues.reduce(0, +) / CGFloat(self.redValues.count)
                self.smoothedValues.append(avg)
                if self.smoothedValues.count > 100 { self.smoothedValues.removeFirst() }

                if self.smoothedValues.count > 3 {
                    let last3 = self.smoothedValues.suffix(3)
                    if last3.dropLast().first! < last3.last! &&
                        last3.dropLast().last! < last3.last! {

                        let now = CACurrentMediaTime()
                        if now - self.lastPeakTime > 0.4 {
                            self.peaks.append(now)
                            self.lastPeakTime = now

                            if self.peaks.count > 2 {
                                let intervals = zip(self.peaks.dropFirst(), self.peaks).map(-)
                                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                                let bpmCalc = Int(60.0 / avgInterval)

                                if bpmCalc >= 40 && bpmCalc <= 180 {
                                    self.bpmValues.append(bpmCalc)
                                    if self.bpmValues.count > 5 { self.bpmValues.removeFirst() }
                                    self.bpm = self.bpmValues.reduce(0, +) / self.bpmValues.count
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MeasurementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bpm: Int = 0
    @State private var message: String = "Place your finger over the camera flash."
    @State private var fingerDetected: Bool = false

    @State private var isMeasuring = false
    @State private var elapsedTime = 0
    @State private var showBPM = false

    @State private var timer: Timer? = nil

    private let accent = Color(red: 46/255, green: 196/255, blue: 182/255)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        stopTimer()
                        isMeasuring = false
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                Spacer()

                ZStack {
                    CameraPreview(bpm: $bpm, message: $message, fingerDetected: $fingerDetected, isMeasuring: $isMeasuring)
                        .clipShape(Circle())
                        .frame(width: 280, height: 280)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: CGFloat(elapsedTime) / 30.0)
                                .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: elapsedTime)
                        )
                        .shadow(radius: 10)
                }

                VStack(spacing: 10) {
                    Group {
                        if isMeasuring && !showBPM {
                            Text("Measuring...")
                                .font(.system(size: 20, weight: .semibold))
                        } else if showBPM && isMeasuring {
                            Text("Measuring... Measured Value: \(bpm)")
                                .font(.system(size: 20, weight: .bold))
                        } else if !isMeasuring && showBPM {
                            Text("Heart Rate: \(bpm)")
                                .font(.system(size: 28, weight: .bold))
                        } else {
                            Text(" ")
                                .font(.system(size: 20, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(height: 36)

                    Text(message)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)

                    if isMeasuring && !fingerDetected {
                        Text("Please place your finger over the camera flash to start measurement.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 18)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            Button {
                startMeasurement()
            } label: {
                Text(isMeasuring ? "Measuring..." : "Start Measurement")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isMeasuring)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.98))
        }
        .onChange(of: fingerDetected) { _, newValue in
            guard isMeasuring else { return }
            if newValue {
                resumeTimerIfNeeded()
            } else {
                stopTimer()
                message = "Place your finger over the flash."
            }
        }
        .onDisappear {
            stopTimer()
            isMeasuring = false
        }
    }

    private func startMeasurement() {
        bpm = 0
        message = "Place your finger over the flash."
        isMeasuring = true
        elapsedTime = 0
        showBPM = false

        if fingerDetected {
            resumeTimerIfNeeded()
        } else {
            stopTimer()
        }
    }

    private func resumeTimerIfNeeded() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if !fingerDetected { return }

            elapsedTime += 1

            if elapsedTime >= 15 {
                showBPM = true
            }

            if elapsedTime >= 30 {
                t.invalidate()
                timer = nil
                isMeasuring = false
                showBPM = true
                message = "Measured Value = \(bpm)"

                if bpm > 0 && fingerDetected {
                    BPMStorage.appendSession(bpm: bpm)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}









