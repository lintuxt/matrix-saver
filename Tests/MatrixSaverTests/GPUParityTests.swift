import XCTest
import Metal

/// Must match `ParityParams` in Shaders.metal (4 floats + 2 uints = 24 bytes).
struct ParityParams {
    var time: Float
    var speed: Float
    var density: Float
    var worldRows: Float
    var seed: UInt32
    var glyphCount: UInt32
}

final class GPUParityTests: XCTestCase {
    func testLayout() {
        XCTAssertEqual(MemoryLayout<ParityParams>.stride, 24)
    }

    func testParity() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "no Metal device")
        let lib = try device.makeDefaultLibrary(bundle: Bundle(for: Self.self))
        let fn = try XCTUnwrap(lib.makeFunction(name: "parityKernel"))
        let pipe = try device.makeComputePipelineState(function: fn)
        let queue = try XCTUnwrap(device.makeCommandQueue())

        var cells: [SIMD2<UInt32>] = []
        for i in 0..<4096 { cells.append(SIMD2(UInt32((i * 37) % 300), UInt32((i * 11) % 80))) }
        let cellBuf = try XCTUnwrap(device.makeBuffer(bytes: cells, length: cells.count * MemoryLayout<SIMD2<UInt32>>.stride))

        let sets: [ParityParams] = [
            ParityParams(time: 123.456, speed: 1, density: 0.6, worldRows: 80, seed: 0x4D41_5452, glyphCount: 80),
            ParityParams(time: 1000.5, speed: 2.3, density: 0.25, worldRows: 80, seed: 0x4D41_5452, glyphCount: 80),
        ]
        for var p in sets {
            let outBuf = try XCTUnwrap(device.makeBuffer(length: cells.count * 16))
            let cb = try XCTUnwrap(queue.makeCommandBuffer())
            let enc = try XCTUnwrap(cb.makeComputeCommandEncoder())
            enc.setComputePipelineState(pipe)
            enc.setBytes(&p, length: MemoryLayout<ParityParams>.stride, index: 0)
            enc.setBuffer(cellBuf, offset: 0, index: 1)
            enc.setBuffer(outBuf, offset: 0, index: 2)
            let tg = min(pipe.maxTotalThreadsPerThreadgroup, 64)
            enc.dispatchThreads(MTLSize(width: cells.count, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: tg, height: 1, depth: 1))
            enc.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()
            XCTAssertNil(cb.error)

            let out = outBuf.contents().bindMemory(to: SIMD4<Float>.self, capacity: cells.count)
            var bMis = 0, hMis = 0, gMis = 0, lit = 0
            for (i, c) in cells.enumerated() {
                let cpu = RainMath.cell(seed: p.seed, col: c.x, row: c.y, time: p.time, speed: p.speed,
                                        density: p.density, worldRows: p.worldRows, glyphCount: p.glyphCount)
                let gpu = out[i]
                if cpu.brightness > 0 { lit += 1 }
                if abs(cpu.brightness - gpu.x) > 1e-3 { bMis += 1 }
                if cpu.head != gpu.y { hMis += 1 }
                if cpu.glyph != UInt32(gpu.z) { gMis += 1 }
            }
            print("PARITY time=\(p.time) lit=\(lit) brightnessMismatch=\(bMis) headMismatch=\(hMis) glyphMismatch=\(gMis) of \(cells.count)")
            let limit = Int(Double(cells.count) * 0.005)
            XCTAssertLessThanOrEqual(bMis, limit)
            XCTAssertLessThanOrEqual(hMis, limit)
            XCTAssertLessThanOrEqual(gMis, limit)
            XCTAssertGreaterThan(lit, 0)
        }
    }
}
