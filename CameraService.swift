import AVFoundation

class CameraService: NSObject {
    let session = AVCaptureSession()
    var device: AVCaptureDevice?
    
    override init() {
        super.init()
        configureCamera()
    }
    
    private func configureCamera() {
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.configureCamera()
                    }
                } else {
                    print("Camera access was not granted. Please enable it in Settings.")
                }
            }
            return
        default:
            print("Camera access has been blocked. Please enable it in Settings.")
            return
        }

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("No camera was found on this device.")
            return
        }
        device = videoDevice
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Failed to add input.: \(error.localizedDescription)")
        }
        
        if videoDevice.hasTorch {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .on
                videoDevice.unlockForConfiguration()
                print("Flash has been turned on.")
            } catch {
                print("Unable to enable flash.")
            }
        }
        
        session.startRunning()
    }
}


