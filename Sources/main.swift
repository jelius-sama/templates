import NIO

@main
struct Entry {
    static func main() throws {
        // Event loop group (thread pool)
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: System.coreCount
        )
        defer {
            try? group.syncShutdownGracefully()
        }

        // Bootstrap = equivalent of ListenAndServe setup
        let bootstrap = ServerBootstrap(group: group)
            // Backlog & socket options
            .serverChannelOption(
                ChannelOptions.backlog,
                value: 256
            )
            .serverChannelOption(
                ChannelOptions.socketOption(.so_reuseaddr),
                value: 1
            )

            // Options for accepted connections
            .childChannelOption(
                ChannelOptions.socketOption(.so_reuseaddr),
                value: 1
            )

            // Pipeline for each connection
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(HelloHandler())
            }

        // Bind and start listening
        let channel = try bootstrap.bind(
            host: "0.0.0.0",
            port: 6969
        ).wait()

        print("Listening on \(channel.localAddress!)")

        // Block forever
        try channel.closeFuture.wait()
    }
}
