import SwiftUI

enum PhotoSaveStatus: Equatable {
    case idle
    case saving
    case saved
    case error(String)
    
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

struct PhotoSaveToast: View {
    let status: PhotoSaveStatus
    
    var body: some View {
        HStack(spacing: 8) {
            switch status {
            case .saving:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            case .saved:
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.system(size: 14, weight: .bold))
            case .error:
                Image(systemName: "xmark")
                    .foregroundColor(.red)
                    .font(.system(size: 14, weight: .bold))
            case .idle:
                EmptyView()
            }
            
            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .onAppear {
            if status == .saved {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            } else if case .error = status {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)
            }
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return ""
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .error(let message):
            return message
        }
    }
}

#Preview("Toast States") {
    ZStack {
        Color.gray
        VStack(spacing: 20) {
            PhotoSaveToast(status: .saving)
            PhotoSaveToast(status: .saved)
            PhotoSaveToast(status: .error("Failed"))
        }
    }
}
