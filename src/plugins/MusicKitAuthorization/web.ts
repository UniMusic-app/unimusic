import { WebPlugin } from "@capacitor/core";
import type { MusicKitAuthorizationPlugin } from "../MusicKitAuthorization";

// Web implementation of WebKitAuthorization
export class MusicKitAuthorization extends WebPlugin
    implements MusicKitAuthorizationPlugin {
    async authorize(): Promise<
        { developerToken: string; musicUserToken: string }
    > {
        const authorizeMusicKit = async () => {
            const music = await MusicKit.configure({
                developerToken: import.meta.env.VITE_DEVELOPER_TOKEN,
                app: {
                    name: import.meta.env.VITE_APP_NAME,
                    build: import.meta.env.VITE_APP_VERSION,
                },
            });

            await music.authorize();
            return music;
        };

        if (globalThis.MusicKit) {
            const music = await authorizeMusicKit();

            return {
                developerToken: music.developerToken,
                musicUserToken: music.musicUserToken!,
            };
        }

        return await new Promise((resolve) => {
            document.addEventListener("musickitloaded", async () => {
                const music = await authorizeMusicKit();

                resolve({
                    developerToken: music.developerToken,
                    musicUserToken: music.musicUserToken!,
                });
            });
        });
    }
}
