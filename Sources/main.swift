import Foundation

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

@main
struct Entry {
    static func main() {
        print("Hello, World!")
    }
}
