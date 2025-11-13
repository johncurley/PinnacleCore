#import <Foundation/Foundation.h>

@class PinnacleMetalRendererWrapper;

/**
 * Compilation result passed to Swift
 */
@interface CompileResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) double compilationTime;
@property (nonatomic, strong) NSArray<NSString *> *errors;
@property (nonatomic, strong) NSArray<NSNumber *> *errorLines;
@end

/**
 * Objective-C wrapper for Pinnacle::ShaderEditor
 * This bridges the C++ shader editor to Swift
 */
@interface ShaderEditorBridge : NSObject

/**
 * Initialize with a renderer
 */
- (instancetype)initWithRenderer:(void*)renderer;

/**
 * Create a new shader program
 */
- (void)createProgramWithName:(NSString*)name;

/**
 * Set vertex shader source
 */
- (void)setVertexShaderSource:(NSString*)source;

/**
 * Set fragment shader source
 */
- (void)setFragmentShaderSource:(NSString*)source;

/**
 * Test compile the current program (without applying)
 * Returns a CompileResult with success status and any errors
 */
- (CompileResult*)testCompile;

/**
 * Apply the compiled shader to the renderer (hot-reload)
 */
- (BOOL)applyShader;

/**
 * Reset to default shaders
 */
- (void)resetToDefaults;

/**
 * Load a preset shader from the library
 * Preset names: "Unlit", "Wireframe", "Normal Visualizer"
 */
- (BOOL)loadPreset:(NSString*)presetName;

/**
 * Get list of available presets
 */
- (NSArray<NSString*>*)availablePresets;

/**
 * Load shader from file
 */
- (BOOL)loadShaderFromFile:(NSString*)path isVertex:(BOOL)isVertex;

/**
 * Save current shader to file
 */
- (BOOL)saveShaderToFile:(NSString*)path isVertex:(BOOL)isVertex;

/**
 * Get current vertex shader source
 */
- (NSString*)getVertexShaderSource;

/**
 * Get current fragment shader source
 */
- (NSString*)getFragmentShaderSource;

@end
