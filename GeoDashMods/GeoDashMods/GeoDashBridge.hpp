// GeoDashBridge.hpp
#ifndef GeoDashBridge_hpp
#define GeoDashBridge_hpp

#ifdef __cplusplus
#include <string>
#include <vector>

// We change this to GeoDashCore so Swift can find the scope perfectly!
namespace GeoDashCore {
    class BridgeManager {
    public:
        static bool isGameRunning();
        static std::vector<std::string> getInstalledMods();
    };
}
#endif // __cplusplus

#endif /* GeoDashBridge_hpp */
