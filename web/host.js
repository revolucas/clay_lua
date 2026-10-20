import { newLua } from "./lua-interop.js";

const canvas = document.getElementById("scene");
const status = document.getElementById("status");
const rendererSelect = document.getElementById("renderer");
const consoleToggle = document.getElementById("console-toggle");
const consolePanel = document.getElementById("console-panel");
const consoleOutput = document.getElementById("console-output");
const consoleEntries = [];
const maxConsoleEntries = 500;

function setConsoleOpen(open) {
  consolePanel.hidden = !open;
  consoleToggle.setAttribute("aria-expanded", String(open));
  if (open) consoleOutput.scrollTop = consoleOutput.scrollHeight;
}

consoleToggle.addEventListener("click", () => setConsoleOpen(consolePanel.hidden));
document.getElementById("console-close").addEventListener("click", () => setConsoleOpen(false));
document.getElementById("console-copy").addEventListener("click", async () => {
  try {
    if (!navigator.clipboard?.writeText) throw new Error("Clipboard access is unavailable");
    await navigator.clipboard.writeText(consoleEntries.join("\n"));
  } catch (error) {
    appendConsole("error", ["Could not copy console output:", error], true);
  }
});
document.getElementById("console-clear").addEventListener("click", () => {
  consoleEntries.length = 0;
  consoleOutput.textContent = "";
});

function formatConsoleValue(value) {
  if (typeof value === "string") return value;
  if (value instanceof Error) return value.stack || `${value.name}: ${value.message}`;
  if (value === undefined) return "undefined";
  if (typeof value === "bigint") return `${value}n`;
  try {
    const json = JSON.stringify(value, (_key, nested) =>
      typeof nested === "bigint" ? `${nested}n` : nested, 2);
    return json === undefined ? String(value) : json;
  } catch (_error) {
    try { return String(value); }
    catch (_stringError) { return "[unprintable value]"; }
  }
}

function appendConsole(level, args, reveal = level === "error") {
  const now = new Date();
  const time = `${now.toLocaleTimeString()} ${String(now.getMilliseconds()).padStart(3, "0")}`;
  const message = args.map(formatConsoleValue).join(" ");
  consoleEntries.push(`${time} [${level.toUpperCase()}] ${message}`);
  if (consoleEntries.length > maxConsoleEntries) {
    consoleEntries.splice(0, consoleEntries.length - maxConsoleEntries);
  }
  const wasAtBottom = consoleOutput.scrollTop + consoleOutput.clientHeight
      >= consoleOutput.scrollHeight - 8;
  consoleOutput.textContent = consoleEntries.join("\n");
  if (wasAtBottom) consoleOutput.scrollTop = consoleOutput.scrollHeight;
  if (reveal) setConsoleOpen(true);
}

// Keep browser developer tools working while mirroring messages in the page,
// so errors are still readable when the demo is running as a standalone build.
for (const level of ["log", "info", "warn", "error", "debug"]) {
  const original = console[level].bind(console);
  console[level] = (...args) => {
    appendConsole(level, args);
    original(...args);
  };
}

window.addEventListener("error", (event) => {
  const location = event.filename
    ? `\n${event.filename}:${event.lineno || 0}:${event.colno || 0}` : "";
  appendConsole("error", [event.error || `${event.message}${location}`], true);
});
window.addEventListener("unhandledrejection", (event) => {
  appendConsole("error", ["Unhandled promise rejection:", event.reason], true);
});

consoleToggle.title = "Show demo logs and full errors (F12)";
const url = new URL(window.location.href);
const requestedRenderer = url.searchParams.get("renderer");
const rendererMode = requestedRenderer === "bgfx" ? "bgfx" : "canvas2d";
rendererSelect.value = rendererMode;
canvas.tabIndex = 0;

if (rendererMode === "canvas2d") {
  canvas.setAttribute("aria-label", "Clay Lua interface rendered with Canvas2D");
  const context = canvas.getContext("2d", { alpha: false, desynchronized: true });
  if (!context) {
    throw new Error("This browser could not create a Canvas2D context");
  }
  // Clay measures text while building the first layout, before the first
  // drawCommands() call. Make the context available to the FFI bridge now.
  canvas.__clayLua2DContext = context;
  status.textContent = "Starting Canvas2D…";
} else {
  canvas.setAttribute("aria-label", "Clay Lua interface rendered with BGFX WebGL2");
  status.textContent = "Starting BGFX WebGL2…";
}

rendererSelect.addEventListener("change", () => {
  const next = new URL(window.location.href);
  next.searchParams.set("renderer", rendererSelect.value);
  window.location.assign(next);
});

const pointer = { x: -1, y: -1, buttons: 0, pressed: 0, wheelX: 0, wheelY: 0 };
let lua = null;
let composing = false;

const textInput = document.createElement("textarea");
textInput.autocomplete = "off";
textInput.autocapitalize = "off";
textInput.spellcheck = false;
textInput.setAttribute("aria-label", "Clay demo keyboard input");
Object.assign(textInput.style, {
  position: "fixed", left: "0", bottom: "0", width: "1px", height: "1px",
  padding: "0", border: "0", opacity: "0", overflow: "hidden", resize: "none",
  zIndex: "-1",
});
document.body.appendChild(textInput);

function luaGlobal(name) {
  // Browser events can arrive while the Emscripten module is loading or
  // between newLua() and newState(). The interop layer needs a live Lua
  // state before it can expose the global table.
  if (!lua || !lua.L || typeof lua._G !== "function") return null;
  const globals = lua._G();
  if (!globals) return null;
  const value = globals[name];
  return typeof value === "function" ? value : null;
}

function keyCode(code) {
  if (/^Key[A-Z]$/.test(code)) return code.charCodeAt(3);
  if (/^Digit[0-9]$/.test(code)) return code.charCodeAt(5);
  if (/^Numpad[0-9]$/.test(code)) return 320 + Number(code.slice(6));
  if (/^F([1-9]|1[0-9]|2[0-5])$/.test(code)) return 289 + Number(code.slice(1));
  const codes = {
    Space: 32, Quote: 39, Comma: 44, Minus: 45, Period: 46, Slash: 47,
    Semicolon: 59, Equal: 61, BracketLeft: 91, Backslash: 92,
    BracketRight: 93, Backquote: 96,
    Escape: 256, Enter: 257, NumpadEnter: 335, Tab: 258, Backspace: 259,
    Insert: 260, Delete: 261, ArrowRight: 262, ArrowLeft: 263,
    ArrowDown: 264, ArrowUp: 265, PageUp: 266, PageDown: 267,
    Home: 268, End: 269, CapsLock: 280, ScrollLock: 281,
    NumLock: 282, PrintScreen: 283, Pause: 284,
    NumpadDecimal: 330, NumpadDivide: 331, NumpadMultiply: 332,
    NumpadSubtract: 333, NumpadAdd: 334, NumpadEqual: 336,
    ShiftLeft: 340, ControlLeft: 341, AltLeft: 342, MetaLeft: 343,
    ShiftRight: 344, ControlRight: 345, AltRight: 346, MetaRight: 347,
    ContextMenu: 348,
  };
  return codes[code] ?? -1;
}

function modifiers(event) {
  return (event.shiftKey ? 1 : 0) | (event.ctrlKey ? 2 : 0)
    | (event.altKey ? 4 : 0) | (event.metaKey ? 8 : 0)
    | (event.getModifierState("CapsLock") ? 16 : 0)
    | (event.getModifierState("NumLock") ? 32 : 0);
}

function sendText(text) {
  const input = luaGlobal("web_input_codepoint");
  if (!input) return;
  for (const char of text) input(char.codePointAt(0));
}

function updatePointer(event) {
  const rect = canvas.getBoundingClientRect();
  pointer.x = event.clientX - rect.left;
  pointer.y = event.clientY - rect.top;
}

function buttonMask(button) {
  if (button === 0) return 1; // primary / left
  if (button === 2) return 2; // secondary / right
  if (button === 1) return 4; // auxiliary / middle
  return 0;
}

canvas.addEventListener("pointermove", (event) => {
  updatePointer(event);
  pointer.buttons = event.buttons;
});
canvas.addEventListener("pointerdown", (event) => {
  canvas.setPointerCapture(event.pointerId);
  updatePointer(event);
  const pressed = buttonMask(event.button);
  pointer.buttons = event.buttons || pressed;
  // Preserve a quick click until Lua has sampled at least one animation frame.
  pointer.pressed |= pressed;
  textInput.focus({ preventScroll: true });
  event.preventDefault();
});
canvas.addEventListener("pointerup", (event) => {
  updatePointer(event);
  pointer.buttons = event.buttons;
});
canvas.addEventListener("pointercancel", () => {
  pointer.buttons = 0;
  pointer.pressed = 0;
});
canvas.addEventListener("contextmenu", (event) => event.preventDefault());
canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  pointer.wheelX += event.deltaX;
  pointer.wheelY += event.deltaY;
}, { passive: false });

window.addEventListener("keydown", (event) => {
  if (event.code === "F12") {
    event.preventDefault();
    setConsoleOpen(consolePanel.hidden);
    return;
  }
  if (consolePanel.contains(event.target) || event.target === consoleToggle) return;
  const code = keyCode(event.code);
  if (code < 0) return;
  const send = luaGlobal("web_key_event");
  if (send) send(code, true, event.repeat, modifiers(event));
  if (["Tab", "Space", "Backspace", "Delete", "ArrowUp", "ArrowDown",
    "ArrowLeft", "ArrowRight", "PageUp", "PageDown", "Home", "End"].includes(event.code)
    || ((event.ctrlKey || event.metaKey) && !["KeyC", "KeyV", "KeyX"].includes(event.code))) {
    event.preventDefault();
  }
});
window.addEventListener("keyup", (event) => {
  if (event.code === "F12" || consolePanel.contains(event.target) || event.target === consoleToggle) return;
  const code = keyCode(event.code);
  const send = luaGlobal("web_key_event");
  if (code >= 0 && send) send(code, false, false, modifiers(event));
});
window.addEventListener("blur", () => {
  pointer.buttons = 0;
  pointer.pressed = 0;
  const release = luaGlobal("web_release_keys");
  if (release) release();
});

textInput.addEventListener("compositionstart", () => { composing = true; });
textInput.addEventListener("compositionend", (event) => {
  composing = false;
  sendText(event.data || textInput.value);
  textInput.value = "";
});
textInput.addEventListener("input", (event) => {
  if (!composing && textInput.value) sendText(textInput.value);
  textInput.value = "";
});
textInput.addEventListener("paste", (event) => {
  const text = event.clipboardData?.getData("text/plain") ?? "";
  const setClipboard = luaGlobal("web_set_clipboard_text");
  if (setClipboard) setClipboard(text);
  event.preventDefault();
});

async function start() {
  if (rendererMode === "canvas2d") {
    await Promise.all([
      document.fonts.load('16px "Clay Mono"'),
      document.fonts.load('16px "Clay Georgia"'),
      document.fonts.load('16px "Clay Codicon"'),
    ]);
  }

  lua = await newLua({
    luaJSPath: "./lua-5.4.7-with-ffi.js",
    locateFile: (path) => new URL(path, import.meta.url).href,
    print: (...args) => console.log("[lua]", ...args),
    printErr: (...args) => console.error("[lua]", ...args),
  });

  // luaffifb resolves ffi.C through the Wasm function table; calling these
  // exported Canvas2D functions through that route can hit a table signature
  // mismatch. Expose direct Emscripten exports to Lua's JS interop instead.
  const wasm = lua.lib;
  const withCString = (value, callback) => {
    const pointer = wasm.stringToNewUTF8(String(value ?? ""));
    try {
      return callback(pointer);
    } finally {
      wasm._free(pointer);
    }
  };
  window.clayLuaCanvas2D = {
    beginFrame: (width, height, ratio) =>
      wasm._clay_canvas2d_ffi_begin_frame(width, height, ratio),
    fillRect: (...args) => wasm._clay_canvas2d_ffi_fill_rect(...args),
    strokeRect: (...args) => wasm._clay_canvas2d_ffi_stroke_rect(...args),
    pushClip: (...args) => wasm._clay_canvas2d_ffi_push_clip(...args),
    popClip: () => wasm._clay_canvas2d_ffi_pop_clip(),
    measureText: (text, fontId, size, letterSpacing, skipTags) =>
      withCString(text, (pointer) => wasm._clay_canvas2d_ffi_measure_text(
        pointer, fontId, size, letterSpacing, skipTags)),
    drawText: (text, ...args) => withCString(text, (pointer) =>
      wasm._clay_canvas2d_ffi_draw_text(pointer, ...args)),
    drawGrid: (...args) => wasm._clay_canvas2d_ffi_draw_grid(...args),
    drawBezier: (...args) => wasm._clay_canvas2d_ffi_draw_bezier(...args),
    colorPicker: (...args) => wasm._clay_canvas2d_ffi_color_picker(...args),
  };

  lua.newState();
  if (typeof lua.lib._clay_lua_register !== "function") {
    throw new Error("Clay registration function was not exported by the Wasm module");
  }
  lua.lib._clay_lua_register(lua.L);
  const source = await fetch("./app.lua").then((response) => {
    if (!response.ok) throw new Error(`Could not load app.lua (${response.status})`);
    return response.text();
  });
  lua.run(source);
  const frame = luaGlobal("web_frame");
  if (!frame) throw new Error("app.lua did not define web_frame");

  let cpuMs = 0;
  let averageFps = 0;
  let lastReport = performance.now();
  let reportFrames = 0;
  let totalFrames = 0;
  let metricsStarted = false;
  let previousTime = performance.now();
  let frameFailed = false;

  function tick(now) {
    if (frameFailed) return;
    const rect = canvas.getBoundingClientRect();
    const pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
    const pixelWidth = Math.max(1, Math.round(rect.width * pixelRatio));
    const pixelHeight = Math.max(1, Math.round(rect.height * pixelRatio));
    if (canvas.width !== pixelWidth) canvas.width = pixelWidth;
    if (canvas.height !== pixelHeight) canvas.height = pixelHeight;
    const dt = Math.min((now - previousTime) / 1000, 0.05);
    previousTime = now;

    const frameStart = performance.now();
    try {
      frame(dt, rect.width, rect.height, pointer.x, pointer.y,
        pointer.buttons | pointer.pressed,
        pointer.wheelX, pointer.wheelY, pixelRatio,
        rendererMode === "canvas2d" ? 1 : 0);
    } catch (error) {
      frameFailed = true;
      console.error("Clay Lua frame failed", error);
      const detail = String(error?.message ?? error).split("\n", 1)[0];
      status.textContent = `${rendererMode === "canvas2d" ? "Canvas2D" : "BGFX WebGL2"} failed: ${detail}`;
      status.classList.add("error");
      return;
    }
    const elapsed = performance.now() - frameStart;
    totalFrames++;
    if (totalFrames > 2) {
      cpuMs = cpuMs === 0 ? elapsed : cpuMs * 0.9 + elapsed * 0.1;
      if (metricsStarted) reportFrames++;
      else {
        lastReport = now;
        metricsStarted = true;
      }
    }
    pointer.pressed = 0;
    pointer.wheelX = 0;
    pointer.wheelY = 0;
    if (now - lastReport >= 1000) {
      averageFps = reportFrames > 0 ? reportFrames * 1000 / (now - lastReport) : 0;
      const backend = rendererMode === "canvas2d" ? "Canvas2D" : "BGFX WebGL2";
      status.textContent = `${backend} · ${averageFps.toFixed(0)} FPS · ${cpuMs.toFixed(2)} ms frame CPU`;
      reportFrames = 0;
      lastReport = now;
    }
    requestAnimationFrame(tick);
  }

  requestAnimationFrame(tick);
}

start().catch((error) => {
  console.error(error);
  status.textContent = `Web build failed: ${error.message}`;
  status.classList.add("error");
});
