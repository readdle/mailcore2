import Foundation
import CMailCore

extension Data {
    
    init?(cdata: CData) {
        guard cdata.instance != nil else {
            return nil
        }
        if let bytes = cdata.bytes {
            self = Data(bytes: bytes, count: Int(cdata.length))
        }
        else {
            self = Data()
        }
    }
    
    public func mailCoreData() -> CData {
        return self.withUnsafeBytes { bytes -> CData in
            guard let bytes: UnsafePointer<Int8> = Data.unwrapUnsafeBytes(bytes) else {
                assert(false)
                return CData()
            }
            
            return CData.dataWithBytes(bytes, UInt32(self.count))
        }
    }
    
    init?(desctructiveCData data: CData) {
        guard data.instance != nil else {
            return nil
        }
        guard let pointer = UnsafeMutableRawPointer.init(mutating: data.bytes) else {
            return nil
        }
        let bytesDeallocator = data.bytesDeallocator
        let length = Int(data.length)
        let deallocator = data.externallyAllocatedMemory == false ? Data.Deallocator.free : Data.Deallocator.custom({ pointer, length in
            bytesDeallocator?(pointer.assumingMemoryBound(to: Int8.self), UInt32(length))
        })
        self = Data.init(bytesNoCopy: pointer, count: length, deallocator: deallocator)
        // Swift take ownership of byte buffer allocated at mailcore
        // That's why we clear bytes pointer at mailcore::Data to prevent freeing memory there
        data.destructiveDataClear()
    }
    
}

#if os(Android) || os(Windows) || os(Linux)
#else
    
extension NSData {
    
    public func mailCoreData() -> CData {
        let swiftData = self as Data
        return swiftData.mailCoreData()
    }
    
}
    
#endif

extension Data {
    public static func unwrapUnsafeBytes<T>(_ ptr: UnsafeRawBufferPointer) -> UnsafePointer<T>? {
        return ptr.bindMemory(to: T.self).baseAddress
    }
    
    public static func unwrapUnsafeMutableBytes<T>(_ ptr: UnsafeMutableRawBufferPointer) -> UnsafeMutablePointer<T>? {
        return ptr.bindMemory(to: T.self).baseAddress
    }
}
