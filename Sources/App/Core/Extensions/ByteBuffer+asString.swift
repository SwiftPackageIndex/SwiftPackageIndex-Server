import Vapor


extension ByteBuffer {

    func asString() -> String {
        String(decoding: readableBytesView, as: UTF8.self)
    }

}
