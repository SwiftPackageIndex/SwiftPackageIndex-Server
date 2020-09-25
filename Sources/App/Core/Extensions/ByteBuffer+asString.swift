import Vapor


extension ByteBuffer {

    func asString() -> String? {
        getString(at: readerIndex, length: readableBytes)
    }

}
