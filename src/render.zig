const main = @import("render/main.zig");

pub const RenderError = main.RenderError;
pub const Stats = main.Stats;
pub const WindowOptions = main.WindowOptions;
pub const Scene = main.Scene;
pub const SceneReloadHook = main.SceneReloadHook;
pub const FrameUpdateHook = main.FrameUpdateHook;
pub const PointerInput = main.PointerInput;
pub const KeyboardInput = main.KeyboardInput;
pub const EditorAxis = main.EditorAxis;
pub const EditorState = main.EditorState;
pub const EditorSplitter = main.EditorSplitter;
pub const EditorFrameState = main.EditorFrameState;
pub const EditorUpdate = main.EditorUpdate;
pub const EditorViewportBounds = main.EditorViewportBounds;
pub const EditorError = main.EditorError;
pub const FrameInput = main.FrameInput;
pub const editorFrameState = main.editorFrameState;
pub const updateEditorState = main.updateEditorState;
pub const stats = main.stats;
pub const writeFrameInput = main.writeFrameInput;
pub const renderDemoBmp = main.renderDemoBmp;
pub const renderDemoBmpWithInput = main.renderDemoBmpWithInput;
pub const runDemoWindow = main.runDemoWindow;
pub const editorGameViewportBounds = main.editorGameViewportBounds;
pub const editorSystemListHitTestPoint = main.editorSystemListHitTestPoint;

test {
    _ = main;
}
