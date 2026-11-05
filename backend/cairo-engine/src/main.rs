use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, BufReader, Write};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LyricLine {
    pub time: u64,
    pub text: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LyricsPayload {
    pub synced: bool,
    pub lines: Vec<LyricLine>,
}

fn parse_timestamp(tag: &str) -> Option<u64> {
    let parts: Vec<&str> = tag.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let minutes: u64 = parts[0].trim().parse().ok()?;
    let sec_parts: Vec<&str> = parts[1].split('.').collect();
    if sec_parts.is_empty() {
        return None;
    }
    let seconds: u64 = sec_parts[0].trim().parse().ok()?;
    let frac_ms: u64 = if sec_parts.len() > 1 {
        let frac_str = sec_parts[1].trim();
        match frac_str.len() {
            1 => frac_str.parse::<u64>().ok()? * 100,
            2 => frac_str.parse::<u64>().ok()? * 10,
            3 => frac_str.parse::<u64>().ok()?,
            _ => {
                if frac_str.len() > 3 {
                    frac_str[..3].parse::<u64>().ok()?
                } else {
                    0
                }
            }
        }
    } else {
        0
    };
    Some(minutes * 60_000 + seconds * 1_000 + frac_ms)
}

fn condense_lines(parsed_lines: Vec<LyricLine>) -> Vec<LyricLine> {
    let mut condensed_lines: Vec<LyricLine> = Vec::new();
    let mut i = 0;

    while i < parsed_lines.len() {
        let mut count = 1;
        let current_text = parsed_lines[i].text.trim().to_lowercase();

        // Look ahead to find consecutive duplicates
        while i + count < parsed_lines.len()
            && parsed_lines[i + count].text.trim().to_lowercase() == current_text
        {
            count += 1;
        }

        let mut final_text = parsed_lines[i].text.clone();
        if count > 1 {
            final_text = format!("{} x{}", final_text, count);
        }

        condensed_lines.push(LyricLine {
            time: parsed_lines[i].time, // Keep the timestamp of the first instance
            text: final_text,
        });

        i += count; // Skip past the duplicates
    }

    condensed_lines
}

fn parse_lrc(lrc_text: &str) -> Vec<LyricLine> {
    let mut lines = Vec::new();
    for raw_line in lrc_text.lines() {
        let trimmed = raw_line.trim();
        if !trimmed.starts_with('[') {
            continue;
        }
        if let Some(close_idx) = trimmed.find(']') {
            let tag = &trimmed[1..close_idx];
            let text = trimmed[close_idx + 1..].trim();
            if let Some(ms) = parse_timestamp(tag) {
                if !text.is_empty() {
                    lines.push(LyricLine {
                        time: ms,
                        text: text.to_string(),
                    });
                }
            }
        }
    }
    lines.sort_by_key(|l| l.time);
    condense_lines(lines)
}

fn fetch_lyrics_waterfall(title: &str, artist: &str) -> LyricsPayload {
    let clean_title = title.trim();
    let clean_artist = artist.trim();

    if clean_title.is_empty() {
        return LyricsPayload {
            synced: false,
            lines: vec![LyricLine {
                time: 0,
                text: "No lyrics available.".to_string(),
            }],
        };
    }

    let mut untimed_fallback: Option<String> = None;

    // --- STEP 1: LRCLIB ---
    let lrclib_url = format!(
        "https://lrclib.net/api/get?track_name={}&artist_name={}",
        urlencoding::encode(clean_title),
        urlencoding::encode(clean_artist)
    );

    if let Ok(mut resp) = ureq::get(&lrclib_url)
        .header("User-Agent", "carbon-cairo-engine/1.0 (Linux; x86_64)")
        .call()
    {
        #[derive(Deserialize)]
        struct LrclibResponse {
            #[serde(rename = "syncedLyrics")]
            synced_lyrics: Option<String>,
            #[serde(rename = "plainLyrics")]
            plain_lyrics: Option<String>,
        }

        if let Ok(data) = resp.body_mut().read_json::<LrclibResponse>() {
            if let Some(synced) = data.synced_lyrics {
                let parsed = parse_lrc(&synced);
                if !parsed.is_empty() {
                    return LyricsPayload {
                        synced: true,
                        lines: parsed,
                    };
                }
            }
            if let Some(plain) = data.plain_lyrics {
                if !plain.trim().is_empty() {
                    untimed_fallback = Some(plain);
                }
            }
        }
    }

    // --- STEP 2: NETEASE CLOUD MUSIC FALLBACK ---
    let search_query = format!("{} {}", clean_artist, clean_title);
    let search_url = "https://music.163.com/api/search/get";
    let search_body = format!(
        "s={}&type=1&limit=5",
        urlencoding::encode(&search_query)
    );

    if let Ok(mut resp) = ureq::post(search_url)
        .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64)")
        .header("Content-Type", "application/x-www-form-urlencoded")
        .header("Cookie", "os=pc")
        .send(search_body.as_bytes())
    {
        #[derive(Deserialize)]
        struct NeteaseSong {
            id: Option<u64>,
        }
        #[derive(Deserialize)]
        struct NeteaseResult {
            songs: Option<Vec<NeteaseSong>>,
        }
        #[derive(Deserialize)]
        struct NeteaseSearchResp {
            result: Option<NeteaseResult>,
        }

        if let Ok(search_data) = resp.body_mut().read_json::<NeteaseSearchResp>() {
            if let Some(songs) = search_data.result.and_then(|r| r.songs) {
                if let Some(first_song) = songs.into_iter().next() {
                    if let Some(song_id) = first_song.id {
                        let lyric_url = format!(
                            "https://music.163.com/api/song/lyric?id={}&lv=1&kv=1&tv=-1",
                            song_id
                        );
                        if let Ok(mut lyr_resp) = ureq::get(&lyric_url)
                            .header("User-Agent", "Mozilla/5.0")
                            .call()
                        {
                            #[derive(Deserialize)]
                            struct NeteaseLrc {
                                lyric: Option<String>,
                            }
                            #[derive(Deserialize)]
                            struct NeteaseLyricResp {
                                lrc: Option<NeteaseLrc>,
                            }

                            if let Ok(lyr_data) = lyr_resp.body_mut().read_json::<NeteaseLyricResp>() {
                                if let Some(lrc_str) = lyr_data.lrc.and_then(|l| l.lyric) {
                                    let parsed = parse_lrc(&lrc_str);
                                    if !parsed.is_empty() {
                                        return LyricsPayload {
                                            synced: true,
                                            lines: parsed,
                                        };
                                    } else if !lrc_str.trim().is_empty() && untimed_fallback.is_none() {
                                        untimed_fallback = Some(lrc_str);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- STEP 3: UNTIMED FALLBACK ---
    if let Some(plain) = untimed_fallback {
        let lines: Vec<LyricLine> = plain
            .lines()
            .map(|l| l.trim())
            .filter(|l| !l.is_empty())
            .map(|l| LyricLine {
                time: 0,
                text: l.to_string(),
            })
            .collect();
        let condensed = condense_lines(lines);
        if !condensed.is_empty() {
            return LyricsPayload {
                synced: false,
                lines: condensed,
            };
        }
    }

    // --- STEP 4: EMPTY FALLBACK ---
    LyricsPayload {
        synced: false,
        lines: vec![LyricLine {
            time: 0,
            text: "No lyrics available.".to_string(),
        }],
    }
}

fn emit_payload(payload: &LyricsPayload) {
    if let Ok(json_str) = serde_json::to_string(payload) {
        println!("{}", json_str);
        let _ = io::stdout().flush();
    }
}

fn query_current_playerctl_metadata() -> Option<(String, String)> {
    let output = Command::new("playerctl")
        .args(["metadata", "--format", "{{title}}|||{{artist}}"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if text.is_empty() {
        return None;
    }
    let parts: Vec<&str> = text.split("|||").collect();
    let title = parts.get(0).copied().unwrap_or("").trim().to_string();
    let artist = parts.get(1).copied().unwrap_or("").trim().to_string();
    Some((title, artist))
}

fn main() {
    let mut last_title = String::new();
    let mut last_artist = String::new();

    // Initial check on startup:
    if let Some((init_title, init_artist)) = query_current_playerctl_metadata() {
        if !init_title.is_empty() {
            let payload = fetch_lyrics_waterfall(&init_title, &init_artist);
            emit_payload(&payload);
            last_title = init_title;
            last_artist = init_artist;
        }
    }

    // Continuous event loop tracking MPRIS changes
    loop {
        let child = Command::new("playerctl")
            .args(["--follow", "metadata", "--format", "{{title}}|||{{artist}}"])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn();

        match child {
            Ok(mut process) => {
                if let Some(stdout) = process.stdout.take() {
                    let reader = BufReader::new(stdout);
                    for line_res in reader.lines() {
                        let line = match line_res {
                            Ok(l) => l,
                            Err(_) => break,
                        };
                        let trimmed = line.trim();
                        if trimmed.is_empty() {
                            continue;
                        }
                        let parts: Vec<&str> = trimmed.split("|||").collect();
                        let title = parts.get(0).copied().unwrap_or("").trim().to_string();
                        let artist = parts.get(1).copied().unwrap_or("").trim().to_string();

                        if title != last_title || artist != last_artist {
                            last_title = title.clone();
                            last_artist = artist.clone();

                            if !title.is_empty() {
                                let payload = fetch_lyrics_waterfall(&title, &artist);
                                emit_payload(&payload);
                            }
                        }
                    }
                }
                let _ = process.wait();
            }
            Err(_) => {
                thread::sleep(Duration::from_millis(2000));
            }
        }

        // Brief cooldown before reconnecting if playerctl exited
        thread::sleep(Duration::from_millis(1500));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_timestamp() {
        assert_eq!(parse_timestamp("00:12.50"), Some(12500));
        assert_eq!(parse_timestamp("01:05.123"), Some(65123));
        assert_eq!(parse_timestamp("02:00.0"), Some(120000));
        assert_eq!(parse_timestamp("invalid"), None);
    }

    #[test]
    fn test_parse_lrc() {
        let lrc = "[00:01.00] Line 1\n[00:05.50] Line 2\n[00:03.20] Line 1.5\n";
        let parsed = parse_lrc(lrc);
        assert_eq!(parsed.len(), 3);
        assert_eq!(parsed[0].time, 1000);
        assert_eq!(parsed[0].text, "Line 1");
        assert_eq!(parsed[1].time, 3200);
        assert_eq!(parsed[1].text, "Line 1.5");
        assert_eq!(parsed[2].time, 5500);
        assert_eq!(parsed[2].text, "Line 2");
    }

    #[test]
    fn test_empty_fallback() {
        let empty = fetch_lyrics_waterfall("", "");
        assert!(!empty.synced);
        assert_eq!(empty.lines.len(), 1);
        assert_eq!(empty.lines[0].time, 0);
        assert_eq!(empty.lines[0].text, "No lyrics available.");
    }

    #[test]
    fn test_condense_lines() {
        let input = vec![
            LyricLine {
                time: 1000,
                text: "Guess who's back".to_string(),
            },
            LyricLine {
                time: 3000,
                text: "guess who's back".to_string(),
            },
            LyricLine {
                time: 5000,
                text: "  GUESS WHO'S BACK  ".to_string(),
            },
            LyricLine {
                time: 7000,
                text: "Back again".to_string(),
            },
        ];
        let condensed = condense_lines(input);
        assert_eq!(condensed.len(), 2);
        assert_eq!(condensed[0].time, 1000);
        assert_eq!(condensed[0].text, "Guess who's back x3");
        assert_eq!(condensed[1].time, 7000);
        assert_eq!(condensed[1].text, "Back again");
    }
}
