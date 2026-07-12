--
-- SoundProfiles
--
-- The "realistic" brain: map each vehicle to an engineClass so the swap picks a
-- plausible engine sound instead of one generic loop for everything.
--
-- Two tiers (mirrors IronHorse's data-table approach):
--   * Tier 1 - explicit per-model overrides for flagships (accurate), keyed by a
--     substring of the vehicle's configFileName (brand/model folder).
--   * Tier 2 - a heuristic fallback classifying the long tail by
--     (powerBand x maxRpm x category x brand) so EVERY vehicle gets a sensible
--     class even before it is hand-mapped.
--
-- Realism calibration (verified, docs/SOUND_RESEARCH.md 11.2): tractors are
-- overwhelmingly inline-4 / inline-6 turbo-diesels. Genuine V8 is SELECTIVE
-- (Scania V8 trucks are the showcase). We NEVER fake a V8 everywhere.
--

SoundProfiles = {}

-- Engine class ids (also the pack folder keys). nil = "no profile" -> vanilla.
SoundProfiles.CLASS = {
    I4_TD_SMALL     = "i4_td_small",     -- small tractor, inline-4 turbo diesel
    I6_TD_MEDIUM    = "i6_td_medium",    -- medium tractor, inline-6 turbo diesel
    I6_TD_LARGE     = "i6_td_large",     -- large tractor, inline-6 turbo diesel
    I6_TD_ARTIC     = "i6_td_artic",     -- big articulated (Steiger/9R/T9), inline-6
    V8_DIESEL_TRUCK = "v8_diesel_truck", -- Scania-class V8 truck (the highlight)
    I4_NA_VINTAGE   = "i4_na_vintage",   -- vintage / low-rpm naturally aspirated
}

-- Heuristic thresholds. Real-data grounded (kW), no magic numbers inline.
SoundProfiles.CFG = {
    SMALL_MAX_KW   = 90,    -- <= ~120 hp: small tractor band
    MEDIUM_MAX_KW  = 160,   -- <= ~215 hp: medium band
    LARGE_MAX_KW   = 260,   -- <= ~350 hp: large band; above -> articulated
    VINTAGE_MAX_RPM = 2100, -- old diesels lug low; combined with low power = vintage
    VINTAGE_MAX_KW = 70,
}

-- Tier 1: explicit flagship overrides. Keys are lowercase substrings matched
-- against the vehicle configFileName. First match wins (longest/most specific
-- listed first). Grounded in the real engine behind each model.
SoundProfiles.TIER1 = {
    { match = "scania",              class = "v8_diesel_truck" }, -- Scania V8 trucks (showcase)
    { match = "johndeere/9r",        class = "i6_td_artic" },     -- 9R articulated, Cummins/JD I6
    { match = "johndeere/8r",        class = "i6_td_large" },     -- 8R = 9.0L PowerTech inline-6
    { match = "fendt/1000",          class = "i6_td_large" },     -- Fendt 1000 = MAN D26 inline-6 12.4L
    { match = "caseih/steiger",      class = "i6_td_artic" },     -- Steiger/Quadtrac, FPT Cursor I6
    { match = "caseih/quadtrac",     class = "i6_td_artic" },
    { match = "newholland/t9",       class = "i6_td_artic" },     -- T9 articulated
}

---Classify a vehicle from extracted numbers. PURE (no engine calls) so it is
-- fully unit-testable.
-- @param number powerKw   peak engine power in kW (0 if unknown)
-- @param number maxRpm    engine max rpm (0 if unknown)
-- @param string category  store category name, lowercased ("truck","tractor",...)
-- @param string brand     brand name, lowercased ("scania", ...)
-- @return string engineClass
function SoundProfiles.classify(powerKw, maxRpm, category, brand)
    powerKw = powerKw or 0
    maxRpm = maxRpm or 0
    category = category or ""
    brand = brand or ""
    local C = SoundProfiles.CLASS
    local CFG = SoundProfiles.CFG

    -- V8 trucks are the one selective V8 case (brand- or category-driven).
    local isTruck = category:find("truck") ~= nil
    if isTruck and brand == "scania" then
        return C.V8_DIESEL_TRUCK
    end

    -- Vintage: genuinely low power AND low-revving (avoids catching modern low-hp).
    if powerKw > 0 and powerKw <= CFG.VINTAGE_MAX_KW
        and maxRpm > 0 and maxRpm <= CFG.VINTAGE_MAX_RPM then
        return C.I4_NA_VINTAGE
    end

    -- Power bands (default engine family = inline turbo-diesel).
    if powerKw <= CFG.SMALL_MAX_KW then
        return C.I4_TD_SMALL
    elseif powerKw <= CFG.MEDIUM_MAX_KW then
        return C.I6_TD_MEDIUM
    elseif powerKw <= CFG.LARGE_MAX_KW then
        return C.I6_TD_LARGE
    else
        -- Above the large band: articulated tractors get the artic class; a
        -- non-tractor heavy (e.g. big truck) stays on the large inline-6.
        if category == "" or category:find("tractor") ~= nil then
            return C.I6_TD_ARTIC
        end
        return C.I6_TD_LARGE
    end
end

---Match a configFileName against the Tier-1 table. PURE.
-- @param string configFileName  the vehicle xml path (any case)
-- @return string|nil engineClass or nil if no flagship match
function SoundProfiles.tier1Match(configFileName)
    if type(configFileName) ~= "string" then
        return nil
    end
    local key = configFileName:lower():gsub("\\", "/")
    for _, entry in ipairs(SoundProfiles.TIER1) do
        if key:find(entry.match, 1, true) ~= nil then
            return entry.class
        end
    end
    return nil
end

---Read the classification inputs off a live vehicle. IN-GAME ONLY (defensive;
-- not unit-tested). Returns numbers/strings suitable for classify().
-- @param table vehicle
-- @return number powerKw, number maxRpm, string category, string brand
function SoundProfiles.extract(vehicle)
    local powerKw, maxRpm, category, brand = 0, 0, "", ""
    if vehicle == nil then
        return powerKw, maxRpm, category, brand
    end
    local spec = vehicle.spec_motorized
    if spec ~= nil and spec.motor ~= nil then
        if spec.motor.peakMotorPower ~= nil then
            powerKw = spec.motor.peakMotorPower / 1000 -- W -> kW
        end
        maxRpm = spec.motor.maxRpm or spec.motor.getMaxRpm ~= nil and spec.motor:getMaxRpm() or 0
    end
    if g_storeManager ~= nil and vehicle.configFileName ~= nil then
        local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
        if item ~= nil then
            category = (item.categoryName or ""):lower()
            if g_brandManager ~= nil and item.brandIndex ~= nil then
                local b = g_brandManager:getBrandByIndex(item.brandIndex)
                if b ~= nil and b.name ~= nil then
                    brand = b.name:lower()
                end
            end
        end
    end
    return powerKw, maxRpm, category, brand
end

---Resolve a live vehicle to its engineClass: Tier 1 first, then the heuristic.
-- IN-GAME entry point (composes extract + the two pure resolvers).
-- @param table vehicle
-- @return string|nil engineClass (nil only if there is no vehicle at all)
function SoundProfiles.forVehicle(vehicle)
    if vehicle == nil then
        return nil
    end
    local t1 = SoundProfiles.tier1Match(vehicle.configFileName)
    if t1 ~= nil then
        return t1
    end
    return SoundProfiles.classify(SoundProfiles.extract(vehicle))
end
