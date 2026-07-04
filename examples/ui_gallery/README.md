# Machina UI Gallery

This project demonstrates the current retained UI primitives: canvas scaling,
screen-space panels, rounded borders, text labels, layout containers, scroll
views, buttons, command ids, command events, toggles, progress bars, separators,
and script-mutated UI state.

Button labels are parented to their button rects with `machina.ui.layout.item`,
so they inherit the button's resolved layout instead of duplicating absolute
positions. This is the preferred pattern for small composite controls.

```sh
mise machina check examples/ui_gallery
mise machina render examples/ui_gallery zig-out/ui-gallery.bmp
mise machina render-test examples/ui_gallery zig-out/ui-gallery-render-test.bmp
```
