import GoUtil
import Foundation

#if canImport(Glibc)
    @preconcurrency import Glibc
#elseif canImport(Musl)
    @preconcurrency import Musl
#endif

typealias HttpHandlerFn = @convention(c) (UInt) -> Void

let basicHandler: HttpHandlerFn = { ctxID in
    let ctx = UnsafeMutableRawPointer(bitPattern: ctxID)
    guard let ctx = ctx else { return }

    let message = "Hello from Swift!\n"
    guard let mutablePtr = strdup(message) else { return }
    HttpWrite(ctx, mutablePtr, Int32(strlen(mutablePtr)))
    free(mutablePtr)
}

let extensiveHandler: HttpHandlerFn = { ctxID in
    let ctx = UnsafeMutableRawPointer(bitPattern: ctxID)
    guard let ctx = ctx else { return }

    var response = ""

    // 1. Request Method
    if let methodPtr = ReqGetMethod(ctx) {
        let method = String(cString: methodPtr)
        response += "Method: \(method)\n"
        free(methodPtr)
    }

    // 2. URL and Path
    if let pathPtr = ReqGetPath(ctx) {
        let path = String(cString: pathPtr)
        response += "Path: \(path)\n"
        free(pathPtr)
    }

    if let urlPtr = ReqGetURL(ctx) {
        let url = String(cString: urlPtr)
        response += "Full URL: \(url)\n"
        free(urlPtr)
    }

    // 3. Query Parameters
    if let rawQueryPtr = ReqGetRawQuery(ctx) {
        let rawQuery = String(cString: rawQueryPtr)
        response += "Raw Query: \(rawQuery)\n"
        free(rawQueryPtr)
    }

    if let nameKey = strdup("name") {
        if let valuePtr = ReqGetQuery(ctx, nameKey) {
            let value = String(cString: valuePtr)
            if !value.isEmpty {
                response += "Query 'name': \(value)\n"
            }
            free(valuePtr)
        }
        free(nameKey)
    }

    // 4. Host and Remote Address
    if let hostPtr = ReqGetHost(ctx) {
        let host = String(cString: hostPtr)
        response += "Host: \(host)\n"
        free(hostPtr)
    }

    if let remotePtr = ReqGetRemoteAddr(ctx) {
        let remote = String(cString: remotePtr)
        response += "Remote Address: \(remote)\n"
        free(remotePtr)
    }

    // 5. Protocol
    if let protoPtr = ReqGetProto(ctx) {
        let proto = String(cString: protoPtr)
        response += "Protocol: \(proto)\n"
        free(protoPtr)
    }

    // 6. Request Headers
    if let uaKey = strdup("User-Agent") {
        if let valuePtr = ReqGetHeader(ctx, uaKey) {
            let value = String(cString: valuePtr)
            response += "User-Agent Header: \(value)\n"
            free(valuePtr)
        }
        free(uaKey)
    }

    if let uaPtr = ReqGetUserAgent(ctx) {
        let ua = String(cString: uaPtr)
        response += "User-Agent (method): \(ua)\n"
        free(uaPtr)
    }

    if let refererPtr = ReqGetReferer(ctx) {
        let referer = String(cString: refererPtr)
        if !referer.isEmpty {
            response += "Referer: \(referer)\n"
        }
        free(refererPtr)
    }

    if let ctKey = strdup("Content-Type") {
        if let valuePtr = ReqGetHeader(ctx, ctKey) {
            let value = String(cString: valuePtr)
            if !value.isEmpty {
                response += "Content-Type: \(value)\n"
            }
            free(valuePtr)
        }
        free(ctKey)
    }

    // 7. Content Length
    let contentLen = ReqGetContentLength(ctx)
    response += "Content-Length: \(contentLen)\n"

    // 8. Cookies
    if let cookieName = strdup("session") {
        if let cookiePtr = ReqGetCookie(ctx, cookieName) {
            let cookie = String(cString: cookiePtr)
            if !cookie.isEmpty {
                response += "Session Cookie: \(cookie)\n"
            }
            free(cookiePtr)
        }
        free(cookieName)
    }

    // 9. Request Body (if present)
    if contentLen > 0 {
        var bodyLength: Int32 = 0
        if let bodyPtr = ReqReadBodyFull(ctx, &bodyLength) {
            if bodyLength > 0 {
                let buffer = UnsafeBufferPointer(start: bodyPtr, count: Int(bodyLength))
                var bodyString = ""
                for i in 0..<Int(bodyLength) {
                    let byte = buffer[i]
                    if byte >= 32 && byte < 127 {
                        bodyString.append(Character(UnicodeScalar(UInt8(byte))))
                    } else if byte == 10 || byte == 13 {
                        bodyString.append(Character(UnicodeScalar(UInt8(byte))))
                    }
                }

                if !bodyString.isEmpty {
                    response += "Body: \(bodyString)\n"
                } else {
                    response += "Body: [binary data, \(bodyLength) bytes]\n"
                }
            }
            free(bodyPtr)
        }
    }

    response += "\n--- Response Demonstration ---\n"

    // 10. Set Response Headers
    if let ctHeaderKey = strdup("Content-Type"),
        let ctHeaderValue = strdup("text/plain; charset=utf-8")
    {
        HttpSetHeader(ctx, ctHeaderKey, ctHeaderValue)
        free(ctHeaderKey)
        free(ctHeaderValue)
    }

    if let customKey = strdup("X-Swift-Server"),
        let customValue = strdup("GoUtil-Swift-Bridge")
    {
        HttpSetHeader(ctx, customKey, customValue)
        free(customKey)
        free(customValue)
    }

    if let addKey = strdup("X-Custom-Header"),
        let addValue = strdup("CustomValue123")
    {
        HttpAddHeader(ctx, addKey, addValue)
        free(addKey)
        free(addValue)
    }

    // 11. Set a Cookie
    if let cookieNameSet = strdup("response_cookie"),
        let cookieValue = strdup("swift_session_\(Int.random(in: 1000...9999))"),
        let cookiePath = strdup("/")
    {
        HttpSetCookie(ctx, cookieNameSet, cookieValue, cookiePath, 3600)
        free(cookieNameSet)
        free(cookieValue)
        free(cookiePath)
    }

    response += "Custom headers and cookies have been set!\n"
    response += "Check your browser's developer tools to see them.\n"

    // 12. Write Response
    guard let responsePtr = strdup(response) else { return }
    HttpWrite(ctx, responsePtr, Int32(strlen(responsePtr)))
    free(responsePtr)
}

@main
struct Entry {
    static func main() {
        if let helloPath = strdup("/hello") {
            NewRoute(helloPath, basicHandler)
            free(helloPath)
        }

        if let extensivePath = strdup("/extensive") {
            NewRoute(extensivePath, extensiveHandler)
            free(extensivePath)
        }

        // Start server in background thread
        let serverThread = Thread {
            if let port = strdup(":6969") {
                print("Starting server on", String(cString: port))
                if let err = StartServer(port) {
                    EPrint("StartingServer(): \(String(cString: err))")
                    free(err)
                }
                free(port)
            }
        }
        serverThread.start()

        var seconds = 0
        while true {
            let s = "\r\(seconds)"
            guard let ptr = strdup(s) else { continue }
            _ = write(STDOUT_FILENO, ptr, strlen(ptr))
            free(ptr)
            sleep(1)
            seconds += 1
        }
    }
}
