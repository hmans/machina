package asset_import

import "core:math"
import "core:testing"

@(test)
test_environment_sampling_bilinearly_filters_texels :: proc(t: ^testing.T) {
	source := []f32{1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1}
	sample := environment_sample_equirect(source, 2, 2, {1, 0, 0})
	for channel in 0 ..< 3 {
		testing.expect(t, math.abs(sample[channel] - 0.5) < 0.0001)
	}
}

@(test)
test_environment_sampling_is_continuous_across_panorama_seam :: proc(t: ^testing.T) {
	source := []f32{1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1}
	above := environment_sample_equirect(source, 2, 2, {-1, 0, 0.0001})
	below := environment_sample_equirect(source, 2, 2, {-1, 0, -0.0001})
	for channel in 0 ..< 3 {
		testing.expect(t, math.abs(above[channel] - below[channel]) < 0.0001)
	}
}
