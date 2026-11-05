use std::io::Write;
use std::os::unix::process::ExitStatusExt;
use std::sync::{Arc, Mutex};
use tokio::io::AsyncReadExt;

async fn execute_upload(
    host: &str,
    file_path: &str,
    safe_file_name: &str,
    total_mb: f64,
    use_fallback: bool,
) -> Result<String, (i32, String)> {
    let mut cmd = tokio::process::Command::new("curl");
    cmd.arg("-4")
        .arg("--http1.1")
        .arg("-g")
        .arg("--no-buffer")
        .arg("--connect-timeout")
        .arg("15")
        .arg("--max-time")
        .arg("7200");
    cmd.kill_on_drop(true);
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());

    let mut filebin_target_url: Option<String> = None;

    if (host.starts_with("buzz") || host.contains("buzz")) && !use_fallback {
        let url = format!("https://w.buzzheavier.com/{}", safe_file_name);
        cmd.arg("-A")
            .arg("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
            .arg("-L")
            .arg("-T")
            .arg(file_path)
            .arg(&url);
    } else if (host.starts_with("buzz") || host.contains("buzz")) && use_fallback {
        // Fallback for Buzzheavier on exit code 35: multi-GB direct raw streaming host filebin.net
        let bin_id = format!(
            "cb{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis()
        );
        let url = format!("https://filebin.net/{}/{}", bin_id, safe_file_name);
        filebin_target_url = Some(url.clone());
        cmd.arg("-A")
            .arg("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Accept: application/json")
            .arg("--data-binary")
            .arg(format!("@{}", file_path))
            .arg(&url);
    } else if host.starts_with("filebin") || host.contains("filebin") {
        let bin_id = format!(
            "cb{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis()
        );
        let url = format!("https://filebin.net/{}/{}", bin_id, safe_file_name);
        filebin_target_url = Some(url.clone());
        cmd.arg("-A")
            .arg("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Accept: application/json")
            .arg("--data-binary")
            .arg(format!("@{}", file_path))
            .arg(&url);
    } else if host.starts_with("x0") || host.contains("x0") {
        cmd.arg("-A")
            .arg("CarbonDrop/1.0 (ArchLinux)")
            .arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://x0.at");
    } else if host.starts_with("uguu") || host.contains("uguu") {
        cmd.arg("-A")
            .arg("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
            .arg("-F")
            .arg(format!("files[]=@{}", file_path))
            .arg("https://uguu.se/upload");
    } else if host.starts_with("kappa") || host.contains("kappa") {
        cmd.arg("-A")
            .arg("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
            .arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://kappa.lol/api/upload");
    } else {
        cmd.arg("-A")
            .arg("CarbonDrop/1.0 (ArchLinux)")
            .arg("-F")
            .arg(format!("file=@{}", file_path))
            .arg("https://x0.at");
    }

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return Err((-1, format!("Failed to spawn curl: {}", e))),
    };

    let engine_pid = std::process::id();
    let child_pid = child.id().unwrap_or(0);
    let init_info = serde_json::json!({
        "type": "init",
        "pid": engine_pid,
        "child_pid": child_pid
    });
    println!("{}", init_info);
    let _ = std::io::stdout().flush();

    let mut stderr = child.stderr.take().expect("Failed to open child stderr");
    let mut stdout = child.stdout.take().expect("Failed to open child stdout");

    let last_err_msg: Arc<Mutex<String>> = Arc::new(Mutex::new(String::new()));
    let last_err_clone = Arc::clone(&last_err_msg);

    // Concurrently read stderr stream for progress and error messages
    let stderr_task = tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        let mut line_buf = Vec::new();
        let mut last_pct = -1.0;

        while let Ok(n) = stderr.read(&mut buf).await {
            if n == 0 {
                break;
            }
            for &b in &buf[..n] {
                if b == b'\r' || b == b'\n' {
                    if !line_buf.is_empty() {
                        let s = String::from_utf8_lossy(&line_buf);
                        let trimmed = s.trim();

                        if trimmed.starts_with("curl: (") || trimmed.contains("error") || trimmed.contains("failure") {
                            let mut lock = last_err_clone.lock().unwrap();
                            *lock = trimmed.to_string();
                        }

                        let parts: Vec<&str> = trimmed.split_whitespace().collect();
                        if !parts.is_empty() {
                            if let Ok(pct) = parts[0].parse::<f64>() {
                                let speed = parts.last().unwrap_or(&"--");
                                let eta = if parts.len() >= 12 { parts[10] } else { "--:--:--" };
                                let current_mb = total_mb * (pct / 100.0);
                                let status = format!(
                                    "{:.0}% ({:.1} / {:.1} MB) • {}/s • ETA {}",
                                    pct, current_mb, total_mb, speed, eta
                                );

                                if (pct - last_pct).abs() >= 0.5 || pct >= 100.0 {
                                    last_pct = pct;
                                    let json_msg = serde_json::json!({
                                        "type": "progress",
                                        "percent": pct,
                                        "status": status
                                    });
                                    println!("{}", json_msg);
                                    let _ = std::io::stdout().flush();
                                }
                            }
                        }
                        line_buf.clear();
                    }
                } else {
                    line_buf.push(b);
                }
            }
        }
    });

    // Concurrently read stdout stream
    let stdout_task = tokio::spawn(async move {
        let mut stdout_buf = Vec::new();
        let _ = stdout.read_to_end(&mut stdout_buf).await;
        stdout_buf
    });

    // Concurrent join prevents pipe buffer deadlocks
    let (wait_res, _, stdout_res) = tokio::join!(child.wait(), stderr_task, stdout_task);
    let stdout_bytes = stdout_res.unwrap_or_default();
    let stdout_str = String::from_utf8_lossy(&stdout_bytes).to_string();

    let exit_code = match wait_res {
        Ok(ref s) => s.code().or_else(|| s.signal().map(|sig| 128 + sig)).unwrap_or(-1),
        Err(_) => -1,
    };

    let exit_success = exit_code == 0;

    let final_url: Option<String> = if exit_success {
        if (host.starts_with("buzz") || host.contains("buzz")) && !use_fallback {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.pointer("/data/id")
                        .and_then(|x| x.as_str())
                        .map(|id| format!("https://buzzheavier.com/{}", id))
                })
        } else if ((host.starts_with("buzz") || host.contains("buzz")) && use_fallback)
            || host.starts_with("filebin")
            || host.contains("filebin")
        {
            if stdout_str.contains("filename") || stdout_str.contains("bin") {
                filebin_target_url
            } else {
                None
            }
        } else if host.starts_with("x0") || host.contains("x0") {
            let trimmed = stdout_str.trim().to_string();
            if trimmed.starts_with("http") {
                Some(trimmed)
            } else {
                None
            }
        } else if host.starts_with("uguu") || host.contains("uguu") {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.pointer("/files/0/url")
                        .and_then(|x| x.as_str())
                        .map(|u| u.to_string())
                })
        } else if host.starts_with("kappa") || host.contains("kappa") {
            serde_json::from_str::<serde_json::Value>(&stdout_str)
                .ok()
                .and_then(|v| {
                    v.get("link").and_then(|x| x.as_str()).map(|link| {
                        let ext = v.get("ext").and_then(|x| x.as_str()).unwrap_or("");
                        format!("{}{}", link, ext)
                    })
                })
        } else {
            let trimmed = stdout_str.trim().to_string();
            if trimmed.starts_with("http") {
                Some(trimmed)
            } else {
                None
            }
        }
    } else {
        None
    };

    if let Some(url) = final_url {
        Ok(url)
    } else {
        let captured_err = last_err_msg.lock().unwrap().clone();
        let err_detail = if !captured_err.is_empty() {
            captured_err
        } else if !stdout_str.trim().is_empty() {
            stdout_str.trim().to_string()
        } else {
            match exit_code {
                35 => "SSL/TLS connect error (handshake reset by peer or ISP)".to_string(),
                28 => "Operation timed out".to_string(),
                7 => "Failed to connect to host".to_string(),
                _ => format!("Transfer failed (curl exit code {})", exit_code),
            }
        };
        Err((exit_code, err_detail))
    }
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        let msg = serde_json::json!({
            "type": "error",
            "message": "Usage: carbon-drop-engine <host> <file_path>"
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
        std::process::exit(1);
    }

    let host_raw = args[1].trim();
    let host = host_raw.to_lowercase();

    // Sanitize incoming file_path: strip file:// and URL-decode spaces/symbols
    let raw_file_arg = args[2].clone();
    let cleaned = raw_file_arg.trim().trim_start_matches("file://");
    let file_path = urlencoding::decode(cleaned)
        .map(|s| s.into_owned())
        .unwrap_or_else(|_| cleaned.to_string());

    let path = std::path::Path::new(&file_path);
    if !path.exists() {
        let msg = serde_json::json!({
            "type": "error",
            "message": format!("File not found: {}", file_path)
        });
        println!("{}", msg);
        let _ = std::io::stdout().flush();
        std::process::exit(1);
    }

    let metadata = match std::fs::metadata(path) {
        Ok(m) => m,
        Err(e) => {
            let msg = serde_json::json!({
                "type": "error",
                "message": format!("Cannot read file metadata: {}", e)
            });
            println!("{}", msg);
            let _ = std::io::stdout().flush();
            std::process::exit(1);
        }
    };

    let file_len = metadata.len();
    let total_mb = (file_len as f64) / (1024.0 * 1024.0);
    let file_name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();
    let safe_file_name = file_name.replace(' ', "_");

    // Print initial progress immediately
    let initial_status = format!("0% (0.0 / {:.1} MB) • Starting...", total_mb);
    let init_progress = serde_json::json!({
        "type": "progress",
        "percent": 0.0,
        "status": initial_status
    });
    println!("{}", init_progress);
    let _ = std::io::stdout().flush();

    // Primary upload execution
    match execute_upload(&host, &file_path, &safe_file_name, total_mb, false).await {
        Ok(url) => {
            let msg = serde_json::json!({
                "type": "complete",
                "url": url
            });
            println!("{}", msg);
            let _ = std::io::stdout().flush();
        }
        Err((exit_code, err_detail)) => {
            // Auto-retry on TLS Exit 35 for Buzzheavier: switch to multi-GB mirror filebin.net
            if (host.starts_with("buzz") || host.contains("buzz")) && exit_code == 35 {
                let retry_msg = serde_json::json!({
                    "type": "progress",
                    "percent": 0.0,
                    "status": "TLS handshake reset (exit 35) • Seamlessly switching to high-capacity mirror..."
                });
                println!("{}", retry_msg);
                let _ = std::io::stdout().flush();

                match execute_upload(&host, &file_path, &safe_file_name, total_mb, true).await {
                    Ok(url) => {
                        let msg = serde_json::json!({
                            "type": "complete",
                            "url": url
                        });
                        println!("{}", msg);
                        let _ = std::io::stdout().flush();
                        return;
                    }
                    Err((code, detail)) => {
                        let err_text = format!("Upload failed (exit code {}): {}", code, detail);
                        let msg = serde_json::json!({
                            "type": "error",
                            "message": err_text
                        });
                        println!("{}", msg);
                        let _ = std::io::stdout().flush();
                        std::process::exit(1);
                    }
                }
            }

            let err_text = format!("Upload failed (exit code {}): {}", exit_code, err_detail);
            let msg = serde_json::json!({
                "type": "error",
                "message": err_text
            });
            println!("{}", msg);
            let _ = std::io::stdout().flush();
            std::process::exit(1);
        }
    }
}
