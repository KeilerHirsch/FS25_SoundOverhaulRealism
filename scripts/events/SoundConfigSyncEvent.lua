--
-- SoundConfigSyncEvent
--
-- Replicates the (small) global SoundConfig across the network. The audio itself
-- is client-side and needs no sync; only the master toggle + per-module flags do.
-- STRICTLY server-authoritative (server -> clients only). A client-originated
-- event is IGNORED — a modified client must not be able to flip everyone's audio
-- config (this mirrors IronHorseSyncEvent's deny-by-default). Foundation: a future
-- admin-gated settings UI would broadcast from the server. No money/authority writes.
--

SoundConfigSyncEvent = {}
local SoundConfigSyncEvent_mt = Class(SoundConfigSyncEvent, Event)

InitEventClass(SoundConfigSyncEvent, "SoundConfigSyncEvent")

function SoundConfigSyncEvent.emptyNew()
    return Event.new(SoundConfigSyncEvent_mt)
end

---@param table values { enabled, engine, ambient } booleans
function SoundConfigSyncEvent.new(values)
    local self = SoundConfigSyncEvent.emptyNew()
    self.values = values or SoundConfig.toValues()
    return self
end

function SoundConfigSyncEvent:writeStream(streamId, _connection)
    streamWriteBool(streamId, self.values.enabled == true)
    streamWriteBool(streamId, self.values.engine == true)
    streamWriteBool(streamId, self.values.ambient == true)
end

function SoundConfigSyncEvent:readStream(streamId, connection)
    self.values = {
        enabled = streamReadBool(streamId),
        engine = streamReadBool(streamId),
        ambient = streamReadBool(streamId),
    }
    self:run(connection)
end

function SoundConfigSyncEvent:run(connection)
    -- Deny-by-default: only a server -> client broadcast is trusted. Ignore any
    -- client-originated event so a modified client cannot force everyone's config.
    if not connection:getIsServer() then
        return
    end
    SoundConfig.applyValues(self.values)
end

---Broadcast the current config from the SERVER to all clients. No-op on a client
-- (clients may not push config).
function SoundConfigSyncEvent.sendCurrent()
    if g_server ~= nil then
        g_server:broadcastEvent(SoundConfigSyncEvent.new(SoundConfig.toValues()), false)
    end
end
