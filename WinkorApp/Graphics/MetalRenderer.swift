import Foundation
import Metal
import MetalKit
import UIKit

// Metal Renderer: The final rendering backend on iOS
// All graphics ultimately go through Metal on iOS:
//   DirectX → DXVK → Vulkan → MoltenVK → Metal → GPU
//   OpenGL → VirGL → Metal → GPU

class MetalRenderer: NSObject, MTKViewDelegate, ObservableObject {
    
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var computePipelineState: MTLComputePipelineState?
    
    // Framebuffer from Wine/DXVK
    private var framebufferTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    
    // Performance tracking
    private var frameCount: Int = 0
    private var lastFPSTime: CFTimeInterval = 0
    var currentFPS: Int = 0
    var frameTime: Double = 0
    
    // Resolution
    var renderWidth: Int = 1280
    var renderHeight: Int = 720
    
    // Callback for frame updates
    var onFrameRendered: ((Int, Double) -> Void)?
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("[MetalRenderer] Metal is not supported on this device")
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            fatalError("[MetalRenderer] Failed to create command queue")
        }
        self.commandQueue = queue
        
        super.init()
        
        setupPipeline()
        setupBuffers()
        
        print("[MetalRenderer] Initialized with device: \(device.name)")
        print("[MetalRenderer] Max buffer length: \(device.maxBufferLength / 1024 / 1024) MB")
        print("[MetalRenderer] Supports Apple GPU family 7: \(device.supportsFamily(.apple7))")
    }
    
    // MARK: - Setup
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("[MetalRenderer] No Metal library found, using runtime shaders")
            setupRuntimeShaders()
            return
        }
        
        let vertexFunc = library.makeFunction(name: "vertex_passthrough")
        let fragmentFunc = library.makeFunction(name: "fragment_texture_sample")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = false
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("[MetalRenderer] Render pipeline created")
        } catch {
            print("[MetalRenderer] Pipeline error: \(error)")
            setupRuntimeShaders()
        }
    }
    
    private func setupRuntimeShaders() {
        // Compile shaders at runtime if .metallib not available
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_passthrough(
            uint vertexID [[vertex_id]],
            constant float4 *vertices [[buffer(0)]]
        ) {
            VertexOut out;
            float4 v = vertices[vertexID];
            out.position = float4(v.xy, 0.0, 1.0);
            out.texCoord = v.zw;
            return out;
        }
        
        fragment float4 fragment_texture_sample(
            VertexOut in [[stage_in]],
            texture2d<float> tex [[texture(0)]],
            sampler smp [[sampler(0)]]
        ) {
            return tex.sample(smp, in.texCoord);
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let vertexFunc = library.makeFunction(name: "vertex_passthrough")
            let fragmentFunc = library.makeFunction(name: "fragment_texture_sample")
            
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("[MetalRenderer] Runtime shader pipeline created")
        } catch {
            print("[MetalRenderer] Runtime shader compilation failed: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Full-screen quad vertices (position.xy, texcoord.xy)
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  // bottom-left
             1.0, -1.0, 1.0, 1.0,  // bottom-right
            -1.0,  1.0, 0.0, 0.0,  // top-left
             1.0, -1.0, 1.0, 1.0,  // bottom-right
             1.0,  1.0, 1.0, 0.0,  // top-right
            -1.0,  1.0, 0.0, 0.0,  // top-left
        ]
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        )
    }
    
    // MARK: - Framebuffer Management
    
    func createFramebuffer(width: Int, height: Int) {
        renderWidth = width
        renderHeight = height
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared
        
        framebufferTexture = device.makeTexture(descriptor: descriptor)
        
        // Depth buffer
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDesc.usage = .renderTarget
        depthDesc.storageMode = .private
        depthTexture = device.makeTexture(descriptor: depthDesc)
        
        print("[MetalRenderer] Framebuffer created: \(width)x\(height)")
    }
    
    func updateFramebuffer(with pixelData: Data) {
        guard let texture = framebufferTexture else { return }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: renderWidth, height: renderHeight, depth: 1)
        )
        
        pixelData.withUnsafeBytes { ptr in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: renderWidth * 4
            )
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize
        print("[MetalRenderer] View resized to \(Int(size.width))x\(Int(size.height))")
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // If we have a framebuffer from Wine/DXVK, render it
        if let framebuffer = framebufferTexture {
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(framebuffer, index: 0)
            
            // Set sampler
            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            if let sampler = device.makeSamplerState(descriptor: samplerDesc) {
                encoder.setFragmentSamplerState(sampler, index: 0)
            }
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        } else {
            // No framebuffer - render a test pattern to show Metal is working
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
                  let pipelineState = pipelineState else { return }
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            // Create a simple test pattern texture
            let testTexture = createTestTexture()
            encoder.setFragmentTexture(testTexture, index: 0)
            
            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            if let sampler = device.makeSamplerState(descriptor: samplerDesc) {
                encoder.setFragmentSamplerState(sampler, index: 0)
            }
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // FPS tracking
        frameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - lastFPSTime
        if elapsed >= 1.0 {
            currentFPS = Int(Double(frameCount) / elapsed)
            frameTime = elapsed / Double(frameCount) * 1000.0
            frameCount = 0
            lastFPSTime = now
            onFrameRendered?(currentFPS, frameTime)
        }
    }
    
    // MARK: - Test Pattern
    
    private func createTestTexture() -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 256,
            height: 256,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create test texture")
        }
        
        // Create a colorful test pattern
        var pixels: [UInt32] = []
        for y in 0..<256 {
            for x in 0..<256 {
                let r = UInt32((x * 255) / 256)
                let g = UInt32((y * 255) / 256)
                let b = UInt32(128)
                let a: UInt32 = 255
                pixels.append((a << 24) | (r << 16) | (g << 8) | b)
            }
        }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: 256, height: 256, depth: 1)
        )
        
        pixels.withUnsafeBufferPointer { buffer in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                withBytes: buffer.baseAddress!,
                bytesPerRow: 256 * 4
            )
        }
        
        return texture
    }
    
    // MARK: - Public
    
    func getDevice() -> MTLDevice { return device }
    func getCommandQueue() -> MTLCommandQueue { return commandQueue }
    
    func getGPUInfo() -> String {
        var info = "GPU: \(device.name)\n"
        info += "Max Threads Per Threadgroup: \(device.maxThreadsPerThreadgroup)\n"
        info += "Max Buffer Length: \(device.maxBufferLength / 1024 / 1024) MB\n"
        info += "Apple GPU Family 7: \(device.supportsFamily(.apple7))\n"
        info += "Apple GPU Family 8: \(device.supportsFamily(.apple8))\n"
        info += "Supports Raytracing: \(device.supportsRaytracing)\n"
        return info
    }
}
