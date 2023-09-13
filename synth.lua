local filter = require("biquad")

---@type Speaker
local speaker = peripheral.find("speaker")
if not speaker then
    -- Try attaching speaker in simulator using periphemu
    if periphemu then
        periphemu.create("top", "speaker")
        speaker = peripheral.find("speaker")
    end

    if not speaker then
        print("Could not connect to speaker!")
        print("Please attach a speaker, e.g. using:")
        print("  attach top speaker")
        return false
    end
end

-- https://tweaked.cc/guide/speaker_audio.html

local samplerate = 48000 -- 48,000 samples a second
-- each sample is an integer between -128 and 127


local pitch = 110
local volume = 0.2

local max = math.max
local min = math.min
local floor = math.floor
local log = math.log

-- clicking "browser paramters" in MeowSynth will reveal more parameters

-- Envelope state enum
local ENV_STATE_NONE = 0
local ENV_STATE_ATTACKING = 1
local ENV_STATE_DECAYING = 2
local ENV_STATE_SUSTAINING = 3
local ENV_STATE_RELEASING = 4

---Create an ADSR envelope
---@param min_value number > 1
---@param max_value number > min_value
---@param attack number in seconds
---@param decay number in seconds
---@param sustain number 0 to 100
---@param release number in seconds
---@return Envelope
local function createEvelope(min_value, max_value, attack, decay, sustain, release)
    ---@class Envelope
    local envelope = {
        state = ENV_STATE_NONE,
        value = min_value,
        attack_factor = 0,
        decay_factor = 0,
        sustain_level = 0,
        release_factor = 0,
        attack = 0,
        decay = 0,
        sustain = 0,
        release = 0,
        ---Set envelope parameters
        ---@param self Envelope
        ---@param attack? number in seconds
        ---@param decay? number in seconds
        ---@param sustain? number 0 to 100
        ---@param release? number in seconds
        setEvelopeParams = function(self, attack, decay, sustain, release)
            attack = attack or self.attack
            decay = decay or self.decay
            sustain = sustain or self.sustain
            release = release or self.release
            self.attack_factor = max_value ^ (1 / (attack * samplerate))
            self.decay_factor = sustain ^ (1 / (decay * samplerate))
            self.sustain_level = max_value * sustain
            self.release_factor = 1 / (self.sustain_level ^ (1 / (release * samplerate)))
        end,
        ---Get the next value from the envelope
        ---@param self Envelope
        ---@return number
        getValue = function(self)
            if self.state == ENV_STATE_RELEASING then
                self.value = max(self.value * self.release_factor, min_value)
                if self.value == min_value then self.state = ENV_STATE_NONE end
            elseif self.state == ENV_STATE_DECAYING then
                self.value = max(self.value * self.decay_factor, self.sustain_level)
                if self.value == self.sustain_level then self.state = ENV_STATE_SUSTAINING end
            elseif self.state == ENV_STATE_ATTACKING then
                self.value = min(self.value * self.attack_factor, max_value)
                if self.value == max_value then self.state = ENV_STATE_DECAYING end
            end
            return self.value
        end
    }
    envelope:setEvelopeParams(attack, decay, sustain, release)
    return envelope
end

local CUTOFF_MAX = 20000
local cutoff_envelope = createEvelope(1, CUTOFF_MAX, 0.25, 0.75, 0.01, 0.25)
local volume_envelope = createEvelope(1, 10000, 0.01, 1, 1, 0.01)
local cutoff_max_log2 = math.log(CUTOFF_MAX, 2)

-- Audio buffer
local audio_buffer = {}
local BUFFER_LENGTH = 1024
local t, x = 0, 0
local cutoff, vol = 0, 0
local cutoff_level = 0
local onNewCutoffLevel = function(level) return end
local function processAudio()
    while true do
        local wavelength = samplerate / pitch
        for i = 1, BUFFER_LENGTH do
            t = (t + 1) % wavelength
            x = 2 * t / wavelength - 1 -- saw tooth (-1 to 1)
            cutoff = cutoff_envelope:getValue()
            x = filter(x, cutoff, samplerate)
            vol = volume_envelope:getValue() * 0.0001
            if vol == 0.0001 then vol = 0 end
            x = max(-1, min(x * volume * vol, 1))
            audio_buffer[i] = floor(127 * x) -- output (-128 to 127)

            if cutoff_envelope.state == ENV_STATE_NONE and volume_envelope ~= ENV_STATE_NONE then
                volume_envelope.state = ENV_STATE_RELEASING
            end
        end

        local new_cutoff_level = floor(log(cutoff, 2) / cutoff_max_log2 * 7) + 1
        if cutoff_level ~= new_cutoff_level then
            cutoff_level = new_cutoff_level
            onNewCutoffLevel(cutoff_level)
        end

        speaker.playAudio(audio_buffer) -- play one buffer at a time for quick response
        os.pullEvent("speaker_audio_empty")
    end
end

local triggerNote = function(newPitch)
    cutoff_envelope.state = ENV_STATE_ATTACKING
    volume_envelope.state = ENV_STATE_ATTACKING
    pitch = newPitch
end

local releaseNote = function()
    cutoff_envelope.state = ENV_STATE_RELEASING
end

return {
    processAudio = processAudio,
    triggerNote = triggerNote,
    releaseNote = releaseNote,
    ---Set envelope parameters
    ---@param attack? number in seconds
    ---@param decay? number in seconds
    ---@param sustain? number 0 to 100
    ---@param release? number in seconds
    setEvelopeParams = function(attack, decay, sustain, release)
        cutoff_envelope:setEvelopeParams(attack, decay, sustain, release)
    end,
    setNewCutoffLevelListener = function(listener)
        onNewCutoffLevel = listener
    end
}
