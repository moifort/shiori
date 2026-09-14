@preconcurrency import AVFoundation
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    let onCapture: @MainActor (Data) -> Void
    @Binding var shouldCapture: Bool

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if shouldCapture {
            uiViewController.capturePhoto()
            DispatchQueue.main.async { shouldCapture = false }
        }
    }

    /// The camera must not outlive the view: releasing the controller is not
    /// enough to guarantee the hardware is freed, so the session is closed here.
    static func dismantleUIViewController(_ uiViewController: CameraViewController, coordinator: ()) {
        uiViewController.closeSession()
    }
}

@MainActor
final class CameraViewController: UIViewController {
    var onCapture: (@MainActor (Data) -> Void)?

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let delegateHandler = PhotoCaptureDelegate()
    /// Opening and closing a session blocks its caller, and both must stay
    /// ordered: they run one after the other on this queue, never on the main one.
    private let sessionQueue = DispatchQueue(label: "shiori.camera.session", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        delegateHandler.viewController = self
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        openSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else { return }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        openSession()
    }

    func capturePhoto() {
        // Shooting through a closed session raises: a tap landing after the stream
        // was cut, or before it is up, is simply ignored.
        guard captureSession.isRunning else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegateHandler)
    }

    func handleCapturedPhoto(_ data: Data) {
        // The shot is in: the analysis that follows has no use for a live camera,
        // so the stream is closed right away rather than at the end of the flow.
        closeSession()
        onCapture?(data)
    }

    func openSession() {
        let session = captureSession
        sessionQueue.async {
            // Nothing to open on a device without a usable camera: `setupCamera`
            // bailed out before wiring an input, and running empty logs for nothing.
            guard !session.isRunning, !session.inputs.isEmpty else { return }
            session.startRunning()
        }
    }

    func closeSession() {
        let session = captureSession
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    @MainActor weak var viewController: CameraViewController?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        if let image = UIImage(data: data), let jpeg = image.resized(maxDimension: 800).jpegData(compressionQuality: 0.6) {
            Task { @MainActor in
                self.viewController?.handleCapturedPhoto(jpeg)
            }
        }
    }
}
