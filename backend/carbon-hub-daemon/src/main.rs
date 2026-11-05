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
    let script = cfg.join("scripts/matugen-scheme.sh");
    if script.exists() {
        let _ = Command::new("bash")
            .arg(&script)
            .arg(scheme)
            .spawn();
    } else {
        let wp = if let Some(p) = wall_path {
            p.to_string()
        } else {
            let wp_state = cfg.join("current_wallpaper_path");
            fs::read_to_string(&wp_state).unwrap_or_default().trim().to_string()
        };
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

async fn shuffle_wallpaper() -> Option<String> {
    let wp_dir = home_dir().join("Pictures/Wallpapers");
    if !wp_dir.exists() {
        return None;
    }

    let mut entries = Vec::new();
    if let Ok(rd) = fs::read_dir(&wp_dir) {
        for entry in rd.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
                let ext = ext.to_lowercase();
                if ["jpg", "jpeg", "png", "webp", "avif"].contains(&ext.as_str()) {
                    entries.push(path.to_string_lossy().to_string());
                }
            }
        }
    }

    if entries.is_empty() {
        return None;
    }

    use std::time::SystemTime;
    let nanos = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().subsec_nanos();
    let idx = (nanos as usize) % entries.len();
    let chosen = entries[idx].clone();
    apply_wallpaper(&chosen).await;
    Some(chosen)
}

fn list_local_wallpapers() -> Value {
    let wp_dir = home_dir().join("Pictures/Wallpapers");
    let thumb_dir = home_dir().join(".cache/carbon/thumbs");
    let mut list = Vec::new();

    if let Ok(rd) = fs::read_dir(&wp_dir) {
        for entry in rd.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
                let ext = ext.to_lowercase();
                if ["jpg", "jpeg", "png", "webp", "avif", "mp4", "mkv", "webm"].contains(&ext.as_str()) {
                    let fname = entry.file_name().to_string_lossy().to_string();
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
            }
        }
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
    } else {
        let _ = Command::new("pkill").args(["-x", "hyprsunset"]).status().await;
        let _ = Command::new("hyprsunset").arg("-t").arg(temp.to_string()).spawn();
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
            let state_file = config_dir().join("ambient_glow_state");
            let _ = fs::write(state_file, if val { "1\n" } else { "0\n" });
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "ambient_glow": val })),
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
            }
            HubResponse {
                status: "ok".into(),
                action: Some(action),
                data: Some(json!({ "feature": feat, "state": state })),
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
