#include <iostream>

#if defined(PLATFORM_WINDOWS)
#include <windows.h>

// This is what Visual Studio compiles on Windows
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        // Create a diagnostic console window so we can see print statements inside Geometry Dash
        AllocConsole();
        FILE* f;
        freopen_s(&f, "CONOUT$", "w", stdout);

        std::cout << "[GeoDashCore] Core Engine successfully injected on Windows!" << std::endl;
    }
    return TRUE;
}

#elif defined(PLATFORM_MAC)

// This is what Xcode compiles on macOS
__attribute__((constructor))
void initialize_mac_loader() {
    std::cout << "[GeoDashCore] Core Engine successfully injected on macOS!" << std::endl;
}

#endif