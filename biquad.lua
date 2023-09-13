-- Biquad filter (doesn't sound exactly the same as the original meowsynth)
-- Based on: https://github.com/Kurene/pyquadfilter
local TAU = math.pi * 2
local cos = math.cos
local sin = math.sin

local w, cos_w, sin_w, alpha
local a0, a1, a2, b0, b1, b2
local y, xbuf0, xbuf1, ybuf0, ybuf1 = 0, 0, 0, 0, 0
local q = 1.25
return function(x, cutoff, samplerate)
    w = TAU * cutoff / samplerate
    cos_w, sin_w = cos(w), sin(w)
    alpha = 0.5 * sin_w / q

    a0 = 1.0 + alpha
    a1 = -2.0 * cos_w / a0
    a2 = (1.0 - alpha) / a0
    b0 = (1.0 - cos_w) * 0.5 / a0
    b1 = (1.0 - cos_w) / a0
    b2 = (1.0 - cos_w) * 0.5 / a0

    y = b0 * x + b1 * xbuf1 + b2 * xbuf0 - a1 * ybuf1 - a2 * ybuf0
    xbuf0, xbuf1 = xbuf1, x
    ybuf0, ybuf1 = ybuf1, y

    return y
end
