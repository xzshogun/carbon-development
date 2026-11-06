use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::process::Command;

const SOCKET_PATH: &str = "/tmp/carbon-hub.sock";

#[derive(Debug, Deserialize)]
struct HubRequest {
    #[allow(dead_code)]
    #[serde(default)]
    module: String,
    action: String,
    #[serde(default)]
    value: Option<Value>,
    #[serde(default)]
    path: Option<String>,
    #[serde(default)]
    scheme: Option<String>,
    #[serde(default)]
    monitor: Option<String>,
    #[serde(default)]
    w: Option<i64>,
    #[serde(default)]
    h: Option<i64>,
    #[serde(default)]
    rate: Option<f64>,
    #[serde(default)]
    transform: Option<i64>,
    #[serde(default)]
    scale: Option<f64>,
    #[serde(default)]
    state: Option<i64>,
    #[serde(default)]
    temp: Option<i64>,
    #[serde(default)]
    feature: Option<String>,
    #[serde(default)]
    scope: Option<String>,
    #[serde(default)]
    binds: Option<Value>,
}

#[derive(Debug, Serialize)]
struct HubResponse {
    status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    action: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    elapsed_us: Option<u128>,
}

fn home_dir() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| env::var("USER").map(|u| PathBuf::from(format!("/home/{}", u))))
        .unwrap_or_else(|_| PathBuf::from("."))
}

fn config_dir() -> PathBuf {
    env::var("CARBON_CONFIG_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join(".config/carbon"))
}

// ---------------------------------------------------------------------------
// HYPRLAND HANDLER (< 1ms IPC over raw unix socket)
// ---------------------------------------------------------------------------
async fn get_hypr_socket_path() -> Option<PathBuf> {
    let xdg = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        if let Ok(out) = std::process::Command::new("id").arg("-u").output() {
            if let Ok(uid_str) = String::from_utf8(out.stdout) {
                let uid = uid_str.trim();
                if !uid.is_empty() {
                    return format!("/run/user/{}", uid);
                }
            }
        }
        "/tmp".to_string()
    });

    if let Ok(sig) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        let p = PathBuf::from(&xdg).join("hypr").join(&sig).join(".socket.sock");
        if p.exists() {
            return Some(p);
        }
    }

    // Auto-discover if HYPRLAND_INSTANCE_SIGNATURE is not set in environment
    let hypr_dir = PathBuf::from(&xdg).join("hypr");
    if let Ok(entries) = std::fs::read_dir(&hypr_dir) {
        for entry in entries.flatten() {
            let sock = entry.path().join(".socket.sock");
            if sock.exists() {
                return Some(sock);
            }
        }
    }

    None
}

async fn send_raw_hypr_cmd(cmd: &str) -> Result<String, String> {
    let sock_path = get_hypr_socket_path().await.ok_or("Hyprland socket not found")?;
    let mut stream = UnixStream::connect(sock_path).await.map_err(|e| e.to_string())?;
    
    let mut payload = cmd.as_bytes().to_vec();
    if !cmd.ends_with('\n') {
        payload.push(b'\n');
    }
    
    stream.write_all(&payload).await.map_err(|e| e.to_string())?;
    stream.shutdown().await.map_err(|e| e.to_string())?;

    let mut reader = BufReader::new(stream);
    let mut response = String::new();
    reader.read_to_string(&mut response).await.map_err(|e| e.to_string())?;
    Ok(response.trim().to_string())
}

async fn set_hypr_option(key: &str, val_str: &str) -> Result<(), String> {
    // Generate both Lua hl.config syntax (default modern) and legacy keyword fallback
    let lua_call = match key {
        "decoration:blur:size" | "blur" => {
            let num: i64 = val_str.parse().unwrap_or(5);
            format!("eval hl.config({{ decoration = {{ blur = {{ size = {} }} }} }})", num)
        }
        "general:gaps_out" | "gaps" => {
            let num: i64 = val_str.parse().unwrap_or(6);
            format!("eval hl.config({{ general = {{ gaps_out = {} }} }})", num)
        }
        "decoration:active_opacity" | "active_opacity" => {
            let num: f64 = val_str.parse().unwrap_or(1.0);
            format!("eval hl.config({{ decoration = {{ active_opacity = {:.2} }} }})", num)
        }
        "decoration:inactive_opacity" | "inactive_opacity" => {
            let num: f64 = val_str.parse().unwrap_or(1.0);
            format!("eval hl.config({{ decoration = {{ inactive_opacity = {:.2} }} }})", num)
        }
        "general:border_size" | "border" => {
            let num: i64 = val_str.parse().unwrap_or(1);
            format!("eval hl.config({{ general = {{ border_size = {} }} }})", num)
        }
        "decoration:shadow:enabled" | "shadow" => {
            let b = val_str == "true" || val_str == "1";
            format!("eval hl.config({{ decoration = {{ shadow = {{ enabled = {} }} }} }})", b)
        }
        _ => return Err(format!("Unknown hypr key: {}", key)),
    };

    let res = send_raw_hypr_cmd(&lua_call).await;
    match res {
        Ok(out) if out == "ok" => Ok(()),
        Ok(_) => {
            // If Lua parser rejected or legacy fallback needed:
            let kw_name = match key {
                "blur" => "decoration:blur:size",
                "gaps" => "general:gaps_out",
                "active_opacity" => "decoration:active_opacity",
                "inactive_opacity" => "decoration:inactive_opacity",
                "border" => "general:border_size",
                "shadow" => "decoration:shadow:enabled",
                other => other,
            };
            let kw_cmd = format!("keyword {} {}", kw_name, val_str);
            let _ = send_raw_hypr_cmd(&kw_cmd).await;
            Ok(())
        }
        Err(e) => Err(e),
    }
}

async fn get_hypr_state() -> Value {
    let opts = [
        ("blur", "decoration:blur:size"),
        ("gaps", "general:gaps_out"),
        ("active_opacity", "decoration:active_opacity"),
        ("inactive_opacity", "decoration:inactive_opacity"),
        ("border", "general:border_size"),
        ("shadow", "decoration:shadow:enabled"),
    ];

    let mut map = serde_json::Map::new();

    for (label, opt_name) in opts {
        let cmd = format!("j/getoption {}\n", opt_name);
        if let Ok(raw) = send_raw_hypr_cmd(&cmd).await {
            if let Ok(parsed) = serde_json::from_str::<Value>(&raw) {
                if let Some(int_val) = parsed.get("int").and_then(|v| v.as_i64()) {
                    if label == "shadow" {
                        map.insert(label.to_string(), json!(int_val != 0));
                    } else {
                        map.insert(label.to_string(), json!(int_val));
                    }
                } else if let Some(float_val) = parsed.get("float").and_then(|v| v.as_f64()) {
                    map.insert(label.to_string(), json!(float_val));
                } else if let Some(bool_val) = parsed.get("bool").and_then(|v| v.as_bool()) {
                    map.insert(label.to_string(), json!(bool_val));
                } else if let Some(css_val) = parsed.get("css").and_then(|v| v.as_str()) {
                    let first = css_val.split_whitespace().next().unwrap_or("0");
                    let num: i64 = first.parse().unwrap_or(0);
                    map.insert(label.to_string(), json!(num));
                } else if let Some(custom_val) = parsed.get("custom").and_then(|v| v.as_str()) {
                    let first = custom_val.split_whitespace().next().unwrap_or("0");
                    let num: i64 = first.parse().unwrap_or(0);
                    map.insert(label.to_string(), json!(num));
                }
            }
        }
    }

    Value::Object(map)
}

// ---------------------------------------------------------------------------
// MATUGEN & WALLPAPER HANDLERS
// ---------------------------------------------------------------------------
async fn run_matugen(scheme: &str, wall_path: Option<&str>) {
    let cfg = config_dir();
    let _ = fs::write(cfg.join("scheme_state"), format!("{}\n", scheme));
    let theme_mk = cfg.join("scripts/theme-mk.py");
    let wp = if let Some(p) = wall_path {
        p.to_string()
    } else {
        let wp_state = cfg.join("current_wallpaper_path");
        fs::read_to_string(&wp_state).unwrap_or_default().trim().to_string()
    };

    if theme_mk.exists() {
        let mut cmd = Command::new("python3");
        cmd.arg(&theme_mk);
        if !wp.is_empty() {
            cmd.arg(&wp);
        }
        cmd.args(["--scheme", scheme]);
        let _ = cmd.spawn();
    } else {
        let mat_type = match scheme.to_lowercase().as_str() {
            "expressive" => "scheme-expressive",
            "fidelity" => "scheme-fidelity",
            "monochrome" => "scheme-monochrome",
            _ => "scheme-tonal-spot",
        };
        let _ = Command::new("matugen")
            .args(["image", &wp, "-t", mat_type, "-m", "dark", "-j", "hex"])
            .spawn();
    }
}

async fn apply_wallpaper(path: &str) {
    let cfg = config_dir();
    let apply_script = cfg.join("scripts/wp-apply.sh");
    let state_file = cfg.join("current_wallpaper_path");
    let hypr_state_file = home_dir().join(".config/hypr/current_wallpaper_path");

    // Update state files immediately
    let _ = fs::write(&state_file, path);
    let _ = fs::write(&hypr_state_file, path);

    if apply_script.exists() {
        let _ = Command::new("bash")
            .arg(&apply_script)
            .arg(path)
            .spawn();
    } else {
        let wallhaven = cfg.join("scripts/wallhaven.py");
        if wallhaven.exists() {
            let _ = Command::new("python3")
                .args([wallhaven.to_str().unwrap(), "apply", path])
                .spawn();
        }
    }
}

fn collect_wallpapers_from_dirs(include_video: bool) -> Vec<PathBuf> {
    let mut dirs = vec![
        home_dir().join("Pictures/Wallpapers"),
        config_dir().join("assets/wallpapers"),
        home_dir().join(".local/share/quickshell/carbon/assets/wallpapers"),
        home_dir().join(".local/share/wallpapers"),
    ];
    let mut results = Vec::new();
    let mut visited = std::collections::HashSet::new();
    while let Some(dir) = dirs.pop() {
        if !dir.exists() {
            continue;
        }
        if let Ok(rd) = fs::read_dir(&dir) {
            for entry in rd.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    dirs.push(path);
                } else if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
                    let ext = ext.to_lowercase();
                    let allowed = if include_video {
                        ["jpg", "jpeg", "png", "webp", "avif", "mp4", "mkv", "webm"].contains(&ext.as_str())
                    } else {
                        ["jpg", "jpeg", "png", "webp", "avif"].contains(&ext.as_str())
                    };
                    if allowed {
                        let s = path.to_string_lossy().to_string();
                        if visited.insert(s) {
                            results.push(path);
                        }
                    }
                }
            }
        }
    }
    results
}

async fn shuffle_wallpaper() -> Option<String> {
    let entries = collect_wallpapers_from_dirs(false);
    if entries.is_empty() {
        return None;
    }

    use std::time::SystemTime;
    let nanos = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().subsec_nanos();
    let idx = (nanos as usize) % entries.len();
    let chosen = entries[idx].to_string_lossy().to_string();
    apply_wallpaper(&chosen).await;
    Some(chosen)
}

fn list_local_wallpapers() -> Value {
    let thumb_dir = home_dir().join(".cache/carbon/thumbs");
    let mut list = Vec::new();

    for path in collect_wallpapers_from_dirs(true) {
        let fname = path.file_name().map(|f| f.to_string_lossy().to_string()).unwrap_or_default();
        let thumb_path = thumb_dir.join(format!("{}.jpg", fname));
        let thumb_url = if thumb_path.exists() {
            format!("file://{}", thumb_path.to_string_lossy())
        } else {
            format!("file://{}", path.to_string_lossy())
        };
        list.push(json!({
            "id": fname,
            "path": path.to_string_lossy(),
            "thumb": thumb_url,
            "filename": fname
        }));
    }

    json!(list)
}

// ---------------------------------------------------------------------------
// DISPLAY & MONITOR HANDLERS
// ---------------------------------------------------------------------------
async fn get_hypr_monitors() -> Value {
    if let Ok(raw) = send_raw_hypr_cmd("j/monitors").await {
        if let Ok(parsed) = serde_json::from_str::<Value>(&raw) {
            return parsed;
        }
    }
    if let Ok(out) = Command::new("hyprctl").args(["monitors", "-j"]).output().await {
        if let Ok(parsed) = serde_json::from_slice::<Value>(&out.stdout) {
            return parsed;
        }
    }
    json!([])
}

async fn set_monitor_resolution(name: &str, w: i64, h: i64, rate: Option<f64>) -> Result<(), String> {
    let monitors = get_hypr_monitors().await;
    let mut current_pos = "auto".to_string();
    let mut current_scale = 1.0;
    let mut current_transform = 0;
    let mut current_rate = 60.0;

    if let Some(arr) = monitors.as_array() {
        for m in arr {
            if m.get("name").and_then(|v| v.as_str()) == Some(name) {
                if let (Some(x), Some(y)) = (m.get("x").and_then(|v| v.as_i64()), m.get("y").and_then(|v| v.as_i64())) {
                    current_pos = format!("{}x{}", x, y);
                }
                if let Some(s) = m.get("scale").and_then(|v| v.as_f64()) {
                    current_scale = s;
                }
                if let Some(t) = m.get("transform").and_then(|v| v.as_i64()) {
                    current_transform = t;
                }
                if let Some(r) = m.get("refreshRate").and_then(|v| v.as_f64()) {
                    current_rate = r;
                }
                break;
            }
        }
    }

    let hz = rate.unwrap_or(current_rate);
    let mode = format!("{}x{}@{:.0}", w, h, hz);
    
    let lua_cmd = format!(
        "eval hl.monitor({{ output = \"{}\", mode = \"{}\", position = \"{}\", scale = {}, transform = {} }})",
        name, mode, current_pos, current_scale, current_transform
    );
    let res = send_raw_hypr_cmd(&lua_cmd).await;
    let fallback_cmd = format!("keyword monitor {},{},{},{},transform,{}", name, mode, current_pos, current_scale, current_transform);
    let _ = send_raw_hypr_cmd(&fallback_cmd).await;
    res.map(|_| ())
}

async fn set_monitor_orientation(name: &str, transform: i64) -> Result<(), String> {
    let monitors = get_hypr_monitors().await;
    let mut current_mode = "preferred".to_string();
    let mut current_pos = "auto".to_string();
    let mut current_scale = 1.0;

    if let Some(arr) = monitors.as_array() {
        for m in arr {
            if m.get("name").and_then(|v| v.as_str()) == Some(name) {
                if let (Some(w), Some(h), Some(r)) = (
                    m.get("width").and_then(|v| v.as_i64()),
                    m.get("height").and_then(|v| v.as_i64()),
                    m.get("refreshRate").and_then(|v| v.as_f64()),
                ) {
                    current_mode = format!("{}x{}@{:.0}", w, h, r);
                }
                if let (Some(x), Some(y)) = (m.get("x").and_then(|v| v.as_i64()), m.get("y").and_then(|v| v.as_i64())) {
                    current_pos = format!("{}x{}", x, y);
                }
                if let Some(s) = m.get("scale").and_then(|v| v.as_f64()) {
                    current_scale = s;
                }
                break;
            }
        }
    }

    let lua_cmd = format!(
        "eval hl.monitor({{ output = \"{}\", mode = \"{}\", position = \"{}\", scale = {}, transform = {} }})",
        name, current_mode, current_pos, current_scale, transform
    );
    let res = send_raw_hypr_cmd(&lua_cmd).await;
    let fallback_cmd = format!("keyword monitor {},{},{},{},transform,{}", name, current_mode, current_pos, current_scale, transform);
    let _ = send_raw_hypr_cmd(&fallback_cmd).await;
    res.map(|_| ())
}

async fn set_monitor_scale(name: &str, scale: f64) -> Result<(), String> {
    let monitors = get_hypr_monitors().await;
    let mut current_mode = "preferred".to_string();
    let mut current_pos = "auto".to_string();
    let mut current_transform = 0;

    if let Some(arr) = monitors.as_array() {
        for m in arr {
            if m.get("name").and_then(|v| v.as_str()) == Some(name) {
                if let (Some(w), Some(h), Some(r)) = (
                    m.get("width").and_then(|v| v.as_i64()),
                    m.get("height").and_then(|v| v.as_i64()),
                    m.get("refreshRate").and_then(|v| v.as_f64()),
                ) {
                    current_mode = format!("{}x{}@{:.0}", w, h, r);
                }
                if let (Some(x), Some(y)) = (m.get("x").and_then(|v| v.as_i64()), m.get("y").and_then(|v| v.as_i64())) {
                    current_pos = format!("{}x{}", x, y);
                }
                if let Some(t) = m.get("transform").and_then(|v| v.as_i64()) {
                    current_transform = t;
                }
                break;
            }
        }
    }

    let lua_cmd = format!(
        "eval hl.monitor({{ output = \"{}\", mode = \"{}\", position = \"{}\", scale = {:.2}, transform = {} }})",
        name, current_mode, current_pos, scale, current_transform
    );
    let res = send_raw_hypr_cmd(&lua_cmd).await;
    let fallback_cmd = format!("keyword monitor {},{},{},{:.2},transform,{}", name, current_mode, current_pos, scale, current_transform);
    let _ = send_raw_hypr_cmd(&fallback_cmd).await;
    res.map(|_| ())
}

async fn set_vrr(state: i64) -> Result<(), String> {
    let lua_cmd = format!("eval hl.config({{ misc = {{ vrr = {} }} }})", state);
    let res = send_raw_hypr_cmd(&lua_cmd).await;
    let fallback_cmd = format!("keyword misc:vrr {}", state);
    let _ = send_raw_hypr_cmd(&fallback_cmd).await;
    res.map(|_| ())
}

async fn set_temperature(temp: i64) {
    if temp >= 6500 {
        let _ = Command::new("pkill").args(["-x", "hyprsunset"]).spawn();
        let _ = Command::new("pkill").args(["-x", "wlsunset"]).spawn();
        let _ = Command::new("pkill").args(["-x", "gammastep"]).spawn();
    } else {
        let _ = Command::new("pkill").args(["-x", "hyprsunset"]).status().await;
        if Command::new("hyprsunset").arg("-t").arg(temp.to_string()).spawn().is_err() {
            let _ = Command::new("pkill").args(["-x", "wlsunset"]).status().await;
            let _ = Command::new("wlsunset").args(["-T", &(temp + 100).to_string(), "-t", &temp.to_string()]).spawn();
        }
    }
}

async fn resolve_monitor_defaults(req_mon: Option<String>, req_w: Option<i64>, req_h: Option<i64>) -> (String, i64, i64) {
    let monitors = get_hypr_monitors().await;
    let mut resolved_name = req_mon;
    let mut resolved_w = req_w;
    let mut resolved_h = req_h;

    if let Some(arr) = monitors.as_array() {
        let target = if let Some(ref m_name) = resolved_name {
            arr.iter().find(|m| m.get("name").and_then(|v| v.as_str()) == Some(m_name))
        } else {
            arr.iter().find(|m| m.get("focused").and_then(|v| v.as_bool()).unwrap_or(false))
                .or_else(|| arr.first())
        };

        if let Some(target) = target {
            if resolved_name.is_none() {
                if let Some(n) = target.get("name").and_then(|v| v.as_str()) {
                    resolved_name = Some(n.to_string());
                }
            }
            if resolved_w.is_none() {
                resolved_w = target.get("width").and_then(|v| v.as_i64());
            }
            if resolved_h.is_none() {
                resolved_h = target.get("height").and_then(|v| v.as_i64());
            }
        }
    }

    (
        resolved_name.unwrap_or_else(|| "default".into()),
        resolved_w.unwrap_or(1920),
        resolved_h.unwrap_or(1080),
    )
}

async fn set_shell_scale(scale: f64) -> Result<(), String> {
    let cfg = config_dir();
    let bar_pos_file = cfg.join("carbon-bar-position.json");
    let hypr_bar_pos_file = home_dir().join(".config/hypr/carbon-bar-position.json");
    
    let mut data: Value = if bar_pos_file.exists() {
        let content = fs::read_to_string(&bar_pos_file).unwrap_or_default();
        serde_json::from_str(&content).unwrap_or_else(|_| json!({}))
    } else {
        json!({})
    };
    
    if let Some(obj) = data.as_object_mut() {
        obj.insert("scale".to_string(), json!(scale));
    }
    
    let formatted = serde_json::to_string_pretty(&data).map_err(|e| e.to_string())?;
    let _ = fs::write(&bar_pos_file, &formatted);
    let _ = fs::write(&hypr_bar_pos_file, &formatted);
    Ok(())
}

async fn get_shell_scale() -> f64 {
    let cfg = config_dir();
    let bar_pos_file = cfg.join("carbon-bar-position.json");
    if bar_pos_file.exists() {
        if let Ok(content) = fs::read_to_string(&bar_pos_file) {
            if let Ok(data) = serde_json::from_str::<Value>(&content) {
                if let Some(s) = data.get("scale").and_then(|v| v.as_f64()) {
                    return s;
                }
            }
        }
    }
    1.0
}

// ---------------------------------------------------------------------------
// MESSAGE ROUTER
// ---------------------------------------------------------------------------
async fn handle_request(req: HubRequest) -> HubResponse {
    let t0 = Instant::now();
    let action = req.action.clone();

    match req.action.as_str() {
        "set_blur" => {
            let val = req.value.and_then(|v| v.as_f64()).unwrap_or(5.0) as i64;
            match set_hypr_option("blur", &val.to_string()).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "blur": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_gaps" => {
            let val = req.value.and_then(|v| v.as_f64()).unwrap_or(6.0) as i64;
            match set_hypr_option("gaps", &val.to_string()).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "gaps": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_active_opacity" => {
            let val = req.value.and_then(|v| v.as_f64()).unwrap_or(1.0);
            match set_hypr_option("active_opacity", &format!("{:.2}", val)).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "active_opacity": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_inactive_opacity" => {
            let val = req.value.and_then(|v| v.as_f64()).unwrap_or(1.0);
            match set_hypr_option("inactive_opacity", &format!("{:.2}", val)).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "inactive_opacity": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_border" => {
            let val = req.value.and_then(|v| v.as_f64()).unwrap_or(1.0) as i64;
            match set_hypr_option("border", &val.to_string()).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "border": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_shadow" => {
            let val = req.value.and_then(|v| v.as_bool()).unwrap_or(true);
            match set_hypr_option("shadow", if val { "true" } else { "false" }).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "shadow": val })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_ambient_glow" => {
            let val = req.value.and_then(|v| v.as_bool()).unwrap_or(false);
            let cfg = config_dir();
            let state_file = cfg.join("ambient_glow_state");
            let _ = fs::write(&state_file, if val { "1\n" } else { "0\n" });
            let audio_border = cfg.join("scripts/audio-border.py");
            if val {
                if audio_border.exists() {
                    let _ = Command::new("python3").arg(&audio_border).spawn();
                }
            } else {
                let _ = Command::new("pkill").args(["-f", "audio-border.py"]).spawn();
            }
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "ambient_glow": val })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_m3_transitions" => {
            let val = req.value.and_then(|v| v.as_bool()).unwrap_or(true);
            let state_file = config_dir().join("m3_transitions_state");
            let _ = fs::write(&state_file, if val { "1\n" } else { "0\n" });
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "m3_transitions": val })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "pause_live_bg" => {
            let pause = req.value.and_then(|v| v.as_bool()).unwrap_or(false);
            let signal = if pause { "-STOP" } else { "-CONT" };
            let _ = Command::new("pkill").args([signal, "-f", "mpvpaper|swww"]).spawn();
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "paused": pause })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_wallpaper" => {
            if let Some(path) = req.path {
                apply_wallpaper(&path).await;
                HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "path": path })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                }
            } else {
                HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some("Missing wallpaper path".into()),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                }
            }
        }
        "shuffle_wallpaper" => {
            let chosen = shuffle_wallpaper().await;
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "path": chosen })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_scheme" => {
            let s = req.scheme.unwrap_or_else(|| "Tonal Spot".into());
            run_matugen(&s, req.path.as_deref()).await;
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "scheme": s })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "get_state" => {
            let hypr = get_hypr_state().await;
            let current_wp = fs::read_to_string(config_dir().join("current_wallpaper_path"))
                .or_else(|_| fs::read_to_string(home_dir().join(".config/hypr/current_wallpaper_path")))
                .unwrap_or_default()
                .trim()
                .to_string();
            let wallpapers = list_local_wallpapers();

            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({
                    "hypr": hypr,
                    "current_wallpaper": current_wp,
                    "wallpapers": wallpapers
                })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "list_wallpapers" => {
            let list = list_local_wallpapers();
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(list),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "get_monitors" => {
            let monitors = get_hypr_monitors().await;
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(monitors),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_resolution" => {
            let (mon, w, h) = resolve_monitor_defaults(req.monitor, req.w, req.h).await;
            let rate = req.rate;
            match set_monitor_resolution(&mon, w, h, rate).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "monitor": mon, "w": w, "h": h, "rate": rate })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_orientation" => {
            let (mon, _, _) = resolve_monitor_defaults(req.monitor, None, None).await;
            let transform = req.transform.or_else(|| req.value.and_then(|v| v.as_i64())).unwrap_or(0);
            match set_monitor_orientation(&mon, transform).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "monitor": mon, "transform": transform })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_scale" => {
            let (mon, _, _) = resolve_monitor_defaults(req.monitor, None, None).await;
            let scale = req.scale.or_else(|| req.value.and_then(|v| v.as_f64())).unwrap_or(1.0);
            match set_monitor_scale(&mon, scale).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "monitor": mon, "scale": scale })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_shell_scale" => {
            let scale = req.scale.or_else(|| req.value.and_then(|v| v.as_f64())).unwrap_or(1.0);
            match set_shell_scale(scale).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "scale": scale })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "get_shell_scale" => {
            let scale = get_shell_scale().await;
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "scale": scale })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_vrr" => {
            let state = req.state.or_else(|| req.value.and_then(|v| v.as_i64())).unwrap_or(0);
            match set_vrr(state).await {
                Ok(_) => HubResponse {
                    status: "ok".into(),
                    action: Some(action),
                    data: Some(json!({ "state": state })),
                    error: None,
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
                Err(e) => HubResponse {
                    status: "error".into(),
                    action: Some(action),
                    data: None,
                    error: Some(e),
                    elapsed_us: Some(t0.elapsed().as_micros()),
                },
            }
        }
        "set_temperature" => {
            let temp = req.temp.or_else(|| req.value.and_then(|v| v.as_i64())).unwrap_or(6500);
            set_temperature(temp).await;
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "temp": temp })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "set_display_feature" => {
            let feat = req.feature.unwrap_or_default();
            let state = req.value.and_then(|v| v.as_bool()).unwrap_or(false);
            if feat == "direct_scanout" {
                let _ = send_raw_hypr_cmd(&format!("eval hl.config({{ render = {{ direct_scanout = {} }} }})", state)).await;
                let _ = send_raw_hypr_cmd(&format!("keyword render:direct_scanout {}", if state { 1 } else { 0 })).await;
            } else if feat == "10bit" {
                let monitors = get_hypr_monitors().await;
                if let Some(arr) = monitors.as_array() {
                    if let Some(m) = arr.first() {
                        let name = m.get("name").and_then(|v| v.as_str()).unwrap_or("eDP-1");
                        let w = m.get("width").and_then(|v| v.as_i64()).unwrap_or(1920);
                        let h = m.get("height").and_then(|v| v.as_i64()).unwrap_or(1080);
                        let r = m.get("refreshRate").and_then(|v| v.as_f64()).unwrap_or(60.0);
                        let x = m.get("x").and_then(|v| v.as_i64()).unwrap_or(0);
                        let y = m.get("y").and_then(|v| v.as_i64()).unwrap_or(0);
                        let s = m.get("scale").and_then(|v| v.as_f64()).unwrap_or(1.0);
                        if state {
                            let _ = send_raw_hypr_cmd(&format!("keyword monitor {},{}x{}@{:.0},{}x{},{:.2},bitdepth,10", name, w, h, r, x, y, s)).await;
                        } else {
                            let _ = send_raw_hypr_cmd(&format!("keyword monitor {},{}x{}@{:.0},{}x{},{:.2}", name, w, h, r, x, y, s)).await;
                        }
                    }
                }
            } else if feat == "mirror" {
                let monitors = get_hypr_monitors().await;
                if let Some(arr) = monitors.as_array() {
                    if arr.len() >= 2 {
                        let primary = arr[0].get("name").and_then(|v| v.as_str()).unwrap_or("eDP-1");
                        for m in arr.iter().skip(1) {
                            if let Some(sec_name) = m.get("name").and_then(|v| v.as_str()) {
                                if state {
                                    let _ = send_raw_hypr_cmd(&format!("keyword monitor {},preferred,auto,1,mirror,{}", sec_name, primary)).await;
                                } else {
                                    let _ = send_raw_hypr_cmd(&format!("keyword monitor {},preferred,auto,1", sec_name)).await;
                                }
                            }
                        }
                    }
                }
            }
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "feature": feat, "state": state })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "get_keybinds" => {
            let scope = req.scope.unwrap_or_else(|| "minimal".into());
            let rel_path = match scope.as_str() {
                "notch" => "configs/keybinds-notch.conf",
                "pill" => "configs/keybinds-pill.conf",
                "vanish" | "nucleus" => "configs/keybinds-vanish.conf",
                "shell" => "keybinds-shell-only.conf",
                "default" => "keybinds.conf",
                "gestures" => "configs/gestures.conf",
                _ => "configs/keybinds-minimal.conf",
            };
            let full_path = config_dir().join(rel_path);
            let mut binds = Vec::new();
            if let Ok(raw) = fs::read_to_string(&full_path) {
                for line in raw.lines() {
                    let s = line.trim();
                    if s.is_empty() || s.starts_with('#') || s.starts_with('$') || !s.contains('=') {
                        continue;
                    }
                    let mut split_eq = s.splitn(2, '=');
                    let btype = split_eq.next().unwrap_or("").trim();
                    let rhs = split_eq.next().unwrap_or("").split(" #").next().unwrap_or("").trim();
                    if !btype.starts_with("bind") {
                        continue;
                    }
                    let parts: Vec<&str> = rhs.split(',').map(|p| p.trim()).collect();
                    if parts.len() >= 3 {
                        let arg = if parts.len() > 3 { parts[3..].join(", ") } else { String::new() };
                        binds.push(json!({
                            "bindType": btype,
                            "mods": parts[0],
                            "key": parts[1],
                            "dispatcher": parts[2],
                            "arg": arg
                        }));
                    }
                }
            }
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({
                    "scope": scope,
                    "filePath": full_path.to_string_lossy(),
                    "binds": binds
                })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        "save_keybinds" => {
            let scope = req.scope.unwrap_or_else(|| "minimal".into());
            let rel_path = match scope.as_str() {
                "notch" => "configs/keybinds-notch.conf",
                "pill" => "configs/keybinds-pill.conf",
                "vanish" | "nucleus" => "configs/keybinds-vanish.conf",
                "shell" => "keybinds-shell-only.conf",
                "default" => "keybinds.conf",
                _ => "configs/keybinds-minimal.conf",
            };
            let mut lines = vec![
                "#################################################################".to_string(),
                format!("# CARBON SHELL — {} KEYBINDINGS", scope.to_uppercase()),
                format!("# File: ~/.config/carbon/{}", rel_path),
                "#################################################################".to_string(),
                String::new(),
                "$mainMod = SUPER".to_string(),
            ];
            if scope == "default" {
                lines.push("$terminal = kitty".to_string());
                lines.push("$fileManager = nautilus".to_string());
            }
            lines.push(String::new());
            if let Some(arr) = req.binds.or(req.value).and_then(|v| v.as_array().cloned()) {
                for b in arr {
                    let bt = b.get("bindType").and_then(|v| v.as_str()).unwrap_or("bind");
                    let mods = b.get("mods").and_then(|v| v.as_str()).unwrap_or("$mainMod");
                    let key = b.get("key").and_then(|v| v.as_str()).unwrap_or("");
                    let disp = b.get("dispatcher").and_then(|v| v.as_str()).unwrap_or("exec");
                    let arg = b.get("arg").and_then(|v| v.as_str()).unwrap_or("");
                    if key.is_empty() {
                        continue;
                    }
                    if arg.is_empty() {
                        lines.push(format!("{} = {}, {}, {},", bt, mods, key, disp));
                    } else {
                        lines.push(format!("{} = {}, {}, {}, {}", bt, mods, key, disp, arg));
                    }
                }
            }
            let content = lines.join("\n") + "\n";
            for base in [config_dir(), home_dir().join(".config/hypr")] {
                let dst = base.join(rel_path);
                if let Some(parent) = dst.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                let _ = fs::write(&dst, &content);
            }
            let mode_sh = config_dir().join("scripts/carbon-mode-keybinds.sh");
            if mode_sh.exists() {
                let _ = Command::new("bash").arg(&mode_sh).spawn();
            } else {
                let _ = send_raw_hypr_cmd("reload").await;
            }
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "scope": scope, "relPath": rel_path })),
                error: None,
                elapsed_us: Some(t0.elapsed().as_micros()),
            }
        }
        other => HubResponse {
            status: "error".into(),
            action: Some(action),
            data: None,
            error: Some(format!("Unknown action: {}", other)),
            elapsed_us: Some(t0.elapsed().as_micros()),
        },
    }
}

// ---------------------------------------------------------------------------
// MAIN DAEMON LISTENER
// ---------------------------------------------------------------------------
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Ensure old socket is removed
    if Path::new(SOCKET_PATH).exists() {
        let _ = fs::remove_file(SOCKET_PATH);
    }

    let listener = UnixListener::bind(SOCKET_PATH)?;
    println!("[carbon-hub-daemon] Listening on {}", SOCKET_PATH);

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                tokio::spawn(async move {
                    let (reader_half, mut writer_half) = stream.into_split();
                    let mut lines = BufReader::new(reader_half).lines();

                    while let Ok(Some(line)) = lines.next_line().await {
                        let line = line.trim();
                        if line.is_empty() {
                            continue;
                        }

                        match serde_json::from_str::<HubRequest>(line) {
                            Ok(req) => {
                                let resp = handle_request(req).await;
                                if let Ok(resp_json) = serde_json::to_string(&resp) {
                                    let mut out = resp_json.into_bytes();
                                    out.push(b'\n');
                                    let _ = writer_half.write_all(&out).await;
                                    let _ = writer_half.flush().await;
                                }
                            }
                            Err(e) => {
                                let err_resp = HubResponse {
                                    status: "error".into(),
                                    action: None,
                                    data: None,
                                    error: Some(format!("JSON parse error: {}", e)),
                                    elapsed_us: None,
                                };
                                if let Ok(resp_json) = serde_json::to_string(&err_resp) {
                                    let mut out = resp_json.into_bytes();
                                    out.push(b'\n');
                                    let _ = writer_half.write_all(&out).await;
                                    let _ = writer_half.flush().await;
                                }
                            }
                        }
                    }
                });
            }
            Err(e) => {
                eprintln!("[carbon-hub-daemon] Accept error: {}", e);
            }
        }
    }
}
