import Foundation
import Metal

// VirGL Renderer: OpenGL to Metal translation
// For games/apps that use OpenGL instead of DirectX
// Pipeline: OpenGL calls → VirGL → Metal commands → GPU
// This is the alternative to DXVK for OpenGL-based applications

class VirGLRenderer {
    
    struct VirGLConfig: Codable {
        var glVersionOverride: String = "4.3"
        var glslVersionOverride: String = "430"
        var enableDebug: Bool = false
        var maxTextureSize: Int = 8192
        var enableShaderCache: Bool = true
        var galliumDriver: String = "virpipe"
        
        func toEnvVars() -> [String: String] {
            var vars: [String: String] = [:]
            vars["MESA_GL_VERSION_OVERRIDE"] = glVersionOverride
            vars["MESA_GLSL_VERSION_OVERRIDE"] = glslVersionOverride
            vars["GALLIUM_DRIVER"] = galliumDriver
            vars["MESA_SHADER_CACHE_DISABLE"] = enableShaderCache ? "false" : "true"
            
            if enableDebug {
                vars["MESA_DEBUG"] = "1"
                vars["LIBGL_DEBUG"] = "verbose"
            }
            
            return vars
        }
    }
    
    // OpenGL extensions that VirGL supports on iOS via Metal
    static let supportedExtensions = [
        "GL_ARB_vertex_buffer_object",
        "GL_ARB_vertex_array_object",
        "GL_ARB_framebuffer_object",
        "GL_ARB_texture_float",
        "GL_ARB_shader_objects",
        "GL_ARB_vertex_shader",
        "GL_ARB_fragment_shader",
        "GL_ARB_geometry_shader4",
        "GL_ARB_tessellation_shader",
        "GL_ARB_compute_shader",
        "GL_ARB_uniform_buffer_object",
        "GL_ARB_shader_storage_buffer_object",
        "GL_ARB_texture_compression",
        "GL_ARB_texture_compression_s3tc",
        "GL_ARB_depth_texture",
        "GL_ARB_shadow",
        "GL_ARB_multisample",
        "GL_ARB_multitexture",
        "GL_ARB_instanced_arrays",
        "GL_ARB_draw_instanced",
        "GL_ARB_draw_elements_base_vertex",
        "GL_EXT_texture_filter_anisotropic",
        "GL_EXT_framebuffer_multisample",
    ]
    
    // OpenGL to Metal mapping for draw calls
    struct GLToMetalMapping {
        let glFunction: String
        let metalEquivalent: String
        let notes: String
    }
    
    static let drawCallMappings: [GLToMetalMapping] = [
        GLToMetalMapping(glFunction: "glDrawArrays", metalEquivalent: "drawPrimitives", notes: "Direct vertex rendering"),
        GLToMetalMapping(glFunction: "glDrawElements", metalEquivalent: "drawIndexedPrimitives", notes: "Indexed rendering"),
        GLToMetalMapping(glFunction: "glDrawArraysInstanced", metalEquivalent: "drawPrimitives(instanceCount:)", notes: "Instanced rendering"),
        GLToMetalMapping(glFunction: "glBindTexture", metalEquivalent: "setFragmentTexture", notes: "Texture binding"),
        GLToMetalMapping(glFunction: "glUseProgram", metalEquivalent: "setRenderPipelineState", notes: "Shader program"),
        GLToMetalMapping(glFunction: "glBindFramebuffer", metalEquivalent: "MTLRenderPassDescriptor", notes: "Framebuffer binding"),
        GLToMetalMapping(glFunction: "glClear", metalEquivalent: "loadAction: .clear", notes: "Buffer clearing"),
        GLToMetalMapping(glFunction: "glViewport", metalEquivalent: "setViewport", notes: "Viewport setting"),
        GLToMetalMapping(glFunction: "glScissor", metalEquivalent: "setScissorRect", notes: "Scissor test"),
        GLToMetalMapping(glFunction: "glBlendFunc", metalEquivalent: "MTLBlendFactor", notes: "Blend state"),
        GLToMetalMapping(glFunction: "glDepthFunc", metalEquivalent: "MTLDepthStencilDescriptor", notes: "Depth test"),
        GLToMetalMapping(glFunction: "glGenBuffers", metalEquivalent: "device.makeBuffer", notes: "Buffer creation"),
        GLToMetalMapping(glFunction: "glGenTextures", metalEquivalent: "device.makeTexture", notes: "Texture creation"),
        GLToMetalMapping(glFunction: "glCompileShader", metalEquivalent: "device.makeLibrary", notes: "Shader compilation"),
    ]
    
    // Texture format mapping
    static let textureFormatMap: [String: String] = [
        "GL_RGBA8": "MTLPixelFormat.rgba8Unorm",
        "GL_RGB8": "MTLPixelFormat.rgba8Unorm (expanded)",
        "GL_RGBA16F": "MTLPixelFormat.rgba16Float",
        "GL_RGBA32F": "MTLPixelFormat.rgba32Float",
        "GL_R8": "MTLPixelFormat.r8Unorm",
        "GL_RG8": "MTLPixelFormat.rg8Unorm",
        "GL_DEPTH24_STENCIL8": "MTLPixelFormat.depth32Float_stencil8",
        "GL_DEPTH_COMPONENT32F": "MTLPixelFormat.depth32Float",
        "GL_COMPRESSED_RGBA_S3TC_DXT1": "MTLPixelFormat.bc1_rgba",
        "GL_COMPRESSED_RGBA_S3TC_DXT3": "MTLPixelFormat.bc2_rgba",
        "GL_COMPRESSED_RGBA_S3TC_DXT5": "MTLPixelFormat.bc3_rgba",
    ]
    
    var config = VirGLConfig()
    
    // Check if VirGL libraries are installed
    func isInstalled() -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let virglPath = docs.appendingPathComponent("drivers/virgl")
        return FileManager.default.fileExists(atPath: virglPath.path)
    }
    
    func getGLInfo() -> String {
        var info = "VirGL OpenGL → Metal Translation\n"
        info += "OpenGL Version: \(config.glVersionOverride)\n"
        info += "GLSL Version: \(config.glslVersionOverride)\n"
        info += "Gallium Driver: \(config.galliumDriver)\n"
        info += "Supported Extensions: \(Self.supportedExtensions.count)\n"
        info += "Texture Formats: \(Self.textureFormatMap.count)\n"
        return info
    }
    
    // Write VirGL mesa config for a container
    func configureMesa(for containerPrefix: URL) {
        let mesaConf = """
        # Mesa/VirGL Configuration for Winkor
        # OpenGL → Metal translation settings
        
        [driconf]
        option name="mesa_glthread" value="true"
        option name="allow_higher_compat_version" value="true"
        option name="force_glsl_extensions_warn" value="false"
        
        [virgl]
        shader_cache = \(config.enableShaderCache ? "true" : "false")
        max_texture_size = \(config.maxTextureSize)
        """
        
        let configPath = containerPrefix.appendingPathComponent("mesa.conf")
        try? mesaConf.write(to: configPath, atomically: true, encoding: .utf8)
    }
}
