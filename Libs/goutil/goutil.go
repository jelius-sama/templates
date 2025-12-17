package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef void (*http_handler_fn)(uintptr_t ctx_id);
typedef const char cchar_t;

static inline void call_swift_handler(http_handler_fn fn, uintptr_t ctx_id) {
    fn(ctx_id);
}
*/
import "C"
import (
    "fmt"
    "io"
    "net/http"
    "os"
    "sync"
    "unsafe"
)

type contextData struct {
    writer  http.ResponseWriter
    request *http.Request
}

var (
    multiplexer = http.NewServeMux()
    contextMap  = make(map[uintptr]*contextData)
    mapMu       sync.RWMutex
    nextID      uintptr = 1
)

//export StartServer
func StartServer(port *C.char) *C.char {
    err := http.ListenAndServe(C.GoString(port), multiplexer)
    return C.CString(err.Error())
}

//export EPrint
func EPrint(msg *C.cchar_t) {
    fmt.Fprintln(os.Stderr, C.GoString((*C.char)(msg)))
}

//export Print
func Print(msg *C.cchar_t) {
    fmt.Fprintln(os.Stdout, C.GoString((*C.char)(msg)))
}

//export NewRoute
func NewRoute(path *C.char, handler C.http_handler_fn) {
    handleFunc := func(w http.ResponseWriter, r *http.Request) {
        // Allocate a single context ID
        mapMu.Lock()
        ctxID := nextID
        nextID++
        contextMap[ctxID] = &contextData{
            writer:  w,
            request: r,
        }
        mapMu.Unlock()

        defer func() {
            mapMu.Lock()
            delete(contextMap, ctxID)
            mapMu.Unlock()
        }()

        // Call handler with just the ID (no structs, no pointers)
        C.call_swift_handler(handler, C.uintptr_t(ctxID))
    }

    multiplexer.HandleFunc(C.GoString(path), handleFunc)
}

/********** Context Accessors **********/

//export GetRequestID
func GetRequestID(ctxID C.uintptr_t) unsafe.Pointer {
    return unsafe.Pointer(uintptr(ctxID))
}

//export GetResponseID
func GetResponseID(ctxID C.uintptr_t) unsafe.Pointer {
    return unsafe.Pointer(uintptr(ctxID))
}

/********** Response Writer Methods **********/

//export HttpWrite
func HttpWrite(ctxID unsafe.Pointer, data *C.char, length C.int) C.int {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        n, _ := ctx.writer.Write(C.GoBytes(unsafe.Pointer(data), length))
        return C.int(n)
    }
    return 0
}

//export HttpWriteHeader
func HttpWriteHeader(ctxID unsafe.Pointer, statusCode C.int) {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        ctx.writer.WriteHeader(int(statusCode))
    }
}

//export HttpSetHeader
func HttpSetHeader(ctxID unsafe.Pointer, key *C.char, value *C.char) {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        ctx.writer.Header().Set(C.GoString(key), C.GoString(value))
    }
}

//export HttpAddHeader
func HttpAddHeader(ctxID unsafe.Pointer, key *C.char, value *C.char) {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        ctx.writer.Header().Add(C.GoString(key), C.GoString(value))
    }
}

//export HttpDelHeader
func HttpDelHeader(ctxID unsafe.Pointer, key *C.char) {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        ctx.writer.Header().Del(C.GoString(key))
    }
}

//export HttpGetHeader
func HttpGetHeader(ctxID unsafe.Pointer, key *C.char) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        value := ctx.writer.Header().Get(C.GoString(key))
        return C.CString(value) // Caller must free
    }
    return nil
}

/********** Request Methods **********/

//export ReqGetMethod
func ReqGetMethod(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.Method)
    }
    return nil
}

//export ReqGetURL
func ReqGetURL(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.URL.String())
    }
    return nil
}

//export ReqGetPath
func ReqGetPath(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.URL.Path)
    }
    return nil
}

//export ReqGetRawQuery
func ReqGetRawQuery(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.URL.RawQuery)
    }
    return nil
}

//export ReqGetQuery
func ReqGetQuery(ctxID unsafe.Pointer, key *C.char) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        value := ctx.request.URL.Query().Get(C.GoString(key))
        return C.CString(value)
    }
    return nil
}

//export ReqGetHeader
func ReqGetHeader(ctxID unsafe.Pointer, key *C.char) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        value := ctx.request.Header.Get(C.GoString(key))
        return C.CString(value)
    }
    return nil
}

//export ReqGetHost
func ReqGetHost(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.Host)
    }
    return nil
}

//export ReqGetRemoteAddr
func ReqGetRemoteAddr(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.RemoteAddr)
    }
    return nil
}

//export ReqGetProto
func ReqGetProto(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.Proto)
    }
    return nil
}

//export ReqGetContentLength
func ReqGetContentLength(ctxID unsafe.Pointer) C.int64_t {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.int64_t(ctx.request.ContentLength)
    }
    return 0
}

//export ReqReadBody
func ReqReadBody(ctxID unsafe.Pointer, buffer *C.char, length C.int) C.int {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if !ok || ctx.request == nil || ctx.request.Body == nil {
        return 0
    }

    goBuffer := (*[1 << 30]byte)(unsafe.Pointer(buffer))[:length:length]
    n, _ := ctx.request.Body.Read(goBuffer)
    return C.int(n)
}

//export ReqReadBodyFull
func ReqReadBodyFull(ctxID unsafe.Pointer, outLen *C.int) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if !ok || ctx.request == nil || ctx.request.Body == nil {
        *outLen = 0
        return nil
    }

    data, err := io.ReadAll(ctx.request.Body)
    if err != nil {
        *outLen = 0
        return nil
    }

    *outLen = C.int(len(data))
    if len(data) == 0 {
        return nil
    }

    cData := C.CBytes(data)
    return (*C.char)(cData)
}

//export ReqGetCookie
func ReqGetCookie(ctxID unsafe.Pointer, name *C.char) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if !ok || ctx.request == nil {
        return nil
    }

    cookie, err := ctx.request.Cookie(C.GoString(name))
    if err != nil {
        return nil
    }
    return C.CString(cookie.Value)
}

//export ReqGetUserAgent
func ReqGetUserAgent(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.UserAgent())
    }
    return nil
}

//export ReqGetReferer
func ReqGetReferer(ctxID unsafe.Pointer) *C.char {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.request != nil {
        return C.CString(ctx.request.Referer())
    }
    return nil
}

//export HttpSetCookie
func HttpSetCookie(ctxID unsafe.Pointer, name *C.char, value *C.char, path *C.char, maxAge C.int) {
    id := uintptr(ctxID)
    mapMu.RLock()
    ctx, ok := contextMap[id]
    mapMu.RUnlock()

    if ok && ctx.writer != nil {
        cookie := &http.Cookie{
            Name:   C.GoString(name),
            Value:  C.GoString(value),
            Path:   C.GoString(path),
            MaxAge: int(maxAge),
        }
        http.SetCookie(ctx.writer, cookie)
    }
}

func main() {}

