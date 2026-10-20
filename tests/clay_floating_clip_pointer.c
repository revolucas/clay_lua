#define CLAY_IMPLEMENTATION
#include "../src/clay/clay.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static void handle_error(Clay_ErrorData error) {
    fprintf(stderr, "Clay error %d: %.*s\n", (int)error.errorType,
        error.errorText.length, error.errorText.chars);
    abort();
}

static Clay_Dimensions measure_text(Clay_StringSlice text,
        Clay_TextElementConfig *config, void *userData) {
    (void)text;
    (void)config;
    (void)userData;
    return (Clay_Dimensions){ 0, 0 };
}

static int clip_depth_inside_floating;
static int clip_depth_at_sibling;
static bool sibling_pointer_over;
static bool floating_child_pointer_over;

static void declare_layout(bool inspectPointer, bool clipToParent) {
    Clay_BeginLayout();
    CLAY(CLAY_ID("test-root"), {
        .layout = {
            .sizing = { CLAY_SIZING_FIXED(100), CLAY_SIZING_FIXED(100) },
            .layoutDirection = CLAY_TOP_TO_BOTTOM,
        },
    }) {
        CLAY(CLAY_ID("outer-clip"), {
            .layout = { .sizing = { CLAY_SIZING_FIXED(10), CLAY_SIZING_FIXED(10) } },
            .clip = { .horizontal = true, .vertical = true },
        }) {
            CLAY(CLAY_ID("floating-clipped"), {
                .layout = { .sizing = { CLAY_SIZING_FIXED(10), CLAY_SIZING_FIXED(10) } },
                .floating = {
                    .offset = { 0, 0 },
                    .attachPoints = { CLAY_ATTACH_POINT_LEFT_TOP, CLAY_ATTACH_POINT_LEFT_TOP },
                    .attachTo = CLAY_ATTACH_TO_PARENT,
                    .clipTo = clipToParent ? CLAY_CLIP_TO_ATTACHED_PARENT : CLAY_CLIP_TO_NONE,
                },
                .clip = { .horizontal = true, .vertical = true },
            }) {
                if (inspectPointer) {
                    clip_depth_inside_floating = Clay_GetCurrentContext()->openClipElementStack.length;
                }
                CLAY(CLAY_ID("floating-child"), {
                    .layout = { .sizing = { CLAY_SIZING_FIXED(20), CLAY_SIZING_FIXED(20) } },
                }) {
                    if (inspectPointer) floating_child_pointer_over = Clay_Hovered();
                }
            }
        }

        CLAY(CLAY_ID("after-floating"), {
            .layout = { .sizing = { CLAY_SIZING_FIXED(20), CLAY_SIZING_FIXED(20) } },
        }) {
            if (inspectPointer) {
                clip_depth_at_sibling = Clay_GetCurrentContext()->openClipElementStack.length;
                sibling_pointer_over = Clay_Hovered();
            }
        }
    }
    (void)Clay_EndLayout(0.0f);
}

int main(void) {
    size_t memorySize = Clay_MinMemorySize();
    void *memory = malloc(memorySize);
    assert(memory != NULL);

    Clay_Arena arena = Clay_CreateArenaWithCapacityAndMemory(memorySize, memory);
    Clay_Initialize(arena, (Clay_Dimensions){ 100, 100 },
        (Clay_ErrorHandler){ handle_error, NULL });
    Clay_SetMeasureTextFunction(measure_text, NULL);

    declare_layout(false, true);
    Clay_SetPointerState((Clay_Vector2){ 5, 15 }, false);
    declare_layout(true, true);

    assert(clip_depth_inside_floating == 2);
    assert(clip_depth_at_sibling == 0);
    assert(sibling_pointer_over);

    // With clipTo=NONE, the floating element's own clip must still constrain
    // its children. The child is 20x20 while its floating parent clips to 10x10.
    declare_layout(false, false);
    Clay_SetPointerState((Clay_Vector2){ 15, 5 }, false);
    declare_layout(true, false);
    assert(!floating_child_pointer_over);

    free(memory);
    puts("floating clip pointer regression passed");
    return 0;
}
