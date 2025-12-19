import NIO

final class HelloHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        let body = "Hello from SwiftNIO!\n"
        let response =
            "HTTP/1.1 200 OK\r\n" + "Content-Length: \(body.utf8.count)\r\n"
            + "Content-Type: text/plain\r\n" + "Connection: close\r\n" + "\r\n" + body

        var buffer = context.channel.allocator.buffer(capacity: response.utf8.count)
        buffer.writeString(response)

        // Write, then immediately close — ordering is guaranteed
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
