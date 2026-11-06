#include <emscripten.h>

/*
 * Thin Canvas2D bridge for the Lua FFI renderer. The Lua side still consumes
 * Clay's render command stream; these calls only map each command onto the
 * browser's existing 2D context.
 */
EM_JS(void, clay_canvas2d_begin_frame, (double width, double height, double ratio), {
	const canvas = document.getElementById("scene");
	if (!canvas) return;
	let ctx = canvas.__clayLua2DContext;
	if (!ctx) {
		ctx = canvas.getContext("2d", { alpha: false, desynchronized: true });
		if (!ctx) throw new Error("Canvas2D could not create a 2D context");
		canvas.__clayLua2DContext = ctx;
	}
	ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
	ctx.globalAlpha = 1;
	ctx.globalCompositeOperation = "source-over";
	ctx.clearRect(0, 0, width, height);
	ctx.fillStyle = "#111a2a";
	ctx.fillRect(0, 0, width, height);
});

EM_JS(void, clay_canvas2d_fill_rect,
	(double x, double y, double w, double h, int r, int g, int b, int a,
	 double tl, double tr, double bl, double br), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx || w <= 0 || h <= 0) return;
	const radii = [tl, tr, br, bl].map((value) =>
		Math.max(0, Math.min(value || 0, Math.min(w, h) * 0.5)));
	ctx.beginPath();
	if (typeof ctx.roundRect === "function") {
		ctx.roundRect(x, y, w, h, radii);
	} else {
		ctx.moveTo(x + radii[0], y);
		ctx.lineTo(x + w - radii[1], y);
		ctx.quadraticCurveTo(x + w, y, x + w, y + radii[1]);
		ctx.lineTo(x + w, y + h - radii[2]);
		ctx.quadraticCurveTo(x + w, y + h, x + w - radii[2], y + h);
		ctx.lineTo(x + radii[3], y + h);
		ctx.quadraticCurveTo(x, y + h, x, y + h - radii[3]);
		ctx.lineTo(x, y + radii[0]);
		ctx.quadraticCurveTo(x, y, x + radii[0], y);
		ctx.closePath();
	}
	ctx.fillStyle = `rgba(${r},${g},${b},${a / 255})`;
	ctx.fill();
});

EM_JS(void, clay_canvas2d_stroke_rect,
	(double x, double y, double w, double h, int r, int g, int b, int a,
	 double tl, double tr, double bl, double br,
	 double left, double right, double top, double bottom), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx || w <= 0 || h <= 0) return;
	ctx.strokeStyle = `rgba(${r},${g},${b},${a / 255})`;
	const widths = [left, right, top, bottom].map((value) => Math.max(0, value || 0));
	if (widths.every((value) => value === widths[0])) {
		const stroke = widths[0];
		if (stroke <= 0) return;
		const inset = stroke * 0.5;
		const rw = Math.max(0, w - stroke), rh = Math.max(0, h - stroke);
		const radii = [tl, tr, br, bl].map((value) =>
			Math.max(0, Math.min((value || 0) - inset, Math.min(rw, rh) * 0.5)));
		ctx.beginPath();
		if (typeof ctx.roundRect === "function") ctx.roundRect(x + inset, y + inset, rw, rh, radii);
		else ctx.rect(x + inset, y + inset, rw, rh);
		ctx.lineWidth = stroke;
		ctx.stroke();
		return;
	}
	ctx.lineCap = "butt";
	const sides = [
		{ width: top, x0: x + Math.max(tl || 0, left * 0.5), y0: y + top * 0.5,
			x1: x + w - Math.max(tr || 0, right * 0.5), y1: y + top * 0.5 },
		{ width: right, x0: x + w - right * 0.5, y0: y + Math.max(tr || 0, top * 0.5),
			x1: x + w - right * 0.5, y1: y + h - Math.max(br || 0, bottom * 0.5) },
		{ width: bottom, x0: x + Math.max(bl || 0, left * 0.5), y0: y + h - bottom * 0.5,
			x1: x + w - Math.max(br || 0, right * 0.5), y1: y + h - bottom * 0.5 },
		{ width: left, x0: x + left * 0.5, y0: y + Math.max(tl || 0, top * 0.5),
			x1: x + left * 0.5, y1: y + h - Math.max(bl || 0, bottom * 0.5) },
	];
	for (const side of sides) {
		if (side.width <= 0 || (side.x0 === side.x1 && side.y0 === side.y1)) continue;
		ctx.beginPath();
		ctx.moveTo(side.x0, side.y0);
		ctx.lineTo(side.x1, side.y1);
		ctx.lineWidth = side.width;
		ctx.stroke();
	}
});

EM_JS(void, clay_canvas2d_push_clip, (double x, double y, double w, double h), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx) return;
	ctx.save();
	ctx.beginPath();
	ctx.rect(x, y, Math.max(0, w), Math.max(0, h));
	ctx.clip();
});

EM_JS(void, clay_canvas2d_pop_clip, (void), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (ctx) ctx.restore();
});

EM_JS(double, clay_canvas2d_measure_text,
	(const char* text_ptr, int font_id, double size, double letter_spacing, int skip_tags), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx) return 0;
	let text = UTF8ToString(text_ptr);
	if (!skip_tags) {
		let plain = "", inside_tag = false;
		for (const character of text) {
			if (character === "[") { inside_tag = true; continue; }
			if (character === "]" && inside_tag) { inside_tag = false; continue; }
			if (!inside_tag) plain += character;
		}
		text = plain;
	}
	text = text.split(String.fromCharCode(9)).join("    ");
	const family = font_id === 0 ? '"Clay Mono", monospace'
		: font_id === 2 ? '"Clay Codicon", sans-serif'
		: '"Clay Serif", serif';
	ctx.font = `${Math.max(1, size)}px ${family}`;
	const lines = text.split(String.fromCharCode(10));
	let width = 0;
	for (const raw_line of lines) {
		const line = raw_line.split(String.fromCharCode(13)).join("");
		const spacing = Math.max(0, line.length - 1) * (letter_spacing || 0);
		width = Math.max(width, ctx.measureText(line).width + spacing);
	}
	return width;
});

EM_JS(void, clay_canvas2d_draw_text,
	(const char* text_ptr, double x, double y, int r, int g, int b, int a,
	 int font_id, double size, double letter_spacing, double line_height), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx) return;
	const text = UTF8ToString(text_ptr).split(String.fromCharCode(9)).join("    ");
	const baseColor = `rgba(${r},${g},${b},${a / 255})`;
	const family = font_id === 0 ? '"Clay Mono", monospace'
		: font_id === 2 ? '"Clay Codicon", sans-serif'
		: '"Clay Serif", serif';
	const style = { color: baseColor, bold: false, italic: false, shadow: false };
	const stack = [];
	const runs = [];
	let cursor = 0;
	function append(value) {
		if (!value) return;
		const last = runs[runs.length - 1];
		if (last && last.color === style.color && last.bold === style.bold
			&& last.italic === style.italic && last.shadow === style.shadow) last.text += value;
		else runs.push({ text: value, ...style });
	}
	while (cursor < text.length) {
		const start = text.indexOf("[", cursor);
		if (start < 0) break;
		const end = text.indexOf("]", start + 1);
		if (end < 0) break;
		append(text.slice(cursor, start));
		cursor = end + 1;
		const token = text.slice(start + 1, end).trim();
		const closing = token[0] === "/";
		const name = (closing ? token.slice(1) : token.split("=", 1)[0]).toLowerCase();
		if (closing) {
			for (let i = stack.length - 1; i >= 0; --i) {
				if (stack[i].name === name) {
					Object.assign(style, stack[i].previous);
					stack.length = i;
					break;
				}
			}
		} else if (["b", "i", "shadow", "color"].includes(name)) {
			stack.push({ name, previous: { ...style } });
			if (name === "b") style.bold = true;
			else if (name === "i") style.italic = true;
			else if (name === "shadow") style.shadow = true;
			else {
				const value = token.slice(token.indexOf("=") + 1).trim();
				if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value)) style.color = value;
			}
		}
	}
	append(text.slice(cursor));
	ctx.save();
	ctx.textBaseline = "top";
	ctx.textAlign = "left";
	ctx.lineJoin = "round";
	let dx = x, line = 0;
	for (const run of runs) {
		ctx.font = `${run.italic ? "italic " : ""}${run.bold ? "700 " : ""}${Math.max(1, size)}px ${family}`;
		ctx.fillStyle = run.color;
		ctx.shadowColor = run.shadow ? "rgba(0,0,0,0.75)" : "transparent";
		ctx.shadowBlur = run.shadow ? 1 : 0;
		ctx.shadowOffsetX = run.shadow ? 1.5 : 0;
		ctx.shadowOffsetY = run.shadow ? 1.5 : 0;
		const pieces = run.text.split(String.fromCharCode(10));
		for (let i = 0; i < pieces.length; ++i) {
			const piece = pieces[i].split(String.fromCharCode(13)).join("");
			if (piece) {
				ctx.fillText(piece, dx, y + line * (line_height > 0 ? line_height : Math.max(1, size) * 1.25));
				dx += ctx.measureText(piece).width + Math.max(0, piece.length - 1) * (letter_spacing || 0);
			}
			if (i + 1 < pieces.length) { line++; dx = x; }
		}
	}
	ctx.restore();
});

EM_JS(void, clay_canvas2d_draw_grid,
	(double x, double y, double w, double h, double step, double offset_x, double offset_y,
	 int r, int g, int b, int a), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx || step <= 0) return;
	ctx.save();
	ctx.translate(x, y);
	ctx.beginPath();
	const start_x = ((offset_x % step) + step) % step;
	const start_y = ((offset_y % step) + step) % step;
	for (let px = start_x; px < w; px += step) { ctx.moveTo(px, 0); ctx.lineTo(px, h); }
	for (let py = start_y; py < h; py += step) { ctx.moveTo(0, py); ctx.lineTo(w, py); }
	ctx.strokeStyle = `rgba(${r},${g},${b},${a / 255})`;
	ctx.lineWidth = 1;
	ctx.stroke();
	ctx.restore();
});

EM_JS(void, clay_canvas2d_draw_bezier,
	(double x, double y, double x0, double y0, double c1x, double c1y,
	 double c2x, double c2y, double x1, double y1, double thickness,
	 int r, int g, int b, int a), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx) return;
	ctx.beginPath();
	ctx.moveTo(x + x0, y + y0);
	ctx.bezierCurveTo(x + c1x, y + c1y, x + c2x, y + c2y, x + x1, y + y1);
	ctx.strokeStyle = `rgba(${r},${g},${b},${a / 255})`;
	ctx.lineWidth = Math.max(0.5, thickness || 1);
	ctx.lineCap = "round";
	ctx.stroke();
});

EM_JS(void, clay_canvas2d_color_picker,
	(double x, double y, double w, double h, int kind,
	 double hue, double saturation, double value, double alpha), {
	const canvas = document.getElementById("scene");
	const ctx = canvas && canvas.__clayLua2DContext;
	if (!ctx || w <= 0 || h <= 0) return;
	ctx.save();
	if (kind === 1) {
		const angle = ((hue % 1) + 1) % 1 * Math.PI * 2;
		const sector = angle / (Math.PI / 3);
		const index = Math.floor(sector) % 6;
		const fraction = sector - Math.floor(sector);
		const q = 1 - fraction;
		const colors = [[1, fraction, 0], [q, 1, 0], [0, 1, fraction], [0, q, 1], [fraction, 0, 1], [1, 0, q]][index];
		const rgb = colors.map((channel) => Math.round(channel * 255));
		ctx.fillStyle = "#fff";
		ctx.fillRect(x, y, w, h);
		const horizontal = ctx.createLinearGradient(x, y, x + w, y);
		horizontal.addColorStop(0, "#fff");
		horizontal.addColorStop(1, `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`);
		ctx.fillStyle = horizontal;
		ctx.fillRect(x, y, w, h);
		const vertical = ctx.createLinearGradient(x, y, x, y + h);
		vertical.addColorStop(0, "rgba(0,0,0,0)");
		vertical.addColorStop(1, "rgba(0,0,0,1)");
		ctx.fillStyle = vertical;
		ctx.fillRect(x, y, w, h);
	} else if (kind === 2) {
		const gradient = ctx.createLinearGradient(x, y, x, y + h);
		[[0, "#ff0000"], [1/6, "#ffff00"], [2/6, "#00ff00"], [3/6, "#00ffff"], [4/6, "#0000ff"], [5/6, "#ff00ff"], [1, "#ff0000"]]
			.forEach(([stop, color]) => gradient.addColorStop(stop, color));
		ctx.fillStyle = gradient;
		ctx.fillRect(x, y, w, h);
	} else {
		for (let py = 0; py < h; py += 8) for (let px = 0; px < w; px += 8) {
			ctx.fillStyle = ((Math.floor(px / 8) + Math.floor(py / 8)) & 1) ? "#aaa" : "#eee";
			ctx.fillRect(x + px, y + py, Math.min(8, w - px), Math.min(8, h - py));
		}
		const h6 = (((hue % 1) + 1) % 1) * 6;
		const index = Math.floor(h6) % 6, fraction = h6 - Math.floor(h6);
		const p = value * (1 - saturation);
		const q = value * (1 - saturation * fraction);
		const t = value * (1 - saturation * (1 - fraction));
		const colors = [[value, t, p], [q, value, p], [p, value, t], [p, q, value], [t, p, value], [value, p, q]][index];
		const rgb = colors.map((channel) => Math.round(channel * 255));
		const gradient = ctx.createLinearGradient(x, y, x, y + h);
		gradient.addColorStop(0, `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${Math.max(0, Math.min(1, alpha))})`);
		gradient.addColorStop(1, "rgba(0,0,0,0)");
		ctx.fillStyle = gradient;
		ctx.fillRect(x, y, w, h);
	}
	ctx.restore();
});

void clay_canvas2d_begin_frame(double width, double height, double ratio);
void clay_canvas2d_fill_rect(double x, double y, double w, double h,
	int r, int g, int b, int a, double tl, double tr, double bl, double br);
void clay_canvas2d_stroke_rect(double x, double y, double w, double h,
	int r, int g, int b, int a, double tl, double tr, double bl, double br,
	double left, double right, double top, double bottom);
void clay_canvas2d_push_clip(double x, double y, double w, double h);
void clay_canvas2d_pop_clip(void);
double clay_canvas2d_measure_text(const char *text, int font_id, double size,
	double letter_spacing, int skip_tags);
void clay_canvas2d_draw_text(const char *text, double x, double y,
	int r, int g, int b, int a, int font_id, double size,
	double letter_spacing, double line_height);
void clay_canvas2d_draw_grid(double x, double y, double w, double h, double step,
	double offset_x, double offset_y, int r, int g, int b, int a);
void clay_canvas2d_draw_bezier(double x, double y, double x0, double y0,
	double c1x, double c1y, double c2x, double c2y, double x1, double y1,
	double thickness, int r, int g, int b, int a);
void clay_canvas2d_color_picker(double x, double y, double w, double h, int kind,
	double hue, double saturation, double value, double alpha);

/*
 * EM_JS functions are callable from C, but they are JavaScript imports rather
 * than Wasm exports. luaffifb resolves ffi.C symbols with dlsym(), so expose
 * ordinary C forwarding functions for that ABI boundary.
 */
EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_begin_frame(
	double width, double height, double ratio) {
	clay_canvas2d_begin_frame(width, height, ratio);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_fill_rect(
	double x, double y, double w, double h, int r, int g, int b, int a,
	double tl, double tr, double bl, double br) {
	clay_canvas2d_fill_rect(x, y, w, h, r, g, b, a, tl, tr, bl, br);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_stroke_rect(
	double x, double y, double w, double h, int r, int g, int b, int a,
	double tl, double tr, double bl, double br,
	double left, double right, double top, double bottom) {
	clay_canvas2d_stroke_rect(x, y, w, h, r, g, b, a, tl, tr, bl, br,
		left, right, top, bottom);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_push_clip(
	double x, double y, double w, double h) {
	clay_canvas2d_push_clip(x, y, w, h);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_pop_clip(void) {
	clay_canvas2d_pop_clip();
}

EMSCRIPTEN_KEEPALIVE double clay_canvas2d_ffi_measure_text(
	const char* text, int font_id, double size, double letter_spacing, int skip_tags) {
	return clay_canvas2d_measure_text(text, font_id, size, letter_spacing, skip_tags);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_draw_text(
	const char* text, double x, double y, int r, int g, int b, int a,
	int font_id, double size, double letter_spacing, double line_height) {
	clay_canvas2d_draw_text(text, x, y, r, g, b, a, font_id, size,
		letter_spacing, line_height);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_draw_grid(
	double x, double y, double w, double h, double step,
	double offset_x, double offset_y, int r, int g, int b, int a) {
	clay_canvas2d_draw_grid(x, y, w, h, step, offset_x, offset_y, r, g, b, a);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_draw_bezier(
	double x, double y, double x0, double y0, double c1x, double c1y,
	double c2x, double c2y, double x1, double y1, double thickness,
	int r, int g, int b, int a) {
	clay_canvas2d_draw_bezier(x, y, x0, y0, c1x, c1y, c2x, c2y,
		x1, y1, thickness, r, g, b, a);
}

EMSCRIPTEN_KEEPALIVE void clay_canvas2d_ffi_color_picker(
	double x, double y, double w, double h, int kind,
	double hue, double saturation, double value, double alpha) {
	clay_canvas2d_color_picker(x, y, w, h, kind, hue, saturation, value, alpha);
}
