export function sleep(delayMs: number): Promise<void> {
    return new Promise((r) => setTimeout(r,  delayMs));
}

type Platform = "macOS" | "iPhone" | "iPad" | "Windows" | "Android" | (string & {});
export function getCurrentPlatform(): Platform {
    if ("userAgentData" in navigator) {
        return (navigator.userAgentData as { platform: string }).platform;
    }
    
    switch (navigator.platform) {
        case "MacIntel":
            return "macOS";
        default:
            return navigator.platform;
    };
}

export function isMobile(): boolean {
    switch (getCurrentPlatform()) {
        case "Android":
        case "iPhone":
        case "iPad":
            return true;
        default:
            return false;
    }
}