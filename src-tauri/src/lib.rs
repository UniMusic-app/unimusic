use std::collections::HashMap;
use std::time::Duration;
use tauri::{AppHandle, Url, WebviewWindowBuilder};
use tokio::time;

#[derive(Debug, thiserror::Error)]
#[allow(unused)]
enum AuthorizationError {
    #[error("Missing initial url")]
    NoInitialUrl,
    #[error("Invalid url: {0}")]
    InvalidUrl(String),
    #[error("Tauri error: {0}")]
    Tauri(#[from] tauri::Error),
}

impl serde::Serialize for AuthorizationError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::ser::Serializer,
    {
        serializer.serialize_str(self.to_string().as_ref())
    }
}

// Mobile platforms are limited to a singular Webview
// Because of this we have two ways of handling the authorization:
//  - Mobile:
//      1. Navigate to the OAuth endpoint
//      2. When MUT has been obtained from the URL redirect back to the app with the musicUserToken parameter set
//      3. App then handles the parameter to set the MusicKit MUT
//  - Desktop:
//      1. Open new WebviewWindow at OAuth endpoint
//      2. Obtain MUT from the URL and return it
//      3. App then can set it directly without any special redirects
cfg_if::cfg_if! {
    if #[cfg(mobile)] {
        #[tauri::command(async)]
        async fn authorize_apple_music(
            app: AppHandle,
            webview: tauri::WebviewWindow,
            url: &str,
        ) -> Result<String, AuthorizationError> {
            let initial_url = webview
                .url()
                .map_err(|_| AuthorizationError::NoInitialUrl)?;

            let url = Url::parse(url).map_err(|e| AuthorizationError::InvalidUrl(e.to_string()))?;

            let webview = WebviewWindowBuilder::new(
                &app,
                "apple-music-authorization",
                tauri::WebviewUrl::External(url),
            ).build()?;

            let mut interval = time::interval(Duration::from_millis(500));
            loop {
                let Ok((url_str, url)) = webview.url().map(|url| (url.to_string(), url)) else {
                    interval.tick().await;
                    continue;
                };

                if url_str.contains("musicUserToken") {
                    let url_params: HashMap<_, _> = url.query_pairs().collect();
                    let music_user_token = url_params
                        .get("musicUserToken")
                        .expect("musicUserToken should exist as param")
                        .to_string();

                    let authorized_url = Url::parse_with_params(
                        initial_url.as_str(),
                        &[("musicUserToken", &music_user_token)],
                    )
                    .map_err(|e| AuthorizationError::InvalidUrl(e.to_string()))?;

                    let webview = WebviewWindowBuilder::new(
                        &app,
                        "music-player",
                        tauri::WebviewUrl::App(std::path::PathBuf::from("/"))
                    ).build()?;
                    webview.eval(&format!("window.location.href = '{authorized_url}'"))?;

                    return Ok(music_user_token);
                }

                interval.tick().await;
            }
        }
    } else {
        #[tauri::command(async)]
        async fn authorize_apple_music(app: AppHandle, url: &str) -> Result<String, AuthorizationError> {
            let url = Url::parse(url).map_err(|e| AuthorizationError::InvalidUrl(e.to_string()))?;

            let mut webview = WebviewWindowBuilder::new(
                &app,
                "apple-music-authorization",
                tauri::WebviewUrl::External(url),
            )
            .title("Apple Music Authorization")
            .inner_size(600.0, 800.0)
            .content_protected(true)
            .build()?;

            let mut interval = time::interval(Duration::from_millis(500));
            let mut refreshed = false;
            loop {
                let Ok((url_str, url)) = webview.url().map(|url| (url.to_string(), url)) else {
                    interval.tick().await;
                    continue;
                };

                // On macOS on debug builds this might get stuck on the loading spinner
                // Forcefully renavigating the webview fixes it
                // It's most likely related to the macOS TouchID logic to make the logging in seamless,
                // as debug builds require logging in with email and password
                // While production build does not freeze and allows TouchID to be used
                #[cfg(target_os = "macos")]
                if tauri::is_dev() && !refreshed && url_str.contains("idmsa") {
                    time::sleep(Duration::from_secs(2)).await;
                    webview.navigate(url)?;
                    refreshed = true;
                    continue;
                }

                if url_str.contains("musicUserToken") {
                    let url_params: HashMap<_, _> = url.query_pairs().collect();
                    let music_user_token = url_params
                        .get("musicUserToken")
                        .expect("musicUserToken should exist as param")
                        .to_string();

                    webview.close()?;
                    return Ok(music_user_token);
                }

                interval.tick().await;
            }
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![authorize_apple_music,])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
