use chrono::{DateTime, Datelike, Duration as ChronoDuration, Local, Utc};
use reqwest::header::{ACCEPT, AUTHORIZATION, USER_AGENT};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::Mutex;
use tokio::time::sleep;

// ─────────────────────────────────────────────────────────────────────────────
// Core Data Models
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct NoteItem {
    pub name: String,
    pub path: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ClipboardItem {
    pub id: String,
    pub preview: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AgendaItem {
    pub date: String,
    pub title: String,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub raw_date: Option<String>,
    #[serde(default)]
    pub time: Option<String>,
    #[serde(default)]
    pub r#type: Option<String>,
    #[serde(default)]
    pub is_user: Option<bool>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ContributionDay {
    pub date: String,
    pub count: u32,
    pub level: u8, // 0 (empty), 1 (dim), 2 (soft mint), 3 (mint), 4 (amber)
    #[serde(default)]
    pub is_future: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ContributionWeek {
    pub month_label: String,
    pub days: Vec<ContributionDay>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PullRequestItem {
    pub number: u64,
    pub title: String,
    pub repo: String,
    pub author: String,
    pub url: String,
    pub state: String,
    pub created_at: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RepositoryItem {
    pub name: String,
    pub full_name: String,
    pub owner: String,
    pub url: String,
    pub description: String,
    pub stars: u32,
    pub language: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WorkspaceStatus {
    pub repo_name: String,
    pub branch: String,
    pub dirty: bool,
    pub ahead: u32,
    pub behind: u32,
    pub last_commit: String,
    pub sync_status: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct GitHubPayload {
    pub authenticated: bool,
    pub username: String,
    pub total_contributions: u32,
    pub contributions: Vec<ContributionDay>,
    #[serde(default)]
    pub weeks: Vec<ContributionWeek>,
    pub pull_requests: Vec<PullRequestItem>,
    pub repositories: Vec<RepositoryItem>,
    pub workspace: WorkspaceStatus,
    pub feedback: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct CpuCore {
    pub id: usize,
    pub usage: f32,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct SystemTelemetryPayload {
    pub cpu_usage: f32,
    pub cpu_cores: Vec<CpuCore>,
    pub cpu_temp: f32,
    pub ram_used_bytes: u64,
    pub ram_total_bytes: u64,
    pub swap_used_bytes: u64,
    pub swap_total_bytes: u64,
    pub net_rx_bps: u64,
    pub net_tx_bps: u64,
    pub kernel_version: String,
    pub uptime_seconds: u64,
    pub uptime_formatted: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct BlueprintWindow {
    pub address: String,
    pub class: String,
    pub title: String,
    pub at: [f32; 2],
    pub size: [f32; 2],
    pub is_focused: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct BlueprintWorkspace {
    pub id: i32,
    pub name: String,
    pub is_active: bool,
    pub has_windows: bool,
    pub windows: Vec<BlueprintWindow>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RadarPayload {
    pub vault: Vec<NoteItem>,
    pub clipboard: Vec<ClipboardItem>,
    pub apps: Vec<String>,
    pub agenda: Vec<AgendaItem>,
    pub github: GitHubPayload,
    pub telemetry: SystemTelemetryPayload,
    #[serde(default)]
    pub workspaces: Vec<BlueprintWorkspace>,
    #[serde(default)]
    pub active_workspace_id: i32,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct CarbonSettings {
    pub github_token: Option<String>,
    pub github_username: Option<String>,
    pub workspace_dir: Option<String>,
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Identity & Environment Detection
// ─────────────────────────────────────────────────────────────────────────────

fn get_home_dir() -> String {
    env::var("HOME").unwrap_or_else(|_| ".".to_string())
}

fn extract_user_from_remote_url(url: &str) -> Option<String> {
    let clean = url.trim();
    if clean.is_empty() {
        return None;
    }

    if let Some(rest) = clean.strip_prefix("git@github.com:") {
        let repo_part = rest.strip_suffix(".git").unwrap_or(rest);
        if let Some((user, _)) = repo_part.split_once('/') {
            return Some(user.to_string());
        }
    }

    if let Some(pos) = clean.find("github.com/") {
        let rest = &clean[pos + "github.com/".len()..];
        let repo_part = rest.strip_suffix(".git").unwrap_or(rest);
        if let Some((user, _)) = repo_part.split_once('/') {
            return Some(user.to_string());
        }
    }

    None
}

fn detect_github_username(workspace_dir: &str) -> String {
    // 1. git config github.user
    if let Ok(out) = Command::new("git")
        .arg("config")
        .arg("--get")
        .arg("github.user")
        .output()
    {
        let u = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !u.is_empty() {
            return u;
        }
    }

    // 2. Parse from workspace remote URL
    if !workspace_dir.is_empty() {
        if let Ok(out) = Command::new("git")
            .arg("-C")
            .arg(workspace_dir)
            .arg("config")
            .arg("--get")
            .arg("remote.origin.url")
            .output()
        {
            let url = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if let Some(user) = extract_user_from_remote_url(&url) {
                return user;
            }
        }
    }

    // 3. git config user.name
    if let Ok(out) = Command::new("git")
        .arg("config")
        .arg("--get")
        .arg("user.name")
        .output()
    {
        let u = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !u.is_empty() {
            return u;
        }
    }

    // 4. System user environment
    if let Ok(u) = env::var("GITHUB_USER")
        .or_else(|_| env::var("GH_USER"))
        .or_else(|_| env::var("USER"))
    {
        let trimmed = u.trim().to_string();
        if !trimmed.is_empty() {
            return trimmed;
        }
    }

    "developer".to_string()
}

fn detect_workspace_dir(home: &str) -> String {
    // 1. Check ~/.config/carbon/repo_path
    let repo_path = PathBuf::from(home).join(".config/carbon/repo_path");
    if let Ok(content) = fs::read_to_string(repo_path) {
        let trimmed = content.trim().to_string();
        if !trimmed.is_empty() && Path::new(&trimmed).is_dir() {
            return trimmed;
        }
    }

    // 2. Check git rev-parse --show-toplevel
    if let Ok(out) = Command::new("git")
        .arg("rev-parse")
        .arg("--show-toplevel")
        .output()
    {
        let top = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !top.is_empty() && Path::new(&top).is_dir() {
            return top;
        }
    }

    // 3. Check <home>/carbon-shell
    let default_shell = PathBuf::from(home).join("carbon-shell");
    if default_shell.is_dir() {
        return default_shell.to_string_lossy().to_string();
    }

    // 4. Current directory
    if let Ok(curr) = env::current_dir() {
        return curr.to_string_lossy().to_string();
    }

    home.to_string()
}

fn load_settings() -> CarbonSettings {
    let home = get_home_dir();
    let path = PathBuf::from(&home).join(".config/carbon/settings.json");
    let mut settings = if let Ok(content) = fs::read_to_string(&path) {
        serde_json::from_str::<CarbonSettings>(&content).unwrap_or_default()
    } else {
        CarbonSettings::default()
    };

    if settings
        .github_token
        .as_ref()
        .map_or(true, |t| t.trim().is_empty())
    {
        if let Ok(tok) = env::var("GITHUB_TOKEN").or_else(|_| env::var("GH_TOKEN")) {
            if !tok.trim().is_empty() {
                settings.github_token = Some(tok.trim().to_string());
            }
        }
    }

    if settings
        .workspace_dir
        .as_ref()
        .map_or(true, |d| d.trim().is_empty())
    {
        settings.workspace_dir = Some(detect_workspace_dir(&home));
    }

    if settings
        .github_username
        .as_ref()
        .map_or(true, |u| u.trim().is_empty())
    {
        let ws = settings.workspace_dir.as_deref().unwrap_or("");
        settings.github_username = Some(detect_github_username(ws));
    }

    settings
}

// ─────────────────────────────────────────────────────────────────────────────
// Obsidian, Clipboard & Agenda
// ─────────────────────────────────────────────────────────────────────────────

fn scan_markdown_files(dir: &Path, files: &mut Vec<(SystemTime, PathBuf)>) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            let file_name = entry.file_name();
            let name_str = file_name.to_string_lossy();
            if name_str.starts_with('.') {
                continue;
            }
            if path.is_dir() {
                scan_markdown_files(&path, files);
            } else if path.is_file() {
                if let Some(ext) = path.extension() {
                    if ext.eq_ignore_ascii_case("md") {
                        let mtime = entry
                            .metadata()
                            .and_then(|m| m.modified())
                            .unwrap_or(SystemTime::UNIX_EPOCH);
                        files.push((mtime, path));
                    }
                }
            }
        }
    }
}

fn fetch_obsidian_notes() -> Vec<NoteItem> {
    let home = get_home_dir();
    let candidate_dirs = [
        format!("{}/Documents/Obsidian", home),
        format!("{}/Documents/Obsidian Vault", home),
        format!("{}/Obsidian", home),
        format!("{}/Documents", home),
    ];

    let mut found_files = Vec::new();
    for cand in candidate_dirs.iter() {
        let p = Path::new(cand);
        if p.is_dir() {
            scan_markdown_files(p, &mut found_files);
            if !found_files.is_empty() {
                break;
            }
        }
    }

    found_files.sort_by(|a, b| b.0.cmp(&a.0));
    let mut notes = Vec::new();
    let mut seen_paths = HashSet::new();
    for (_, path) in found_files.into_iter().take(20) {
        let path_str = path.to_string_lossy().to_string();
        if seen_paths.insert(path_str.clone()) {
            let name = path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| "note.md".to_string());
            notes.push(NoteItem {
                name,
                path: path_str,
            });
        }
    }

    notes
}

fn fetch_clipboard() -> Vec<ClipboardItem> {
    let output = Command::new("sh")
        .arg("-c")
        .arg("cliphist list 2>/dev/null | head -n 15")
        .output();

    let mut items = Vec::new();
    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout);
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            if let Some((id, rest)) = trimmed.split_once('\t') {
                items.push(ClipboardItem {
                    id: id.trim().to_string(),
                    preview: rest.trim().to_string(),
                });
            } else if let Some((id, rest)) = trimmed.split_once(' ') {
                items.push(ClipboardItem {
                    id: id.trim().to_string(),
                    preview: rest.trim().to_string(),
                });
            } else {
                items.push(ClipboardItem {
                    id: "".to_string(),
                    preview: trimmed.to_string(),
                });
            }
        }
    }

    items
}

fn fetch_agenda() -> Vec<AgendaItem> {
    let home = get_home_dir();
    let agenda_path = format!("{}/.config/carbon/agenda.json", home);

    let mut items = Vec::new();
    if let Ok(content) = fs::read_to_string(&agenda_path) {
        if let Ok(parsed) = serde_json::from_str::<Vec<AgendaItem>>(&content) {
            items = parsed;
        }
    }

    if items.is_empty() {
        let cal_script = format!("{}/carbon-shell/hypr/scripts/carbon-calendar.py", home);
        let cal_script_alt = format!("{}/.config/hypr/scripts/carbon-calendar.py", home);
        let script = if Path::new(&cal_script).exists() {
            Some(cal_script)
        } else if Path::new(&cal_script_alt).exists() {
            Some(cal_script_alt)
        } else {
            None
        };

        if let Some(s) = script {
            if let Ok(output) = Command::new("python3").arg(&s).arg("--agenda").output() {
                if let Ok(parsed) = serde_json::from_slice::<Vec<AgendaItem>>(&output.stdout) {
                    items = parsed;
                }
            }
        }
    }

    let now = chrono::Local::now();
    let cur_ym = now.format("%Y-%m").to_string();
    let cur_month_abbr = now.format("%b").to_string();

    items
        .into_iter()
        .filter(|item| {
            if let Some(ref rd) = item.raw_date {
                rd.starts_with(&cur_ym)
            } else {
                item.date.starts_with(&cur_month_abbr)
            }
        })
        .collect()
}

// ─────────────────────────────────────────────────────────────────────────────
// Hyprland Socket2 IPC & App Usage
// ─────────────────────────────────────────────────────────────────────────────

fn is_ignored_class(cls: &str) -> bool {
    let lower = cls.trim().to_lowercase();
    lower.is_empty()
        || lower == "nil"
        || lower == "null"
        || lower.contains("quickshell")
        || lower.contains("carbon-shell")
        || lower.contains("xwaylandvideobridge")
        || lower.contains("desktop-portal")
        || lower.contains("hyprlock")
        || lower.contains("rofi")
        || lower.contains("wofi")
        || lower.contains("fuzzel")
}

fn get_usage_file_path() -> PathBuf {
    let home = get_home_dir();
    PathBuf::from(home).join(".config/carbon/app_usage.json")
}

fn load_app_usage(path: &Path) -> HashMap<String, u32> {
    if let Ok(content) = fs::read_to_string(path) {
        if let Ok(map) = serde_json::from_str::<HashMap<String, u32>>(&content) {
            return map;
        }
    }
    HashMap::new()
}

fn save_app_usage(path: &Path, tally: &HashMap<String, u32>) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json_str) = serde_json::to_string_pretty(tally) {
        let tmp_path = path.with_extension("json.tmp");
        if fs::write(&tmp_path, json_str.as_bytes()).is_ok() {
            let _ = fs::rename(&tmp_path, path);
        } else {
            let _ = fs::write(path, json_str.as_bytes());
        }
    }
}

fn seed_from_clients(tally: &mut HashMap<String, u32>) {
    let output = Command::new("hyprctl").arg("clients").arg("-j").output();

    if let Ok(out) = output {
        if let Ok(json_val) = serde_json::from_slice::<serde_json::Value>(&out.stdout) {
            if let Some(arr) = json_val.as_array() {
                for item in arr {
                    if let Some(cls) = item.get("class").and_then(|c| c.as_str()) {
                        let trimmed = cls.trim();
                        if !is_ignored_class(trimmed) {
                            tally.entry(trimmed.to_string()).or_insert(1);
                        }
                    }
                }
            }
        }
    }
}

fn find_socket2_path() -> Option<PathBuf> {
    if let Ok(sig) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        if let Ok(xdg) = env::var("XDG_RUNTIME_DIR") {
            let p = PathBuf::from(&xdg).join("hypr").join(&sig).join(".socket2.sock");
            if p.exists() {
                return Some(p);
            }
        }
        let p = PathBuf::from("/tmp/hypr").join(&sig).join(".socket2.sock");
        if p.exists() {
            return Some(p);
        }
    }

    if let Ok(xdg) = env::var("XDG_RUNTIME_DIR") {
        let hypr_dir = PathBuf::from(&xdg).join("hypr");
        if let Ok(entries) = fs::read_dir(hypr_dir) {
            for entry in entries.flatten() {
                let p = entry.path().join(".socket2.sock");
                if p.exists() {
                    return Some(p);
                }
            }
        }
    }

    let tmp_hypr = Path::new("/tmp/hypr");
    if let Ok(entries) = fs::read_dir(tmp_hypr) {
        for entry in entries.flatten() {
            let p = entry.path().join(".socket2.sock");
            if p.exists() {
                return Some(p);
            }
        }
    }

    None
}

#[derive(Deserialize, Debug, Default)]
struct HyprMonitorInfo {
    #[serde(default)]
    width: i32,
    #[serde(default)]
    height: i32,
    #[serde(default)]
    focused: bool,
}

#[derive(Deserialize, Debug, Default)]
struct HyprWsRef {
    #[serde(default)]
    id: i32,
}

#[derive(Deserialize, Debug, Default)]
struct HyprClientInfo {
    #[serde(default)]
    address: String,
    #[serde(default)]
    at: [i32; 2],
    #[serde(default)]
    size: [i32; 2],
    #[serde(default)]
    workspace: Option<HyprWsRef>,
    #[serde(default)]
    class: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    mapped: bool,
    #[serde(default)]
    hidden: bool,
    #[serde(default, rename = "focusHistoryID")]
    focus_history_id: Option<i32>,
}

#[derive(Deserialize, Debug, Default)]
struct HyprActiveWsInfo {
    #[serde(default)]
    id: i32,
}

pub fn fetch_blueprint_workspaces() -> (Vec<BlueprintWorkspace>, i32) {
    let mut mon_width = 1366.0f32;
    let mut mon_height = 768.0f32;

    if let Ok(out) = Command::new("hyprctl").args(["monitors", "-j"]).output() {
        if let Ok(mons) = serde_json::from_slice::<Vec<HyprMonitorInfo>>(&out.stdout) {
            if let Some(m) = mons.iter().find(|m| m.focused).or_else(|| mons.first()) {
                if m.width > 0 && m.height > 0 {
                    mon_width = m.width as f32;
                    mon_height = m.height as f32;
                }
            }
        }
    }

    let mut active_id = 1;
    if let Ok(out) = Command::new("hyprctl").args(["activeworkspace", "-j"]).output() {
        if let Ok(ws) = serde_json::from_slice::<HyprActiveWsInfo>(&out.stdout) {
            if ws.id > 0 {
                active_id = ws.id;
            }
        }
    }

    let mut clients: Vec<HyprClientInfo> = Vec::new();
    if let Ok(out) = Command::new("hyprctl").args(["clients", "-j"]).output() {
        if let Ok(parsed) = serde_json::from_slice::<Vec<HyprClientInfo>>(&out.stdout) {
            clients = parsed;
        }
    }

    let mut workspaces = Vec::with_capacity(9);
    for id in 1..=9 {
        let is_active = id == active_id;
        let mut ws_windows = Vec::new();

        for c in &clients {
            if !c.mapped || c.hidden {
                continue;
            }
            if let Some(ref wref) = c.workspace {
                if wref.id == id {
                    let nx = (c.at[0] as f32 / mon_width).clamp(0.0, 1.0);
                    let ny = (c.at[1] as f32 / mon_height).clamp(0.0, 1.0);
                    let nw = (c.size[0] as f32 / mon_width).clamp(0.02, 1.0);
                    let nh = (c.size[1] as f32 / mon_height).clamp(0.02, 1.0);
                    let is_focused = c.focus_history_id == Some(0);

                    ws_windows.push(BlueprintWindow {
                        address: c.address.clone(),
                        class: c.class.clone(),
                        title: c.title.clone(),
                        at: [nx, ny],
                        size: [nw, nh],
                        is_focused,
                    });
                }
            }
        }

        let has_windows = !ws_windows.is_empty();
        workspaces.push(BlueprintWorkspace {
            id,
            name: id.to_string(),
            is_active,
            has_windows,
            windows: ws_windows,
        });
    }

    (workspaces, active_id)
}

async fn start_ipc_listener(
    tally: Arc<Mutex<HashMap<String, u32>>>,
    usage_path: PathBuf,
    blueprint_state: Arc<Mutex<(Vec<BlueprintWorkspace>, i32)>>,
) {
    let mut last_active = String::new();

    loop {
        if let Some(sock_path) = find_socket2_path() {
            if let Ok(stream) = tokio::net::UnixStream::connect(&sock_path).await {
                let mut reader = BufReader::new(stream).lines();
                while let Ok(Some(line)) = reader.next_line().await {
                    let trimmed = line.trim();
                    let mut class_to_record = None;
                    let mut update_blueprint = false;

                    if let Some(payload) = trimmed.strip_prefix("activewindow>>") {
                        let class = payload.split(',').next().unwrap_or("").trim();
                        if is_ignored_class(class) {
                            last_active.clear();
                        } else if class != last_active {
                            last_active = class.to_string();
                            class_to_record = Some(class.to_string());
                        }
                        update_blueprint = true;
                    } else if let Some(payload) = trimmed.strip_prefix("openwindow>>") {
                        let parts: Vec<&str> = payload.splitn(4, ',').collect();
                        if parts.len() >= 3 {
                            let class = parts[2].trim();
                            if !is_ignored_class(class) {
                                class_to_record = Some(class.to_string());
                            }
                        }
                        update_blueprint = true;
                    } else if trimmed.starts_with("closewindow>>")
                        || trimmed.starts_with("movewindow>>")
                        || trimmed.starts_with("workspace>>")
                        || trimmed.starts_with("focusedmon>>")
                        || trimmed.starts_with("changefloatingmode>>")
                        || trimmed.starts_with("urgent>>")
                    {
                        update_blueprint = true;
                    }

                    if let Some(cls) = class_to_record {
                        let mut map = tally.lock().await;
                        let count = map.entry(cls).or_insert(0);
                        *count += 1;
                        save_app_usage(&usage_path, &map);
                    }

                    if update_blueprint {
                        let bp = fetch_blueprint_workspaces();
                        let mut state = blueprint_state.lock().await;
                        *state = bp;
                    }
                }
            }
        }

        sleep(Duration::from_secs(2)).await;
    }
}

fn get_top_apps(tally: &HashMap<String, u32>) -> Vec<String> {
    let mut normalized: HashMap<String, u32> = HashMap::new();
    let mut original_names: HashMap<String, String> = HashMap::new();

    for (k, v) in tally {
        let lower = k.trim().to_lowercase();
        *normalized.entry(lower.clone()).or_insert(0) += *v;
        original_names.entry(lower).or_insert_with(|| k.clone());
    }

    let mut entries: Vec<(String, u32)> = normalized
        .into_iter()
        .map(|(lower, count)| (original_names.remove(&lower).unwrap_or(lower), count))
        .collect();

    entries.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    entries.into_iter().take(8).map(|(k, _)| k).collect()
}

// ─────────────────────────────────────────────────────────────────────────────
// Real Git Operations & Dynamic Repository Discovery
// ─────────────────────────────────────────────────────────────────────────────

fn scan_local_git_repos(home: &str, workspace_dir: &str) -> Vec<PathBuf> {
    let mut repos = Vec::new();
    let mut seen = HashSet::new();

    let ws_path = PathBuf::from(workspace_dir);
    if ws_path.join(".git").exists() {
        seen.insert(ws_path.clone());
        repos.push(ws_path);
    }

    let bases = [
        PathBuf::from(home),
        PathBuf::from(home).join("Projects"),
        PathBuf::from(home).join("repos"),
        PathBuf::from(home).join("Development"),
        PathBuf::from(home).join("src"),
    ];

    for base in bases.iter() {
        if !base.is_dir() {
            continue;
        }
        if let Ok(entries) = fs::read_dir(base) {
            for entry in entries.flatten() {
                let p = entry.path();
                let file_name = p
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_default();
                let lower_name = file_name.to_lowercase();

                if file_name.starts_with('.')
                    || lower_name.contains("backup")
                    || lower_name.ends_with(".bak")
                    || lower_name == "target"
                    || lower_name == "node_modules"
                    || lower_name == "build"
                {
                    continue;
                }

                if p.is_dir() && p.join(".git").exists() {
                    if seen.insert(p.clone()) {
                        repos.push(p);
                    }
                }
            }
        }
    }

    repos
}

fn detect_repo_language(path: &Path) -> String {
    if path.join("Cargo.toml").exists() {
        return "Rust".to_string();
    }
    if path.join("pyproject.toml").exists() || path.join("requirements.txt").exists() {
        return "Python".to_string();
    }
    if path.join("package.json").exists() {
        if path.join("tsconfig.json").exists() {
            return "TypeScript".to_string();
        }
        return "JavaScript".to_string();
    }
    if path.join("CMakeLists.txt").exists() || path.join("Makefile").exists() {
        return "C/C++".to_string();
    }
    if path.join("quickshell").exists() || path.join("shell.qml").exists() {
        return "QML".to_string();
    }

    if let Ok(entries) = fs::read_dir(path) {
        for entry in entries.flatten() {
            if let Some(ext) = entry.path().extension() {
                let e = ext.to_string_lossy().to_lowercase();
                if e == "py" {
                    return "Python".to_string();
                }
                if e == "rs" {
                    return "Rust".to_string();
                }
                if e == "sh" {
                    return "Shell".to_string();
                }
                if e == "qml" {
                    return "QML".to_string();
                }
                if e == "go" {
                    return "Go".to_string();
                }
                if e == "c" || e == "cpp" || e == "h" {
                    return "C/C++".to_string();
                }
            }
        }
    }

    "Repository".to_string()
}

fn discover_local_repositories(
    home: &str,
    workspace_dir: &str,
    username: &str,
    seen_names: &mut HashSet<String>,
) -> Vec<RepositoryItem> {
    let mut repos = Vec::new();
    let local_dirs = scan_local_git_repos(home, workspace_dir);
    for dir in local_dirs {
        let repo_name = dir
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        if repo_name.is_empty() || seen_names.contains(&repo_name) {
            continue;
        }

        let dir_str = dir.to_string_lossy();
        let remote_url = Command::new("git")
            .arg("-C")
            .arg(&*dir_str)
            .arg("config")
            .arg("--get")
            .arg("remote.origin.url")
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string())
            .unwrap_or_default();

        let detected_lang = detect_repo_language(&dir);
        let display_url = if !remote_url.is_empty() {
            if remote_url.starts_with("git@github.com:") {
                remote_url
                    .replace("git@github.com:", "https://github.com/")
                    .trim_end_matches(".git")
                    .to_string()
            } else {
                remote_url.trim_end_matches(".git").to_string()
            }
        } else {
            format!("file://{}", dir_str)
        };

        let owner =
            extract_user_from_remote_url(&remote_url).unwrap_or_else(|| username.to_string());
        seen_names.insert(repo_name.clone());
        repos.push(RepositoryItem {
            name: repo_name.clone(),
            full_name: format!("{}/{}", owner, repo_name),
            owner,
            url: display_url,
            description: "Local development repository".to_string(),
            stars: 0,
            language: detected_lang,
        });
    }

    repos
}

fn get_git_contributions(home: &str, workspace_dir: &str) -> (u32, Vec<ContributionDay>, Vec<ContributionWeek>) {
    let today = Local::now().date_naive();
    let mut day_counts: HashMap<String, u32> = HashMap::new();

    let repos = scan_local_git_repos(home, workspace_dir);
    for repo in &repos {
        let repo_str = repo.to_string_lossy();
        if let Ok(out) = Command::new("git")
            .arg("-C")
            .arg(&*repo_str)
            .arg("log")
            .arg("--since=300 days ago")
            .arg("--date=short")
            .arg("--pretty=format:%ad")
            .output()
        {
            let text = String::from_utf8_lossy(&out.stdout);
            for line in text.lines() {
                let trimmed = line.trim();
                if !trimmed.is_empty() {
                    *day_counts.entry(trimmed.to_string()).or_insert(0) += 1;
                }
            }
        }
    }

    let mut total = 0;
    let num_weeks: usize = 36;
    let days_since_sunday = today.weekday().num_days_from_sunday();
    let this_sunday = today - ChronoDuration::days(days_since_sunday as i64);
    let start_sunday = this_sunday - ChronoDuration::weeks((num_weeks - 1) as i64);

    let mut all_days = Vec::with_capacity(num_weeks * 7);
    let mut weeks = Vec::with_capacity(num_weeks);
    let mut last_label_week: i32 = -99;

    for w in 0..num_weeks {
        let week_start = start_sunday + ChronoDuration::weeks(w as i64);
        let mut week_days = Vec::with_capacity(7);
        let mut month_label = String::new();

        for d in 0..7 {
            let date = week_start + ChronoDuration::days(d as i64);
            let date_key = date.format("%Y-%m-%d").to_string();
            let is_future = date > today;
            let count = if is_future {
                0
            } else {
                day_counts.get(&date_key).copied().unwrap_or(0)
            };
            total += count;

            if date.day() == 1 && month_label.is_empty() {
                month_label = date.format("%b").to_string();
            }

            let level = if is_future {
                0
            } else {
                match count {
                    0 => 0,
                    1..=2 => 1,
                    3..=6 => 2,
                    7..=14 => 3,
                    _ => 4,
                }
            };

            let day_item = ContributionDay {
                date: date.format("%b %d, %Y").to_string(),
                count,
                level,
                is_future,
            };

            all_days.push(day_item.clone());
            week_days.push(day_item);
        }

        if w == 0 && month_label.is_empty() {
            month_label = week_start.format("%b").to_string();
        }

        if !month_label.is_empty() {
            if (w as i32) - last_label_week < 3 {
                month_label.clear();
            } else {
                last_label_week = w as i32;
            }
        }

        weeks.push(ContributionWeek {
            month_label,
            days: week_days,
        });
    }

    (total, all_days, weeks)
}

fn get_workspace_status(workspace_dir: &str) -> WorkspaceStatus {
    let path = Path::new(workspace_dir);
    if !path.exists() {
        return WorkspaceStatus {
            repo_name: "No workspace".to_string(),
            branch: "-".to_string(),
            dirty: false,
            ahead: 0,
            behind: 0,
            last_commit: "-".to_string(),
            sync_status: "Workspace directory not found".to_string(),
        };
    }

    let repo_name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "Workspace".to_string());

    let branch = Command::new("git")
        .arg("-C")
        .arg(workspace_dir)
        .arg("rev-parse")
        .arg("--abbrev-ref")
        .arg("HEAD")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "main".to_string());

    let dirty = Command::new("git")
        .arg("-C")
        .arg(workspace_dir)
        .arg("status")
        .arg("--porcelain")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false);

    let mut ahead = 0;
    let mut behind = 0;
    if let Ok(out) = Command::new("git")
        .arg("-C")
        .arg(workspace_dir)
        .arg("rev-list")
        .arg("--left-right")
        .arg("--count")
        .arg("HEAD...@{u}")
        .output()
    {
        if let Ok(counts) = String::from_utf8(out.stdout) {
            let parts: Vec<&str> = counts.trim().split_whitespace().collect();
            if parts.len() >= 2 {
                ahead = parts[0].parse().unwrap_or(0);
                behind = parts[1].parse().unwrap_or(0);
            }
        }
    }

    let last_commit = Command::new("git")
        .arg("-C")
        .arg(workspace_dir)
        .arg("log")
        .arg("-1")
        .arg("--format=%h %s")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "No commits found in tree".to_string());

    let sync_status = if dirty {
        "Uncommitted changes in tree".to_string()
    } else if ahead > 0 {
        format!("{} commit(s) ahead of origin", ahead)
    } else if behind > 0 {
        format!("{} commit(s) behind origin", behind)
    } else {
        "Synced with origin".to_string()
    };

    WorkspaceStatus {
        repo_name,
        branch,
        dirty,
        ahead,
        behind,
        last_commit,
        sync_status,
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic GitHub API & Local Project Synchronizer
// ─────────────────────────────────────────────────────────────────────────────

fn format_relative_time(iso_str: &str) -> String {
    if let Ok(dt) = DateTime::parse_from_rfc3339(iso_str) {
        let now = Utc::now();
        let diff = now.signed_duration_since(dt.with_timezone(&Utc));
        let secs = diff.num_seconds();
        if secs < 60 {
            return "just now".to_string();
        } else if secs < 3600 {
            let mins = secs / 60;
            return format!("{}m ago", mins);
        } else if secs < 86400 {
            let hours = secs / 3600;
            return format!("{}h ago", hours);
        } else if secs < 86400 * 7 {
            let days = secs / 86400;
            return format!("{}d ago", days);
        } else {
            return dt.format("%b %d").to_string();
        }
    }
    iso_str.to_string()
}

async fn fetch_remote_prs(
    client: &reqwest::Client,
    token: Option<&str>,
    username: &str,
    workspace_repo: &str,
) -> Vec<PullRequestItem> {
    let mut prs = Vec::new();
    let mut seen_ids = HashSet::new();

    // 1. Search issues API for all open PRs in repositories owned by username
    if !username.is_empty() {
        let search_url = "https://api.github.com/search/issues";
        let query_str = format!("is:pr is:open user:{}", username);
        let mut req = client
            .get(search_url)
            .query(&[("q", &query_str)])
            .header(USER_AGENT, "carbon-radar-engine")
            .header(ACCEPT, "application/vnd.github+json");

        if let Some(tok) = token {
            if !tok.trim().is_empty() {
                req = req.header(AUTHORIZATION, format!("Bearer {}", tok.trim()));
            }
        }

        if let Ok(resp) = req.send().await {
            if resp.status().is_success() {
                if let Ok(val) = resp.json::<serde_json::Value>().await {
                    if let Some(items) = val.get("items").and_then(|it| it.as_array()) {
                        for item in items {
                            let num = item.get("number").and_then(|n| n.as_u64()).unwrap_or(0);
                            let title = item
                                .get("title")
                                .and_then(|t| t.as_str())
                                .unwrap_or("")
                                .to_string();
                            let repo_url = item
                                .get("repository_url")
                                .and_then(|u| u.as_str())
                                .unwrap_or("");
                            let repo = repo_url
                                .split('/')
                                .last()
                                .unwrap_or(workspace_repo)
                                .to_string();
                            let author = item
                                .get("user")
                                .and_then(|u| u.get("login"))
                                .and_then(|l| l.as_str())
                                .unwrap_or("")
                                .to_string();
                            let url = item
                                .get("html_url")
                                .and_then(|u| u.as_str())
                                .unwrap_or("")
                                .to_string();
                            let state = item
                                .get("state")
                                .and_then(|s| s.as_str())
                                .unwrap_or("open")
                                .to_uppercase();
                            let created_at_raw =
                                item.get("created_at").and_then(|c| c.as_str()).unwrap_or("");
                            let created_at = format_relative_time(created_at_raw);

                            let pr_key = format!("{}:{}", repo, num);
                            if seen_ids.insert(pr_key) {
                                prs.push(PullRequestItem {
                                    number: num,
                                    title,
                                    repo,
                                    author,
                                    url,
                                    state,
                                    created_at,
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. Also check workspace repo pulls directly if none found yet
    if prs.is_empty() && !workspace_repo.is_empty() && !username.is_empty() {
        let repo_pulls_url = format!(
            "https://api.github.com/repos/{}/{}/pulls",
            username, workspace_repo
        );
        let mut req = client
            .get(&repo_pulls_url)
            .header(USER_AGENT, "carbon-radar-engine")
            .header(ACCEPT, "application/vnd.github+json");

        if let Some(tok) = token {
            if !tok.trim().is_empty() {
                req = req.header(AUTHORIZATION, format!("Bearer {}", tok.trim()));
            }
        }

        if let Ok(resp) = req.send().await {
            if resp.status().is_success() {
                if let Ok(val) = resp.json::<serde_json::Value>().await {
                    if let Some(arr) = val.as_array() {
                        for item in arr {
                            let num = item.get("number").and_then(|n| n.as_u64()).unwrap_or(0);
                            let title = item
                                .get("title")
                                .and_then(|t| t.as_str())
                                .unwrap_or("")
                                .to_string();
                            let repo = item
                                .get("base")
                                .and_then(|b| b.get("repo"))
                                .and_then(|r| r.get("name"))
                                .and_then(|n| n.as_str())
                                .unwrap_or(workspace_repo)
                                .to_string();
                            let author = item
                                .get("user")
                                .and_then(|u| u.get("login"))
                                .and_then(|l| l.as_str())
                                .unwrap_or("")
                                .to_string();
                            let url = item
                                .get("html_url")
                                .and_then(|u| u.as_str())
                                .unwrap_or("")
                                .to_string();
                            let state = item
                                .get("state")
                                .and_then(|s| s.as_str())
                                .unwrap_or("open")
                                .to_uppercase();
                            let created_at_raw =
                                item.get("created_at").and_then(|c| c.as_str()).unwrap_or("");
                            let created_at = format_relative_time(created_at_raw);

                            let pr_key = format!("{}:{}", repo, num);
                            if seen_ids.insert(pr_key) {
                                prs.push(PullRequestItem {
                                    number: num,
                                    title,
                                    repo,
                                    author,
                                    url,
                                    state,
                                    created_at,
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    prs
}

async fn fetch_repositories(
    client: &reqwest::Client,
    token: Option<&str>,
    username: &str,
    home: &str,
    workspace_dir: &str,
) -> Vec<RepositoryItem> {
    let mut repos = Vec::new();
    let mut seen_names = HashSet::new();

    // 1. Fetch remote repositories from GitHub API
    if !username.is_empty() {
        let url = if token.is_some() {
            "https://api.github.com/user/repos?sort=updated&per_page=15".to_string()
        } else {
            format!(
                "https://api.github.com/users/{}/repos?sort=updated&per_page=15",
                username
            )
        };

        let mut req = client
            .get(&url)
            .header(USER_AGENT, "carbon-radar-engine")
            .header(ACCEPT, "application/vnd.github+json");

        if let Some(tok) = token {
            if !tok.trim().is_empty() {
                req = req.header(AUTHORIZATION, format!("Bearer {}", tok.trim()));
            }
        }

        if let Ok(resp) = req.send().await {
            if resp.status().is_success() {
                if let Ok(val) = resp.json::<serde_json::Value>().await {
                    if let Some(arr) = val.as_array() {
                        for item in arr {
                            let name = item
                                .get("name")
                                .and_then(|n| n.as_str())
                                .unwrap_or("")
                                .to_string();
                            if name.is_empty() {
                                continue;
                            }
                            let full_name = item
                                .get("full_name")
                                .and_then(|n| n.as_str())
                                .unwrap_or(&name)
                                .to_string();
                            let owner = item
                                .get("owner")
                                .and_then(|o| o.get("login"))
                                .and_then(|l| l.as_str())
                                .unwrap_or(username)
                                .to_string();
                            let url = item
                                .get("html_url")
                                .and_then(|u| u.as_str())
                                .unwrap_or("")
                                .to_string();
                            let description = item
                                .get("description")
                                .and_then(|d| d.as_str())
                                .unwrap_or("")
                                .to_string();
                            let stars = item
                                .get("stargazers_count")
                                .and_then(|s| s.as_u64())
                                .unwrap_or(0) as u32;
                            let language = item
                                .get("language")
                                .and_then(|l| l.as_str())
                                .unwrap_or("Code")
                                .to_string();

                            seen_names.insert(name.clone());
                            repos.push(RepositoryItem {
                                name,
                                full_name,
                                owner,
                                url,
                                description,
                                stars,
                                language,
                            });
                        }
                    }
                }
            }
        }
    }

    // 2. Discover local git repositories on disk and append any not already found
    let local_repos = discover_local_repositories(home, workspace_dir, username, &mut seen_names);
    repos.extend(local_repos);

    repos
}

pub async fn search_github_repositories(
    client: &reqwest::Client,
    token: Option<&str>,
    query: &str,
) -> Vec<RepositoryItem> {
    let q = query.trim();
    if q.is_empty() {
        return Vec::new();
    }

    let url = "https://api.github.com/search/repositories";
    let mut req = client
        .get(url)
        .query(&[("q", q), ("per_page", "15")])
        .header(USER_AGENT, "carbon-shell")
        .header(ACCEPT, "application/vnd.github.v3+json");

    if let Some(tok) = token {
        let trimmed_tok = tok.trim();
        if !trimmed_tok.is_empty() {
            req = req.header(AUTHORIZATION, format!("Bearer {}", trimmed_tok));
        }
    }

    let mut repos = Vec::new();
    if let Ok(resp) = req.send().await {
        if resp.status().is_success() {
            if let Ok(val) = resp.json::<serde_json::Value>().await {
                if let Some(items) = val.get("items").and_then(|i| i.as_array()) {
                    for item in items {
                        let name = item
                            .get("name")
                            .and_then(|n| n.as_str())
                            .unwrap_or("")
                            .to_string();
                        if name.is_empty() {
                            continue;
                        }
                        let full_name = item
                            .get("full_name")
                            .and_then(|n| n.as_str())
                            .unwrap_or(&name)
                            .to_string();
                        let owner = item
                            .get("owner")
                            .and_then(|o| o.get("login"))
                            .and_then(|l| l.as_str())
                            .unwrap_or("")
                            .to_string();
                        let url = item
                            .get("html_url")
                            .and_then(|u| u.as_str())
                            .unwrap_or("")
                            .to_string();
                        let description = item
                            .get("description")
                            .and_then(|d| d.as_str())
                            .unwrap_or("")
                            .to_string();
                        let stars = item
                            .get("stargazers_count")
                            .and_then(|s| s.as_u64())
                            .unwrap_or(0) as u32;
                        let language = item
                            .get("language")
                            .and_then(|l| l.as_str())
                            .unwrap_or("Code")
                            .to_string();

                        repos.push(RepositoryItem {
                            name,
                            full_name,
                            owner,
                            url,
                            description,
                            stars,
                            language,
                        });
                    }
                }
            }
        }
    }

    repos
}

async fn refresh_github_data(
    client: &reqwest::Client,
    gh_state: &Arc<Mutex<GitHubState>>,
    home: &str,
    ws_dir: &str,
    username: &str,
    token: Option<&str>,
) {
    let ws_repo_name = Path::new(ws_dir)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "carbon-shell".to_string());

    let (prs, repos) = tokio::join!(
        fetch_remote_prs(client, token, username, &ws_repo_name),
        fetch_repositories(client, token, username, home, ws_dir)
    );

    let mut state = gh_state.lock().await;
    state.pull_requests = prs;
    if !repos.is_empty() {
        state.all_repositories = repos;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// GitHub State Model
// ─────────────────────────────────────────────────────────────────────────────

pub struct GitHubState {
    pub settings: CarbonSettings,
    pub pull_requests: Vec<PullRequestItem>,
    pub all_repositories: Vec<RepositoryItem>,
    pub search_query: String,
    pub search_results: Option<Vec<RepositoryItem>>,
    pub feedback: String,
}

impl GitHubState {
    pub fn new(settings: CarbonSettings) -> Self {
        let home = get_home_dir();
        let ws = settings
            .workspace_dir
            .clone()
            .unwrap_or_else(|| detect_workspace_dir(&home));
        let user = settings
            .github_username
            .clone()
            .unwrap_or_else(|| detect_github_username(&ws));
        let mut seen = HashSet::new();
        let initial_repos = discover_local_repositories(&home, &ws, &user, &mut seen);

        Self {
            settings,
            pull_requests: Vec::new(),
            all_repositories: initial_repos,
            search_query: String::new(),
            search_results: None,
            feedback: String::new(),
        }
    }

    pub fn filtered_repositories(&self) -> Vec<RepositoryItem> {
        let q = self.search_query.trim().to_lowercase();
        if q.is_empty() {
            return self.all_repositories.clone();
        }
        self.all_repositories
            .iter()
            .filter(|r| {
                r.name.to_lowercase().contains(&q)
                    || r.full_name.to_lowercase().contains(&q)
                    || r.description.to_lowercase().contains(&q)
                    || r.language.to_lowercase().contains(&q)
            })
            .cloned()
            .collect()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hardware Telemetry Monitor (sysinfo)
// ─────────────────────────────────────────────────────────────────────────────

pub struct HardwareMonitor {
    sys: sysinfo::System,
    networks: sysinfo::Networks,
    components: sysinfo::Components,
    last_refresh: std::time::Instant,
}

impl HardwareMonitor {
    pub fn new() -> Self {
        let mut sys = sysinfo::System::new_all().unwrap_or_else(|_| sysinfo::System::new().unwrap());
        sys.refresh_all();
        let networks = sysinfo::Networks::new_with_refreshed_list()
            .unwrap_or_else(|_| sysinfo::Networks::new().unwrap());
        let components = sysinfo::Components::new_with_refreshed_list()
            .unwrap_or_else(|_| sysinfo::Components::new().unwrap());
        Self {
            sys,
            networks,
            components,
            last_refresh: std::time::Instant::now(),
        }
    }

    pub fn poll(&mut self) -> SystemTelemetryPayload {
        let elapsed = self.last_refresh.elapsed().as_secs_f64().max(0.5);
        self.last_refresh = std::time::Instant::now();

        self.sys.refresh_cpu_all();
        self.sys.refresh_memory();
        self.networks.refresh(true);
        self.components.refresh(true);

        // Global and per-core CPU usage
        let cpu_usage = self.sys.global_cpu_usage();
        let cpu_cores = self
            .sys
            .cpus()
            .iter()
            .enumerate()
            .map(|(id, cpu)| CpuCore {
                id,
                usage: cpu.usage(),
            })
            .collect();

        // CPU Temperature
        let mut cpu_temp: f32 = 0.0;
        for c in self.components.iter() {
            let label = c.label().to_lowercase();
            if label.contains("package id")
                || label.contains("cpu")
                || label.contains("tdie")
                || label.contains("tctl")
                || label.contains("core 0")
            {
                if let Some(t) = c.temperature() {
                    if t > 0.0 {
                        cpu_temp = t;
                        break;
                    }
                }
            }
        }
        if cpu_temp == 0.0 {
            for c in self.components.iter() {
                if let Some(t) = c.temperature() {
                    if t > 0.0 {
                        cpu_temp = t;
                        break;
                    }
                }
            }
        }
        if cpu_temp == 0.0 {
            if let Ok(entries) = fs::read_dir("/sys/class/thermal") {
                for entry in entries.flatten() {
                    let path = entry.path().join("temp");
                    if let Ok(content) = fs::read_to_string(&path) {
                        if let Ok(raw_t) = content.trim().parse::<f32>() {
                            let t = if raw_t > 200.0 { raw_t / 1000.0 } else { raw_t };
                            if t > 0.0 {
                                cpu_temp = t;
                                break;
                            }
                        }
                    }
                }
            }
        }

        // RAM & SWAP
        let ram_total_bytes = self.sys.total_memory();
        let ram_used_bytes = self.sys.used_memory();
        let swap_total_bytes = self.sys.total_swap();
        let swap_used_bytes = self.sys.used_swap();

        // Network Up/Down speeds (bytes per second)
        let mut total_rx_delta: u64 = 0;
        let mut total_tx_delta: u64 = 0;
        for (name, data) in self.networks.iter() {
            let name_str = name.to_string_lossy().to_lowercase();
            if name_str != "lo" {
                total_rx_delta += data.received();
                total_tx_delta += data.transmitted();
            }
        }
        let net_rx_bps = ((total_rx_delta as f64) / elapsed).round() as u64;
        let net_tx_bps = ((total_tx_delta as f64) / elapsed).round() as u64;

        // Kernel & Uptime
        let kernel_version = sysinfo::System::kernel_version()
            .unwrap_or_else(|_| "Linux".to_string());
        let uptime_seconds = sysinfo::System::uptime().unwrap_or_default();
        let hours = uptime_seconds / 3600;
        let mins = (uptime_seconds % 3600) / 60;
        let uptime_formatted = if hours >= 24 {
            let days = hours / 24;
            let rem_hours = hours % 24;
            format!("{}d {}h", days, rem_hours)
        } else if hours > 0 {
            format!("{}h {}m", hours, mins)
        } else {
            format!("{}m", mins)
        };

        SystemTelemetryPayload {
            cpu_usage,
            cpu_cores,
            cpu_temp,
            ram_used_bytes,
            ram_total_bytes,
            swap_used_bytes,
            swap_total_bytes,
            net_rx_bps,
            net_tx_bps,
            kernel_version,
            uptime_seconds,
            uptime_formatted,
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payload & Emission
// ─────────────────────────────────────────────────────────────────────────────

async fn build_payload(
    tally: &Arc<Mutex<HashMap<String, u32>>>,
    gh_state: &Arc<Mutex<GitHubState>>,
    hw_monitor: &Arc<Mutex<HardwareMonitor>>,
    blueprint_state: &Arc<Mutex<(Vec<BlueprintWorkspace>, i32)>>,
) -> RadarPayload {
    let apps = {
        let map = tally.lock().await;
        get_top_apps(&map)
    };

    let mut gh = gh_state.lock().await;
    let home = get_home_dir();
    let ws_dir = gh
        .settings
        .workspace_dir
        .clone()
        .unwrap_or_else(|| detect_workspace_dir(&home));
    let workspace = get_workspace_status(&ws_dir);
    let (total_contributions, contributions, weeks) = get_git_contributions(&home, &ws_dir);

    let authenticated = gh
        .settings
        .github_token
        .as_ref()
        .map_or(false, |t| !t.trim().is_empty());
    let username = gh
        .settings
        .github_username
        .clone()
        .unwrap_or_else(|| detect_github_username(&ws_dir));

    let repositories = if !gh.search_query.trim().is_empty() {
        gh.search_results.clone().unwrap_or_default()
    } else {
        gh.all_repositories.clone()
    };

    let feedback = std::mem::take(&mut gh.feedback);

    let github = GitHubPayload {
        authenticated,
        username,
        total_contributions,
        contributions,
        weeks,
        pull_requests: gh.pull_requests.clone(),
        repositories,
        workspace,
        feedback,
    };

    let telemetry = {
        let mut hw = hw_monitor.lock().await;
        hw.poll()
    };

    let (workspaces, active_workspace_id) = {
        let bp = blueprint_state.lock().await;
        bp.clone()
    };

    RadarPayload {
        vault: fetch_obsidian_notes(),
        clipboard: fetch_clipboard(),
        apps,
        agenda: fetch_agenda(),
        github,
        telemetry,
        workspaces,
        active_workspace_id,
    }
}

fn emit_payload(payload: &RadarPayload) {
    if let Ok(serialized) = serde_json::to_string(payload) {
        let mut stdout = std::io::stdout();
        let _ = writeln!(stdout, "{}", serialized);
        let _ = stdout.flush();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Command Handler
// ─────────────────────────────────────────────────────────────────────────────

async fn handle_action_command(
    cmd: &str,
    gh_state: &Arc<Mutex<GitHubState>>,
    client: &reqwest::Client,
) {
    let trimmed = cmd.trim();
    if trimmed.is_empty() {
        return;
    }

    if let Some(url) = trimmed.strip_prefix("OPEN_URL ") {
        let target = url.trim();
        if !target.is_empty() {
            let _ = Command::new("xdg-open").arg(target).spawn();
            let mut state = gh_state.lock().await;
            state.feedback.clear();
        }
    } else if trimmed == "PUSH_LOCAL" {
        let (ws_dir, home, username, token) = {
            let state = gh_state.lock().await;
            let home = get_home_dir();
            let ws = state
                .settings
                .workspace_dir
                .clone()
                .unwrap_or_else(|| detect_workspace_dir(&home));
            let user = state.settings.github_username.clone().unwrap_or_default();
            let tok = state.settings.github_token.clone();
            (ws, home, user, tok)
        };

        let mut cmd = Command::new("git");
        cmd.arg("-C").arg(&ws_dir).arg("push");
        let output = cmd.output();

        {
            let mut state = gh_state.lock().await;
            match output {
                Ok(out) if out.status.success() => {
                    state.feedback = "Local workspace pushed to origin/main".to_string();
                }
                Ok(out) => {
                    let err = String::from_utf8_lossy(&out.stderr);
                    let first_line = err
                        .lines()
                        .find(|l| !l.trim().is_empty())
                        .unwrap_or("Git push returned an error");
                    state.feedback = format!("Git: {}", first_line);
                }
                Err(e) => {
                    state.feedback = format!("Push command failed: {}", e);
                }
            }
        }

        refresh_github_data(client, gh_state, &home, &ws_dir, &username, token.as_deref()).await;
    } else if let Some(rest) = trimmed.strip_prefix("MERGE_PR ") {
        let parts: Vec<&str> = rest.split_whitespace().collect();
        if parts.len() >= 2 {
            let repo = parts[0];
            let num_str = parts[1];
            if let Ok(num) = num_str.parse::<u64>() {
                let mut state = gh_state.lock().await;
                if let Some(ref tok) = state.settings.github_token {
                    if !tok.trim().is_empty() {
                        let client_clone = client.clone();
                        let merge_url = format!(
                            "https://api.github.com/repos/{}/pulls/{}/merge",
                            repo, num
                        );
                        let tok_clone = tok.clone();
                        tokio::spawn(async move {
                            let _ = client_clone
                                .put(&merge_url)
                                .header(USER_AGENT, "carbon-radar-engine")
                                .header(AUTHORIZATION, format!("Bearer {}", tok_clone))
                                .send()
                                .await;
                        });
                    }
                }

                state
                    .pull_requests
                    .retain(|p| !(p.repo == repo && p.number == num));
                state.feedback = format!("PR #{} merged into {}", num, repo);
            }
        }
    } else if let Some(query) = trimmed.strip_prefix("SEARCH_REPOS").or_else(|| trimmed.strip_prefix("SEARCH")) {
        let q = query.trim().to_string();
        let (token, old_q) = {
            let mut state = gh_state.lock().await;
            state.search_query = q.clone();
            if q.is_empty() {
                state.search_results = None;
            }
            (state.settings.github_token.clone(), q)
        };
        if !old_q.is_empty() {
            let results = search_github_repositories(client, token.as_deref(), &old_q).await;
            let mut state = gh_state.lock().await;
            if state.search_query == old_q {
                state.search_results = Some(results);
            }
        }
    } else if trimmed == "REFRESH" || trimmed == "REFRESH_GITHUB" {
        let (home, ws_dir, username, token) = {
            let state = gh_state.lock().await;
            let home = get_home_dir();
            let ws = state
                .settings
                .workspace_dir
                .clone()
                .unwrap_or_else(|| detect_workspace_dir(&home));
            let user = state.settings.github_username.clone().unwrap_or_default();
            let tok = state.settings.github_token.clone();
            (home, ws, user, tok)
        };
        refresh_github_data(client, gh_state, &home, &ws_dir, &username, token.as_deref()).await;
        let mut state = gh_state.lock().await;
        state.feedback = "Refreshed GitHub & Workspace status".to_string();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Entrypoint
// ─────────────────────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let settings = load_settings();
    let gh_state = Arc::new(Mutex::new(GitHubState::new(settings.clone())));
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());

    let usage_path = get_usage_file_path();
    let mut initial_tally = load_app_usage(&usage_path);

    if initial_tally.is_empty() {
        seed_from_clients(&mut initial_tally);
        if !initial_tally.is_empty() {
            save_app_usage(&usage_path, &initial_tally);
        }
    }

    let tally = Arc::new(Mutex::new(initial_tally));
    let initial_bp = fetch_blueprint_workspaces();
    let blueprint_state = Arc::new(Mutex::new(initial_bp));

    // Spawn Hyprland socket2 IPC listener
    let listener_tally = Arc::clone(&tally);
    let listener_path = usage_path.clone();
    let listener_bp = Arc::clone(&blueprint_state);
    tokio::spawn(async move {
        start_ipc_listener(listener_tally, listener_path, listener_bp).await;
    });

    // Spawn background GitHub and repository synchronizer
    let sync_state = Arc::clone(&gh_state);
    let sync_client = client.clone();
    let home = get_home_dir();
    let ws_dir = settings
        .workspace_dir
        .clone()
        .unwrap_or_else(|| detect_workspace_dir(&home));
    let username = settings
        .github_username
        .clone()
        .unwrap_or_else(|| detect_github_username(&ws_dir));
    let token = settings.github_token.clone();

    tokio::spawn(async move {
        // Initial fetch
        refresh_github_data(
            &sync_client,
            &sync_state,
            &home,
            &ws_dir,
            &username,
            token.as_deref(),
        )
        .await;

        loop {
            sleep(Duration::from_secs(60)).await;
            refresh_github_data(
                &sync_client,
                &sync_state,
                &home,
                &ws_dir,
                &username,
                token.as_deref(),
            )
            .await;
        }
    });

    let hw_monitor = Arc::new(Mutex::new(HardwareMonitor::new()));
    let mut stdin_reader = BufReader::new(tokio::io::stdin()).lines();
    let mut ticker = tokio::time::interval(Duration::from_secs(2));

    // Emit initial payload immediately
    let initial = build_payload(&tally, &gh_state, &hw_monitor, &blueprint_state).await;
    emit_payload(&initial);

    loop {
        tokio::select! {
            _ = ticker.tick() => {
                let payload = build_payload(&tally, &gh_state, &hw_monitor, &blueprint_state).await;
                emit_payload(&payload);
            }
            line = stdin_reader.next_line() => {
                match line {
                    Ok(Some(raw_line)) => {
                        handle_action_command(&raw_line, &gh_state, &client).await;
                        let payload = build_payload(&tally, &gh_state, &hw_monitor, &blueprint_state).await;
                        emit_payload(&payload);
                    }
                    Ok(None) => {
                        sleep(Duration::from_millis(100)).await;
                    }
                    Err(_) => {
                        sleep(Duration::from_millis(500)).await;
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_fetch_prs_and_repos() {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap();
        let prs = fetch_remote_prs(&client, None, "xzshogun", "carbon-shell").await;
        println!("Fetched PRs: {:?}", prs);
        assert!(!prs.is_empty(), "Should fetch at least PR #8");

        let home = get_home_dir();
        let ws = detect_workspace_dir(&home);
        let mut seen = HashSet::new();
        let repos = discover_local_repositories(&home, &ws, "xzshogun", &mut seen);
        println!(
            "Discovered local repos: {:?}",
            repos.iter().map(|r| &r.name).collect::<Vec<_>>()
        );
        assert!(!repos.is_empty(), "Should discover local git repos");
    }

    #[tokio::test]
    async fn test_search_github_repositories() {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(8))
            .build()
            .unwrap();
        let repos = search_github_repositories(&client, None, "carbon-shell").await;
        println!("Search repos found: {}", repos.len());
        for r in &repos {
            println!("Repo: {} / {} ({})", r.owner, r.name, r.url);
        }
        assert!(!repos.is_empty(), "Should find repos matching 'carbon-shell'");
        assert!(repos.iter().any(|r| r.name.to_lowercase().contains("carbon")));
    }

    #[tokio::test]
    async fn test_sysinfo_polling() {
        let mut hw = HardwareMonitor::new();
        tokio::time::sleep(Duration::from_millis(200)).await;
        let telemetry = hw.poll();

        println!("Global CPU: {:.1}%", telemetry.cpu_usage);
        println!("CPU Cores ({} cores):", telemetry.cpu_cores.len());
        for core in &telemetry.cpu_cores {
            println!("  Core {}: {:.1}%", core.id, core.usage);
        }
        println!("CPU Temp: {:.1}°C", telemetry.cpu_temp);
        println!("RAM: {} / {} bytes", telemetry.ram_used_bytes, telemetry.ram_total_bytes);
        println!("SWAP: {} / {} bytes", telemetry.swap_used_bytes, telemetry.swap_total_bytes);
        println!("Net: RX {} B/s, TX {} B/s", telemetry.net_rx_bps, telemetry.net_tx_bps);
        println!("Kernel: {}", telemetry.kernel_version);
        println!("Uptime: {} ({})", telemetry.uptime_seconds, telemetry.uptime_formatted);

        assert!(!telemetry.cpu_cores.is_empty(), "Should report CPU cores");
        assert!(telemetry.ram_total_bytes > 0, "Should report total RAM");
        assert!(!telemetry.kernel_version.is_empty(), "Should report kernel version");
    }
}
