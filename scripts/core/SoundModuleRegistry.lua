--
-- SoundModuleRegistry
--
-- The backbone: an ordered registry of feature modules. The loader installs ONE
-- global sound hook + ONE tick; both dispatch through this registry. Adding a
-- feature = registering a module here; the core never changes.
--

SoundModuleRegistry = {}
SoundModuleRegistry.modules = {}
SoundModuleRegistry.byName = {}

---Register a module. Ignores duplicates (by name) so a double-source is safe.
-- @param table module a SoundModule instance
function SoundModuleRegistry.register(module)
    if module == nil or module.name == nil then
        Logging.warning("[SoundOverhaulRealism] register: ignoring module without a name.")
        return
    end
    if SoundModuleRegistry.byName[module.name] ~= nil then
        return
    end
    SoundModuleRegistry.byName[module.name] = module
    table.insert(SoundModuleRegistry.modules, module)
    Logging.info("[SoundOverhaulRealism] module registered: %s", module.name)
end

---@return table ordered list of registered modules
function SoundModuleRegistry.getModules()
    return SoundModuleRegistry.modules
end

---@param string name module id
-- @return table|nil the registered module, or nil
function SoundModuleRegistry.get(name)
    return SoundModuleRegistry.byName[name]
end
