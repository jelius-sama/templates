import GoUtil
#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

@main
struct Entry {
    static func main() {
        Test()

        var seconds = 0

        while true {
            if seconds == 70 {
                print("\n", terminator: "")
                break
            }

            let s = "\r\(seconds)"
            s.withCString { ptr in
                _ = write(STDOUT_FILENO, ptr, strlen(ptr))
            }
            sleep(1)
            seconds += 1
        }
    }
}
