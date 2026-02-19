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
                    print("Kamera izni verilmedi")
                }
            }
            return
        default:
            print("Kamera izni engellenmiş")
            return
        }

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("Kamera bulunamadı")
            return
        }
        device = videoDevice
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Input eklenemedi: \(error.localizedDescription)")
        }
        
        if videoDevice.hasTorch {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.torchMode = .on
                videoDevice.unlockForConfiguration()
                print("Flaş açıldı")
            } catch {
                print("Flaş açılamadı")
            }
        }
        
        session.startRunning()
    }
}


