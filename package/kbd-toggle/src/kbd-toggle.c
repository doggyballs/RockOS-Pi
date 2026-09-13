/*
 * kbd-toggle — a tiny Wayland overlay button that toggles wvkbd visibility.
 *
 * Draws a floating "⌨" button in the bottom-right corner of the screen
 * on the wlr-layer-shell overlay layer. On click (touch or mouse), sends
 * SIGRTMIN to the wvkbd process to toggle the keyboard.
 *
 * Dependencies: wayland-client, cairo (for drawing), libxkbcommon (transitive)
 * Protocol: wlr-layer-shell-unstable-v1 (for overlay surface)
 *
 * Build: see ../Makefile
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>

#include <wayland-client.h>
#include <cairo/cairo.h>

/* Wayland protocol headers — generated at build time from XML */
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "xdg-shell-client-protocol.h"

#define BTN_SIZE 48
#define BTN_MARGIN 8

/* --- globals --- */
static struct wl_display *display;
static struct wl_registry *registry;
static struct wl_compositor *compositor = NULL;
static struct zwlr_layer_shell_v1 *layer_shell = NULL;
static struct wl_shm *shm = NULL;
static struct wl_seat *seat = NULL;
static struct wl_pointer *pointer = NULL;

static struct wl_surface *surface;
static struct zwlr_layer_surface_v1 *layer_surface;
static int32_t output_w = 0, output_h = 0;
static int configured = 0;

static pid_t wvkbd_pid = 0;

/* --- find wvkbd PID --- */
static pid_t find_wvkbd_pid(void) {
    /* Read PID from /tmp/wvkbd.pid (written by S99rockos) */
    FILE *f = fopen("/tmp/wvkbd.pid", "r");
    if (f) {
        pid_t pid;
        if (fscanf(f, "%d", &pid) == 1) {
            fclose(f);
            return pid;
        }
        fclose(f);
    }
    /* Fallback: find by scanning /proc for "wvkbd" in cmdline */
    char buf[256];
    for (int i = 1; i < 32768; i++) {
        snprintf(buf, sizeof(buf), "/proc/%d/cmdline", i);
        int fd = open(buf, O_RDONLY);
        if (fd < 0) continue;
        int n = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (n > 0) {
            buf[n] = '\0';
            if (strstr(buf, "wvkbd")) return i;
        }
    }
    return 0;
}

static void toggle_keyboard(void) {
    if (wvkbd_pid == 0)
        wvkbd_pid = find_wvkbd_pid();
    if (wvkbd_pid > 0) {
        kill(wvkbd_pid, SIGRTMIN);
        fprintf(stderr, "kbd-toggle: sent SIGRTMIN to wvkbd (pid %d)\n", wvkbd_pid);
    } else {
        fprintf(stderr, "kbd-toggle: wvkbd process not found\n");
    }
}

/* --- shm buffer drawing --- */
static void draw_button(struct wl_shm *shm, struct wl_surface *surf) {
    int width = BTN_SIZE;
    int height = BTN_SIZE;
    int stride = width * 4;
    int buf_size = stride * height;

    /* Create a shm temp file */
    char tmpl[] = "/tmp/kbd-toggle-shm-XXXXXX";
    int fd = mkstemp(tmpl);
    if (fd < 0) return;
    unlink(tmpl);
    if (ftruncate(fd, buf_size) < 0) { close(fd); return; }

    void *data = mmap(NULL, buf_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) { close(fd); return; }

    /* Draw with cairo */
    cairo_surface_t *cs = cairo_image_surface_create_for_data(
        (unsigned char *)data, CAIRO_FORMAT_ARGB32, width, height, stride);
    cairo_t *cr = cairo_create(cs);

    /* Transparent background */
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    /* Draw a semi-transparent rounded rect */
    double r = 10;
    cairo_set_source_rgba(cr, 0.1, 0.1, 0.15, 0.85);
    cairo_new_sub_path(cr);
    cairo_arc(cr, width - r, r, r, -3.14/2, 0);
    cairo_arc(cr, width - r, height - r, r, 0, 3.14/2);
    cairo_arc(cr, r, height - r, r, 3.14/2, 3.14);
    cairo_arc(cr, r, r, r, 3.14, 3*3.14/2);
    cairo_close_path(cr);
    cairo_fill_preserve(cr);
    cairo_set_source_rgba(cr, 0.4, 0.4, 0.5, 0.8);
    cairo_set_line_width(cr, 1.5);
    cairo_stroke(cr);

    /* Draw the keyboard icon (simplified ⌨) */
    cairo_set_source_rgba(cr, 0.9, 0.9, 0.95, 1.0);
    /* Draw a small keyboard shape */
    double kx = 10, ky = 16, kw = 28, kh = 16;
    cairo_rectangle(cr, kx, ky, kw, kh);
    cairo_set_line_width(cr, 1.5);
    cairo_stroke(cr);
    /* Key dots */
    cairo_set_font_size(cr, 8);
    cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_move_to(cr, kx + 3, ky + 11);
    cairo_show_text(cr, ".....");
    cairo_move_to(cr, kx + 3, ky + 7);
    cairo_show_text(cr, ".....");

    cairo_destroy(cr);
    cairo_surface_destroy(cs);

    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, buf_size);
    struct wl_buffer *buffer = wl_shm_pool_create_buffer(pool, 0, width, height, stride,
        WL_SHM_FORMAT_ARGB8888);
    wl_surface_attach(surf, buffer, 0, 0);
    wl_surface_damage_buffer(surf, 0, 0, width, height);
    wl_surface_commit(surf);
    wl_buffer_destroy(buffer);
    wl_shm_pool_destroy(pool);
    munmap(data, buf_size);
    close(fd);
}

/* --- pointer handling --- */
static void pointer_enter(void *data, struct wl_pointer *p, uint32_t serial,
    struct wl_surface *surf, wl_fixed_t sx, wl_fixed_t sy) {}
static void pointer_leave(void *data, struct wl_pointer *p, uint32_t serial,
    struct wl_surface *surf) {}
static void pointer_motion(void *data, struct wl_pointer *p, uint32_t time,
    wl_fixed_t sx, wl_fixed_t sy) {}

static void pointer_button(void *data, struct wl_pointer *p, uint32_t serial,
    uint32_t time, uint32_t button, uint32_t state) {
    if (state == WL_POINTER_BUTTON_STATE_PRESSED && button == 0x110 /* BTN_LEFT */) {
        toggle_keyboard();
    }
}

static void pointer_axis(void *data, struct wl_pointer *p, uint32_t time,
    uint32_t axis, wl_fixed_t value) {}

static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
};

static void seat_capabilities(void *data, struct wl_seat *s, uint32_t caps) {
    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !pointer) {
        pointer = wl_seat_get_pointer(s);
        wl_pointer_add_listener(pointer, &pointer_listener, NULL);
    }
}

static void seat_name(void *data, struct wl_seat *s, const char *name) {}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

/* --- layer surface --- */
static void layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *ls,
    uint32_t serial, uint32_t width, uint32_t height) {
    output_w = width;
    output_h = height;
    zwlr_layer_surface_v1_ack_configure(ls, serial);
    configured = 1;
    draw_button(shm, surface);
}

static void layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *ls) {
    fprintf(stderr, "kbd-toggle: layer surface closed\n");
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

/* --- registry --- */
static void registry_global(void *data, struct wl_registry *r, uint32_t name,
    const char *iface, uint32_t version) {
    if (strcmp(iface, "wl_compositor") == 0)
        compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
    else if (strcmp(iface, "wl_shm") == 0)
        shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    else if (strcmp(iface, "wl_seat") == 0)
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
    else if (strcmp(iface, zwlr_layer_shell_v1_interface.name) == 0)
        layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
}

static void registry_remove(void *data, struct wl_registry *r, uint32_t name) {}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_remove,
};

int main(int argc, char *argv[]) {
    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "kbd-toggle: cannot connect to Wayland display\n");
        return 1;
    }

    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!compositor || !shm || !layer_shell) {
        fprintf(stderr, "kbd-toggle: missing required Wayland interfaces\n");
        return 1;
    }

    if (seat)
        wl_seat_add_listener(seat, &seat_listener, NULL);

    surface = wl_compositor_create_surface(compositor);

    layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        layer_shell, surface, NULL,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kbd-toggle");

    /* Anchor to bottom-right corner */
    zwlr_layer_surface_v1_set_anchor(layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);

    zwlr_layer_surface_v1_set_size(layer_surface, BTN_SIZE, BTN_SIZE);
    zwlr_layer_surface_v1_set_margin(layer_surface, 0, BTN_MARGIN, BTN_MARGIN, 0);
    zwlr_layer_surface_v1_set_keyboard_interactivity(layer_surface, 0);
    zwlr_layer_surface_v1_add_listener(layer_surface, &layer_surface_listener, NULL);
    wl_surface_commit(surface);
    wl_display_roundtrip(display);

    if (!configured) {
        fprintf(stderr, "kbd-toggle: layer surface not configured\n");
        return 1;
    }

    /* Find wvkbd PID at startup */
    wvkbd_pid = find_wvkbd_pid();
    fprintf(stderr, "kbd-toggle: wvkbd pid = %d\n", wvkbd_pid);

    /* Main loop */
    while (1) {
        if (wl_display_dispatch(display) == -1)
            break;
    }

    fprintf(stderr, "kbd-toggle: exiting\n");
    return 0;
}