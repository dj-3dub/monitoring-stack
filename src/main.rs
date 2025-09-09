use anyhow::Result;
use clap::Parser;
use serde::Deserialize;
use std::{fs, time::Duration};
use tokio::time::sleep;

// === metrics ===
use axum::{routing::get, Router};
use once_cell::sync::Lazy;
use prometheus::{Encoder, IntCounterVec, IntGaugeVec, Opts, Registry, TextEncoder};
use std::net::SocketAddr;

// global metrics registry
static REGISTRY: Lazy<Registry> = Lazy::new(Registry::new);

// per-check gauges/counters
static CHECK_UP: Lazy<IntGaugeVec> = Lazy::new(|| {
    let g = IntGaugeVec::new(
        Opts::new("pizza_check_up", "Check up (1) / down (0)"),
        &["host", "name"],
    )
    .unwrap();
    REGISTRY.register(Box::new(g.clone())).ok();
    g
});
static CHECK_FAILS: Lazy<IntCounterVec> = Lazy::new(|| {
    let c = IntCounterVec::new(
        Opts::new("pizza_check_fail_total", "Total failures per check"),
        &["host", "name"],
    )
    .unwrap();
    REGISTRY.register(Box::new(c.clone())).ok();
    c
});
static CHECK_LAST_MS: Lazy<IntGaugeVec> = Lazy::new(|| {
    let g = IntGaugeVec::new(
        Opts::new("pizza_check_last_ms", "Last check latency (ms)"),
        &["host", "name"],
    )
    .unwrap();
    REGISTRY.register(Box::new(g.clone())).ok();
    g
});

// === config ===
#[derive(Parser, Debug)]
struct Args {
    /// Path to config file
    #[arg(long, default_value = "/etc/pizza-ops/config.toml")]
    config: String,
    /// Metrics listen address (e.g. 0.0.0.0:9108)
    #[arg(long, default_value = "0.0.0.0:9108")]
    metrics: String,
}

#[derive(Debug, Deserialize)]
struct Config {
    host: String,
    interval: String,
    #[serde(default)]
    checks: Vec<Check>,
}

#[derive(Debug, Deserialize)]
struct Check {
    #[serde(rename = "type")]
    #[allow(dead_code)]
    check_type: Option<String>, // optional; future use

    name: String,
    url: String,
    expect_status: u16,

    #[serde(default)]
    remediation: Vec<Remediation>,

    #[serde(default)]
    #[allow(dead_code)]
    notify_recovery: bool, // placeholder for future alerting
}

#[derive(Debug, Deserialize)]
struct Remediation {
    action: String,
    cmd: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    let raw = fs::read_to_string(&args.config)?;
    let cfg: Config = toml::from_str(&raw)?;

    println!("== pizza-ops-agent running on host {} ==", cfg.host);

    // spawn metrics server
    let metrics_addr: SocketAddr = args.metrics.parse()?;
    let app = Router::new().route("/metrics", get(metrics));
    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind(metrics_addr)
            .await
            .expect("bind metrics");
        axum::serve(listener, app).await.expect("serve metrics");
    });
    println!("metrics listening on http://{}/metrics", args.metrics);

    let interval = humantime::parse_duration(&cfg.interval)?;
    loop {
        for check in &cfg.checks {
            let name = check.name.as_str();
            let started = std::time::Instant::now();

            match run_http_check(check).await {
                Ok(_) => {
                    let ms = started.elapsed().as_millis() as i64;
                    CHECK_UP.with_label_values(&[&cfg.host, name]).set(1);
                    CHECK_LAST_MS
                        .with_label_values(&[&cfg.host, name])
                        .set(ms);
                    println!("{} OK ({} ms)", name, ms);
                }
                Err(e) => {
                    let ms = started.elapsed().as_millis() as i64;
                    CHECK_UP.with_label_values(&[&cfg.host, name]).set(0);
                    CHECK_LAST_MS
                        .with_label_values(&[&cfg.host, name])
                        .set(ms);
                    CHECK_FAILS.with_label_values(&[&cfg.host, name]).inc();
                    eprintln!("{} FAIL: {e}", name);

                    for r in &check.remediation {
                        if r.action == "command" {
                            let _ = std::process::Command::new("bash")
                                .arg("-lc")
                                .arg(&r.cmd)
                                .status();
                        }
                    }
                }
            }
        }
        sleep(interval).await;
    }
}

async fn run_http_check(check: &Check) -> Result<()> {
    let rsp = reqwest::Client::new()
        .get(&check.url)
        .timeout(Duration::from_secs(5))
        .send()
        .await?;
    if rsp.status().as_u16() != check.expect_status {
        anyhow::bail!("expected {}, got {}", check.expect_status, rsp.status());
    }
    Ok(())
}

// /metrics handler
async fn metrics() -> (axum::http::StatusCode, String) {
    let mut buf = Vec::new();
    let encoder = TextEncoder::new();
    if let Err(e) = encoder.encode(&REGISTRY.gather(), &mut buf) {
        return (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            format!("encode error: {e}"),
        );
    }
    (
        axum::http::StatusCode::OK,
        String::from_utf8(buf).unwrap_or_default(),
    )
}
