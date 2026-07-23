# Cluster Cathedral

This example fills a long dark hall with **320 independently animated HDR point lights**. Sixteen lights orbit each of twenty architectural ribs while traveling pulses move through the palette. The result exercises Scrapbot's 16×9×24 GPU-computed light clusters, growable light/index buffers beyond their initial 256-light capacity, retained dirty transforms, shared geometry/material batching, bloom, and cascaded shadows in one deliberately excessive scene.

Run it directly:

```sh
mise scrapbot run examples/clustered-lights
```

Or open the live editor and watch the performance diagnostics:

```sh
mise scrapbot run examples/clustered-lights --editor
```

The project camera drifts gently through the cathedral. Opening the editor gives you a separate fly camera, so you can move through the individual lighting volumes without disturbing the authored view.
