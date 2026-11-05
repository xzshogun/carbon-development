use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::process::{Child, Command, Stdio};
use sysinfo::{ProcessesToUpdate, System};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::time::{interval, Duration};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FocusState {
    Idle,
    Focus,
    Break,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FocusStatusPayload {
    pub state: FocusState,
    pub remaining: u32,
    pub focus_target: u32,
    pub break_target: u32,
    pub noise_active: bool,
    pub noise_type: String,
}

struct Engine {
    state: FocusState,
    focus_target_min: u32,
    break_target_min: u32,
    remaining_sec: u32,
    frozen_pids: Vec<i32>,
    noise_active: bool,
    noise_type: String,
    noise_child: Option<Child>,
    system: System,
}

impl Engine {
    fn new() -> Self {
        let focus_min = 25;
        let break_min = 5;
        Self {
            state: FocusState::Idle,
            focus_target_min: focus_min,
            break_target_min: break_min,
            remaining_sec: focus_min * 60,
            frozen_pids: Vec::new(),
            noise_active: false,
            noise_type: "none".to_string(),
            noise_child: None,
            system: System::new_all(),
        }
    }

    fn payload(&self) -> FocusStatusPayload {
        FocusStatusPayload {
            state: self.state,
            remaining: self.remaining_sec,
            focus_target: self.focus_target_min,
            break_target: self.break_target_min,
            noise_active: self.noise_active,
            noise_type: self.noise_type.clone(),
        }
    }

    fn emit(&self) {
        if let Ok(json_str) = serde_json::to_string(&self.payload()) {
            let mut out = io::stdout().lock();
            let _ = writeln!(out, "{}", json_str);
            let _ = out.flush();
        }
    }

    fn freeze_distractions(&mut self) {
        self.system.refresh_processes(ProcessesToUpdate::All, true);
        let target_names = [
            "discord",
            "vesktop",
            "webcord",
            "steam",
            "spotify",
            "telegram-desktop",
            "telegram",
            "slack",
            "lutris",
        ];

        let mut pids_to_freeze = Vec::new();
        for (pid, process) in self.system.processes() {
            let name = process.name().to_string_lossy().to_lowercase();
            for target in &target_names {
                if name.contains(target) {
                    pids_to_freeze.push(pid.as_u32() as i32);
                    break;
                }
            }
        }

        for pid in pids_to_freeze {
            if !self.frozen_pids.contains(&pid) {
                unsafe {
                    libc::kill(pid as libc::pid_t, libc::SIGSTOP);
                }
                self.frozen_pids.push(pid);
            }
        }

        // Apply Hyprland active window dimming
        let _ = Command::new("hyprctl")
            .args(["keyword", "decoration:dim_inactive", "true"])
            .status();
        let _ = Command::new("hyprctl")
            .args(["keyword", "decoration:dim_strength", "0.93"])
            .status();
    }

    fn unfreeze_distractions(&mut self) {
        for pid in self.frozen_pids.drain(..) {
            unsafe {
                libc::kill(pid as libc::pid_t, libc::SIGCONT);
            }
        }

        // Revert Hyprland dimming
        let _ = Command::new("hyprctl")
            .args(["keyword", "decoration:dim_inactive", "false"])
            .status();
    }

    fn start_focus(&mut self) {
        self.state = FocusState::Focus;
        self.remaining_sec = self.focus_target_min * 60;
        self.freeze_distractions();
        self.emit();
    }

    fn start_break(&mut self) {
        self.state = FocusState::Break;
        self.remaining_sec = self.break_target_min * 60;
        self.unfreeze_distractions();
        self.emit();
    }

    fn stop(&mut self) {
        self.state = FocusState::Idle;
        self.remaining_sec = self.focus_target_min * 60;
        self.unfreeze_distractions();
        self.stop_noise();
        self.emit();
    }

    fn tick(&mut self) {
        match self.state {
            FocusState::Focus => {
                if self.remaining_sec > 0 {
                    self.remaining_sec -= 1;
                }
                if self.remaining_sec == 0 {
                    self.start_break();
                    return;
                }
                self.emit();
            }
            FocusState::Break => {
                if self.remaining_sec > 0 {
                    self.remaining_sec -= 1;
                }
                if self.remaining_sec == 0 {
                    self.stop();
                    return;
                }
                self.emit();
            }
            FocusState::Idle => {
                // In idle, emit periodic status update
                self.emit();
            }
        }
    }

    fn set_focus_target(&mut self, mins: u32) {
        if mins > 0 {
            self.focus_target_min = mins;
            if self.state == FocusState::Idle {
                self.remaining_sec = mins * 60;
            }
            self.emit();
        }
    }

    fn set_break_target(&mut self, mins: u32) {
        if mins > 0 {
            self.break_target_min = mins;
            if self.state == FocusState::Break {
                self.remaining_sec = mins * 60;
            }
            self.emit();
        }
    }

    fn play_noise(&mut self, kind: &str) {
        self.stop_noise();
        let home = std::env::var("HOME").unwrap_or_default();
        let rain_mp3 = format!("{}/.config/carbon/assets/rain.mp3", home);
        let child = if kind == "rain" && std::path::Path::new(&rain_mp3).exists() {
            Command::new("mpv")
                .args(["--loop=inf", "--no-video", &rain_mp3])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .ok()
        } else if Command::new("play").arg("-h").output().is_ok() {
            let synth_arg = if kind == "rain" { "pinknoise" } else { "brownnoise" };
            Command::new("play")
                .args(["-q", "-n", "synth", synth_arg])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .ok()
        } else {
            let lavfi_arg = if kind == "rain" {
                "av://lavfi:anoisesrc=c=pink:r=48000:a=0.05,lowpass=f=1200"
            } else {
                "av://lavfi:anoisesrc=c=brown:r=48000:a=0.05"
            };
            Command::new("mpv")
                .args(["--no-video", lavfi_arg])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .ok()
        };

        if child.is_some() {
            self.noise_child = child;
            self.noise_active = true;
            self.noise_type = kind.to_string();
        }
        self.emit();
    }

    fn stop_noise(&mut self) {
        if let Some(mut child) = self.noise_child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.noise_active = false;
        self.noise_type = "none".to_string();
        self.emit();
    }

    fn toggle_noise(&mut self) {
        if self.noise_active {
            self.stop_noise();
        } else {
            self.play_noise("brown");
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.unfreeze_distractions();
        if let Some(mut child) = self.noise_child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

#[tokio::main]
async fn main() {
    let mut engine = Engine::new();
    engine.emit();

    let mut tick_interval = interval(Duration::from_secs(1));
    // Consume immediate first tick
    tick_interval.tick().await;

    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin).lines();

    loop {
        tokio::select! {
            _ = tick_interval.tick() => {
                engine.tick();
            }
            line_res = reader.next_line() => {
                match line_res {
                    Ok(Some(line)) => {
                        let trimmed = line.trim();
                        if trimmed.is_empty() {
                            continue;
                        }

                        if trimmed == "start" {
                            engine.start_focus();
                        } else if trimmed == "stop" {
                            engine.stop();
                        } else if trimmed == "start_break" || trimmed == "break" {
                            engine.start_break();
                        } else if trimmed.starts_with("set_focus ") {
                            let val_str = trimmed.trim_start_matches("set_focus ").trim();
                            if let Ok(m) = val_str.parse::<u32>() {
                                engine.set_focus_target(m);
                            }
                        } else if trimmed.starts_with("set_break ") {
                            let val_str = trimmed.trim_start_matches("set_break ").trim();
                            if let Ok(m) = val_str.parse::<u32>() {
                                engine.set_break_target(m);
                            }
                        } else if trimmed == "toggle_audio_noise" || trimmed == "toggle_noise" {
                            engine.toggle_noise();
                        } else if trimmed == "noise_brown" || trimmed == "brown" {
                            engine.play_noise("brown");
                        } else if trimmed == "noise_rain" || trimmed == "rain" {
                            engine.play_noise("rain");
                        } else if trimmed == "noise_stop" {
                            engine.stop_noise();
                        }
                    }
                    Ok(None) => {
                        // EOF from stdin
                        break;
                    }
                    Err(_) => {
                        break;
                    }
                }
            }
        }
    }
}
