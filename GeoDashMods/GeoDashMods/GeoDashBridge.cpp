// GeoDashBridge.cpp
#include "GeoDashBridge.hpp"

#ifdef __cplusplus
namespace GeoDashCore {

    bool BridgeManager::isGameRunning() {
        return true;
    }

    std::vector<std::string> BridgeManager::getInstalledMods() {
        return { "Speedhack.geode", "CustomMenu.geode", "TextureLoader.geode" };
    }
}

extern "C" bool GeoDashIsGameRunning() {
    return GeoDashCore::BridgeManager::isGameRunning();
}

extern "C" const char *GeoDashInstalledMods() {
    static const std::string installedMods = [] {
        const auto mods = GeoDashCore::BridgeManager::getInstalledMods();
        std::string result;
        for (size_t index = 0; index < mods.size(); ++index) {
            if (index > 0) {
                result += '\n';
            }
            result += mods[index];
        }
        return result;
    }();
    return installedMods.c_str();
}
#endif // __cplusplus
