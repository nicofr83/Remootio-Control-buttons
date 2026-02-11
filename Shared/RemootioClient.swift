import Foundation
import CommonCrypto

// MARK: - Remootio WebSocket API v3 Client

/// Handles the full Remootio WebSocket API v3 protocol:
/// connection, authentication (AES-256-CBC + HMAC-SHA256), and actions.
class RemootioClient: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    
    // MARK: - Published State
    @Published var connectionState: ConnectionState = .disconnected
    @Published var gateStatus: GateStatus = .unknown
    @Published var lastError: String?
    
    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting…"
        case connected = "Connected"
        case authenticating = "Authenticating…"
        case authenticated = "Ready"
    }
    
    enum GateStatus: String {
        case open = "open"
        case closed = "closed"
        case noSensor = "no sensor"
        case unknown = "unknown"
    }
    
    // MARK: - Configuration
    let deviceIP: String
    let apiSecretKey: Data  // 32 bytes
    let apiAuthKey: Data    // 32 bytes
    let deviceName: String
    
    // MARK: - Session State
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var sessionKey: Data?
    private var lastActionId: Int = 0
    private var pingTimer: Timer?
    private var actionCompletionHandlers: [Int: (Bool, String?) -> Void] = [:]
    
    // MARK: - Init
    
    init(deviceIP: String, apiSecretKey: String, apiAuthKey: String, deviceName: String) {
        self.deviceIP = deviceIP
        self.apiSecretKey = RemootioClient.hexStringToData(apiSecretKey)
        self.apiAuthKey = RemootioClient.hexStringToData(apiAuthKey)
        self.deviceName = deviceName
        super.init()
    }
    
    // MARK: - Connect
    
    func connect() {
        disconnect()
        
        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.lastError = nil
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        guard let url = URL(string: "ws://\(deviceIP):8080") else {
            DispatchQueue.main.async {
                self.lastError = "Invalid IP address"
                self.connectionState = .disconnected
            }
            return
        }
        
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listenForMessages()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionKey = nil
        actionCompletionHandlers.removeAll()
        
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.gateStatus = .unknown
        }
    }
    
    // MARK: - Actions
    
    func sendOpen(completion: ((Bool, String?) -> Void)? = nil) {
        sendAction("OPEN", completion: completion)
    }
    
    func sendClose(completion: ((Bool, String?) -> Void)? = nil) {
        sendAction("CLOSE", completion: completion)
    }
    
    func sendTrigger(completion: ((Bool, String?) -> Void)? = nil) {
        sendAction("TRIGGER", completion: completion)
    }
    
    func sendQuery(completion: ((Bool, String?) -> Void)? = nil) {
        sendAction("QUERY", completion: completion)
    }
    
    // MARK: - WebSocket Delegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
        startAuthentication()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.gateStatus = .unknown
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.connectionState = .disconnected
                self.gateStatus = .unknown
            }
        }
    }
    
    // MARK: - Message Handling
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.connectionState = .disconnected
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "PONG", "SERVER_HELLO":
            break
        case "ERROR":
            if let errorMessage = json["errorMessage"] as? String {
                DispatchQueue.main.async { self.lastError = errorMessage }
            }
        case "ENCRYPTED":
            handleEncryptedFrame(json)
        default:
            break
        }
    }
    
    // MARK: - Authentication Flow
    
    private func startAuthentication() {
        DispatchQueue.main.async { self.connectionState = .authenticating }
        sendJSON(["type": "AUTH"])
    }
    
    private func handleEncryptedFrame(_ json: [String: Any]) {
        guard let dataObj = json["data"] as? [String: Any],
              let ivBase64 = dataObj["iv"] as? String,
              let payloadBase64 = dataObj["payload"] as? String,
              let macBase64 = json["mac"] as? String else { return }
        
        let isAuthChallenge = (sessionKey == nil)
        let decryptionKey = isAuthChallenge ? apiSecretKey : sessionKey!
        
        // Verify MAC
        let macData = constructMacBase(iv: ivBase64, payload: payloadBase64)
        let calculatedMac = hmacSHA256(key: apiAuthKey, data: macData)
        
        guard let receivedMac = Data(base64Encoded: macBase64),
              calculatedMac == receivedMac else {
            DispatchQueue.main.async { self.lastError = "MAC verification failed" }
            return
        }
        
        // Decrypt
        guard let iv = Data(base64Encoded: ivBase64),
              let ciphertext = Data(base64Encoded: payloadBase64),
              let decryptedData = aesDecrypt(data: ciphertext, key: decryptionKey, iv: iv),
              let payloadStr = String(data: decryptedData, encoding: .utf8),
              let payloadJSON = payloadStr.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: payloadJSON) as? [String: Any],
              let payloadType = payload["type"] as? String else {
            DispatchQueue.main.async { self.lastError = "Decryption failed" }
            return
        }
        
        if isAuthChallenge && payloadType == "CHALLENGE" {
            handleAuthChallenge(payload)
        } else {
            handleDecryptedPayload(payload, type: payloadType)
        }
    }
    
    private func handleAuthChallenge(_ payload: [String: Any]) {
        guard let challenge = payload["challenge"] as? [String: Any],
              let sessionKeyBase64 = challenge["sessionKey"] as? String,
              let initialActionId = challenge["initialActionId"] as? Int,
              let sessionKeyData = Data(base64Encoded: sessionKeyBase64) else {
            DispatchQueue.main.async { self.lastError = "Invalid auth challenge" }
            return
        }
        
        self.sessionKey = sessionKeyData
        self.lastActionId = initialActionId
        
        sendAction("QUERY") { [weak self] success, _ in
            if success {
                DispatchQueue.main.async { self?.connectionState = .authenticated }
                self?.startPingTimer()
            }
        }
    }
    
    private func handleDecryptedPayload(_ payload: [String: Any], type: String) {
        switch type {
        case "QUERY", "TRIGGER", "OPEN", "CLOSE":
            if let response = payload["response"] as? [String: Any] {
                if let id = response["id"] as? Int { self.lastActionId = id }
                
                let success = (response["success"] as? Bool) ?? false
                let relayTriggered = (response["relayTriggered"] as? Bool) ?? false
                let errorCode = response["errorCode"] as? String
                
                if let state = response["state"] as? String {
                    DispatchQueue.main.async {
                        self.gateStatus = GateStatus(rawValue: state) ?? .unknown
                    }
                }
                
                if let id = response["id"] as? Int,
                   let handler = actionCompletionHandlers.removeValue(forKey: id) {
                    handler(success || relayTriggered, errorCode)
                }
            }
            
        case "EVENT":
            if let event = payload["event"] as? [String: Any],
               let state = event["state"] as? String {
                DispatchQueue.main.async {
                    self.gateStatus = GateStatus(rawValue: state) ?? .unknown
                }
            }
            
        default: break
        }
    }
    
    // MARK: - Send Action
    
    private func sendAction(_ action: String, completion: ((Bool, String?) -> Void)? = nil) {
        guard let sessionKey = sessionKey else {
            completion?(false, "Not authenticated")
            return
        }
        
        let nextActionId = (lastActionId + 1) % 0x7FFFFFFF
        if let completion = completion {
            actionCompletionHandlers[nextActionId] = completion
        }
        
        let unencryptedPayload: [String: Any] = ["type": action, "id": nextActionId]
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: unencryptedPayload),
              let encryptedFrame = buildEncryptedFrame(payload: payloadData, key: sessionKey) else {
            completion?(false, "Encryption failed")
            return
        }
        
        sendJSON(encryptedFrame)
    }
    
    // MARK: - Encrypted Frame Construction
    
    private func buildEncryptedFrame(payload: Data, key: Data) -> [String: Any]? {
        var iv = Data(count: 16)
        let result = iv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard result == errSecSuccess else { return nil }
        guard let ciphertext = aesEncrypt(data: payload, key: key, iv: iv) else { return nil }
        
        let ivBase64 = iv.base64EncodedString()
        let payloadBase64 = ciphertext.base64EncodedString()
        let macData = constructMacBase(iv: ivBase64, payload: payloadBase64)
        let mac = hmacSHA256(key: apiAuthKey, data: macData)
        
        return [
            "type": "ENCRYPTED",
            "data": ["iv": ivBase64, "payload": payloadBase64],
            "mac": mac.base64EncodedString()
        ]
    }
    
    // MARK: - Crypto Helpers
    
    private func constructMacBase(iv: String, payload: String) -> Data {
        // CRITICAL: order must be "iv" first, then "payload"
        let macString = "{\"iv\":\"\(iv)\",\"payload\":\"\(payload)\"}"
        return macString.data(using: .utf8)!
    }
    
    private func hmacSHA256(key: Data, data: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dataPtr in
            key.withUnsafeBytes { keyPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                        keyPtr.baseAddress!, key.count,
                        dataPtr.baseAddress!, data.count, &hmac)
            }
        }
        return Data(hmac)
    }
    
    private func aesEncrypt(data: Data, key: Data, iv: Data) -> Data? {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesEncrypted = 0
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyPtr.baseAddress!, key.count, ivPtr.baseAddress!,
                                dataPtr.baseAddress!, data.count,
                                bufferPtr.baseAddress!, bufferSize, &bytesEncrypted)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return buffer.prefix(bytesEncrypted)
    }
    
    private func aesDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesDecrypted = 0
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyPtr.baseAddress!, key.count, ivPtr.baseAddress!,
                                dataPtr.baseAddress!, data.count,
                                bufferPtr.baseAddress!, bufferSize, &bytesDecrypted)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return buffer.prefix(bytesDecrypted)
    }
    
    // MARK: - Helpers
    
    private func sendJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { self?.lastError = error.localizedDescription }
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.sendJSON(["type": "PING"])
        }
    }
    
    static func hexStringToData(_ hex: String) -> Data {
        var data = Data()
        var temp = ""
        for char in hex {
            temp += String(char)
            if temp.count == 2 {
                if let byte = UInt8(temp, radix: 16) { data.append(byte) }
                temp = ""
            }
        }
        return data
    }
}
