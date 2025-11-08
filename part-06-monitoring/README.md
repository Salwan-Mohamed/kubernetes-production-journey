# 🔍 Part 6: Monitoring & Observability - Production Eyes and Ears

> **The 3 AM Wake-Up Call That Changed Everything**: Complete production-grade monitoring stack with metrics, logs, traces, and intelligent alerting.

[![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
[![Loki](https://img.shields.io/badge/Loki-FDD835?logo=loki&logoColor=black)](https://grafana.com/oss/loki/)
[![Jaeger](https://img.shields.io/badge/Jaeger-00BCD4?logo=jaeger&logoColor=white)](https://www.jaegertracing.io/)

---

## 📋 Table of Contents

- [Overview](#overview)
- [What This Part Covers](#what-this-part-covers)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [Architecture](#architecture)
- [Validation](#validation)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)
- [Related Articles](#related-articles)

---

## 🎯 Overview

This section provides **production-ready monitoring and observability** configurations for Kubernetes, implementing the three pillars:

- 📊 **Metrics** - Prometheus + Thanos (What's wrong?)
- 📝 **Logs** - Loki + Promtail (Why did it happen?)
- 🔗 **Traces** - Jaeger + OpenTelemetry (Where in the flow?)
- 📈 **Visualization** - Grafana (Unified dashboards)
- 🚨 **Alerting** - AlertManager (Intelligent routing)

### Real-World Scenario

**Healthcare Platform**: 50,000 patients, 500K requests/day
- **Before monitoring**: 4-hour MTTR, $100K/month incident costs
- **After monitoring**: 15-minute MTTR, $2.5K/month incident costs
- **ROI**: 11,000% return on investment

### Key Features

✅ **Complete observability stack** - Metrics, logs, traces unified  
✅ **Production-grade configs** - HA, retention policies, resource limits  
✅ **Intelligent alerting** - SLO-based, symptom-focused, runbook-linked  
✅ **Cost-optimized** - ~$886/month for full stack  
✅ **Pre-built dashboards** - 15+ ready-to-use Grafana dashboards  
✅ **Application instrumentation** - Go, Python, Node.js examples  
✅ **Validation scripts** - Automated health checks  

---

## 📦 What This Part Covers

### 1. Metrics Stack (Prometheus + Thanos)
- Prometheus Operator deployment
- Service monitors and pod monitors
- Recording rules for SLOs
- Thanos for long-term storage
- High-cardinality best practices

### 2. Logging Stack (Loki + Promtail)
- Loki distributed deployment
- Promtail DaemonSet configuration
- Log retention policies
- Structured logging examples
- LogQL query patterns

### 3. Tracing Stack (Jaeger + OpenTelemetry)
- OpenTelemetry Collector
- Jaeger deployment with Elasticsearch
- Application instrumentation
- Sampling strategies
- Trace correlation

### 4. Visualization (Grafana)
- Dashboard provisioning
- Data source configuration
- Alert visualization
- Mobile access for on-call
- Role-based access control

### 5. Alerting (AlertManager)
- Alert rule definitions
- Routing configuration
- PagerDuty integration
- Slack integration
- Inhibition rules

### 6. SLO & Error Budgets
- SLO definitions
- Error budget tracking
- Burn rate alerts
- Error budget policy

---

## 📁 Repository Structure

```
part-06-monitoring/
├── README.md                           # This file
├── docs/
│   ├── ARCHITECTURE.md                 # Architecture overview
│   ├── DEPLOYMENT_GUIDE.md            # Step-by-step deployment
│   ├── TROUBLESHOOTING.md             # Common issues and solutions
│   ├── COST_ANALYSIS.md               # Cost breakdown and optimization
│   └── BEST_PRACTICES.md              # Monitoring best practices
│
├── prometheus/
│   ├── README.md                       # Prometheus setup guide
│   ├── kube-prometheus-stack-values.yaml  # Helm values
│   ├── servicemonitors/
│   │   ├── patient-api-monitor.yaml
│   │   ├── auth-service-monitor.yaml
│   │   └── database-monitor.yaml
│   ├── rules/
│   │   ├── slo-recording-rules.yaml   # SLO calculations
│   │   ├── alerts.yaml                # Alert definitions
│   │   └── resource-alerts.yaml       # Resource alerts
│   └── scripts/
│       ├── deploy-prometheus.sh
│       └── validate-targets.sh
│
├── thanos/
│   ├── README.md                       # Thanos setup guide
│   ├── thanos-values.yaml             # Helm values
│   ├── s3-config.yaml                 # S3 backend config
│   └── scripts/
│       └── deploy-thanos.sh
│
├── loki/
│   ├── README.md                       # Loki setup guide
│   ├── loki-values.yaml               # Helm values (distributed)
│   ├── promtail-values.yaml           # Promtail DaemonSet config
│   ├── retention-policies.yaml        # Retention configuration
│   └── scripts/
│       ├── deploy-loki.sh
│       └── validate-logs.sh
│
├── jaeger/
│   ├── README.md                       # Jaeger setup guide
│   ├── jaeger-values.yaml             # Helm values
│   ├── otel-collector-values.yaml     # OpenTelemetry Collector
│   ├── sampling-strategies.yaml       # Sampling configuration
│   └── scripts/
│       ├── deploy-jaeger.sh
│       └── test-tracing.sh
│
├── grafana/
│   ├── README.md                       # Grafana setup guide
│   ├── dashboards/
│   │   ├── kubernetes-cluster.json
│   │   ├── application-red-metrics.json
│   │   ├── slo-dashboard.json
│   │   ├── database-performance.json
│   │   └── alert-overview.json
│   ├── datasources/
│   │   ├── prometheus-datasource.yaml
│   │   ├── loki-datasource.yaml
│   │   └── jaeger-datasource.yaml
│   └── scripts/
│       ├── import-dashboards.sh
│       └── setup-datasources.sh
│
├── alertmanager/
│   ├── README.md                       # AlertManager guide
│   ├── alertmanager-config.yaml       # Complete configuration
│   ├── routes/
│   │   ├── critical-alerts.yaml
│   │   ├── warning-alerts.yaml
│   │   └── team-routing.yaml
│   ├── receivers/
│   │   ├── pagerduty-receiver.yaml
│   │   └── slack-receiver.yaml
│   └── scripts/
│       ├── test-alert.sh
│       └── validate-routing.sh
│
├── instrumentation/
│   ├── README.md                       # Instrumentation guide
│   ├── go-example/
│   │   ├── main.go                    # Go app with metrics/traces
│   │   ├── metrics.go
│   │   └── tracing.go
│   ├── python-example/
│   │   ├── app.py                     # Python FastAPI example
│   │   └── requirements.txt
│   └── nodejs-example/
│       ├── index.js                   # Node.js Express example
│       └── package.json
│
├── slo/
│   ├── README.md                       # SLO configuration guide
│   ├── definitions/
│   │   ├── availability-slo.yaml
│   │   ├── latency-slo.yaml
│   │   └── error-budget-policy.yaml
│   └── dashboards/
│       └── slo-tracking.json
│
├── validation/
│   ├── README.md                       # Validation guide
│   ├── validate-monitoring.sh         # Complete health check
│   ├── test-metrics.sh                # Metrics validation
│   ├── test-logs.sh                   # Log ingestion test
│   ├── test-traces.sh                 # Trace validation
│   ├── test-alerts.sh                 # Alert routing test
│   └── load-generator.sh              # Generate test traffic
│
├── examples/
│   ├── healthcare-platform/           # Complete healthcare example
│   │   ├── architecture.md
│   │   ├── metrics-requirements.md
│   │   ├── alert-runbooks/
│   │   └── incident-timeline.md
│   └── real-incident-resolution/
│       └── db-pool-exhaustion.md
│
├── scripts/
│   ├── deploy-all.sh                  # Deploy complete stack
│   ├── upgrade-stack.sh               # Upgrade monitoring stack
│   ├── backup-dashboards.sh           # Backup Grafana dashboards
│   └── generate-load.sh               # Load testing
│
└── terraform/                          # IaC for monitoring infrastructure
    ├── main.tf
    ├── prometheus.tf
    ├── loki.tf
    ├── jaeger.tf
    └── outputs.tf
```

---

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster v1.31+ (with at least 3 nodes)
- `kubectl` configured
- `helm` v3.13+
- Storage class for persistent volumes
- S3-compatible storage (for Thanos and Loki)

### 1. Clone the Repository

```bash
git clone https://github.com/Salwan-Mohamed/kubernetes-production-journey.git
cd kubernetes-production-journey/part-06-monitoring
```

### 2. Configure Environment

```bash
# Copy example configurations
cp .env.example .env

# Edit with your values
vim .env
```

### 3. Deploy Complete Stack (Automated)

```bash
# Deploy everything at once
./scripts/deploy-all.sh
```

**OR** Deploy components individually:

```bash
# 1. Deploy Prometheus
./prometheus/scripts/deploy-prometheus.sh

# 2. Deploy Thanos
./thanos/scripts/deploy-thanos.sh

# 3. Deploy Loki
./loki/scripts/deploy-loki.sh

# 4. Deploy Jaeger
./jaeger/scripts/deploy-jaeger.sh

# 5. Import Grafana dashboards
./grafana/scripts/import-dashboards.sh
```

### 4. Validate Deployment

```bash
# Run comprehensive validation
./validation/validate-monitoring.sh

# Expected output:
# ✓ All monitoring pods running (24/24)
# ✓ All Prometheus targets up (47/47)
# ✓ Loki receiving logs (12 streams)
# ✓ Grafana dashboards loaded (15 dashboards)
# ✓ AlertManager receiving alerts
# ✓ Thanos components running (5 pods)
```

### 5. Access UIs

```bash
# Grafana (port-forward for initial access)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000
# Default login: admin / <check-secret>

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090

# AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open: http://localhost:9093

# Jaeger
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686
# Open: http://localhost:16686
```

---

## 📚 Deployment Guide

For detailed step-by-step instructions, see [DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)

### Quick Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| **Preparation** | 30 min | Configure S3, secrets, namespaces |
| **Prometheus** | 15 min | Deploy Prometheus Operator |
| **Thanos** | 10 min | Add long-term storage |
| **Loki** | 15 min | Deploy logging stack |
| **Jaeger** | 15 min | Deploy tracing |
| **Grafana** | 10 min | Import dashboards |
| **Validation** | 15 min | End-to-end testing |
| **Total** | ~2 hours | Complete monitoring stack |

---

## 🏗️ Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  APPLICATION TIER                            │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │Patient API│   │Auth Service│  │ Database │               │
│  └─────┬────┘   └─────┬────┘   └─────┬────┘               │
│        │ metrics       │ metrics      │ metrics             │
└────────┼───────────────┼──────────────┼─────────────────────┘
         │               │              │
         ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│              COLLECTION TIER                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │Prometheus│   │ Promtail │   │   OTel   │               │
│  │(scrape)  │   │(logs)    │   │Collector │               │
│  └─────┬────┘   └─────┬────┘   └─────┬────┘               │
│        │              │              │                       │
│        ▼              ▼              ▼                       │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │  Thanos  │   │   Loki   │   │  Jaeger  │               │
│  │(storage) │   │(storage) │   │(storage) │               │
│  └─────┬────┘   └─────┬────┘   └─────┬────┘               │
└────────┼───────────────┼──────────────┼─────────────────────┘
         │               │              │
         └───────────────┴──────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │         GRAFANA                │
         │  (Unified Visualization)       │
         └───────────────┬───────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │      ALERTMANAGER              │
         │  (PagerDuty + Slack)          │
         └───────────────────────────────┘
```

For detailed architecture, see [ARCHITECTURE.md](./docs/ARCHITECTURE.md)

---

## ✅ Validation

### Automated Health Checks

```bash
# Complete validation suite
./validation/validate-monitoring.sh

# Individual component checks
./validation/test-metrics.sh      # Prometheus targets
./validation/test-logs.sh         # Loki ingestion
./validation/test-traces.sh       # Jaeger traces
./validation/test-alerts.sh       # Alert routing
```

### Manual Verification Checklist

- [ ] All pods in `monitoring` namespace are `Running`
- [ ] Prometheus scraping all targets (check `/targets`)
- [ ] Loki receiving logs from all namespaces
- [ ] Jaeger showing traces from instrumented services
- [ ] Grafana dashboards loading with data
- [ ] Test alert routes to PagerDuty/Slack
- [ ] SLO dashboards showing current status

---

## 🔧 Troubleshooting

Common issues and solutions:

### Prometheus Not Scraping Targets

```bash
# Check ServiceMonitor labels
kubectl get servicemonitors -n monitoring

# Verify Prometheus ServiceMonitor selector
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector

# Check service labels match
kubectl get svc -n <app-namespace> --show-labels
```

### Loki Not Receiving Logs

```bash
# Check Promtail pods
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=50

# Verify Loki endpoint
kubectl exec -n monitoring <promtail-pod> -- wget -O- http://loki:3100/ready
```

### High Cardinality Issues

```bash
# Check series count
kubectl exec -n monitoring <prometheus-pod> -- wget -O- http://localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName'

# Find high-cardinality metrics
kubectl exec -n monitoring <prometheus-pod> -- wget -O- 'http://localhost:9090/api/v1/label/__name__/values' | jq -r '.data[]' | wc -l
```

For more troubleshooting, see [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)

---

## 💰 Cost Estimation

### Monthly Costs (AWS us-east-1)

| Component | Resources | Monthly Cost |
|-----------|-----------|-------------|
| Prometheus | 2 × t3.large + 200GB EBS | $140 |
| Thanos | 4 × t3.medium + 2TB S3 | $184 |
| Loki | 3 × t3.large + 500GB S3 | $192 |
| Jaeger | 3-node Elasticsearch + compute | $340 |
| Grafana | 1 × t3.small | $30 |
| **Total** | | **~$886/month** |

### Cost per Metric

- **Per request**: $0.00006
- **Per incident prevented**: Priceless
- **ROI**: 11,000% (vs. incident costs)

### Optimization Tips

1. Use Spot instances for non-critical components (30-70% savings)
2. Implement aggressive log filtering (reduce Loki costs)
3. Use 5% trace sampling (reduce Jaeger costs)
4. Enable Thanos downsampling (reduce storage costs)
5. Set appropriate retention periods

For detailed cost analysis, see [COST_ANALYSIS.md](./docs/COST_ANALYSIS.md)

---

## 📖 Related Articles

This code accompanies **Part 6** of the Kubernetes Production Journey series:

- **[Part 1: Introduction](../../README.md)** - The Day 1 framework
- **[Part 2: Infrastructure Provisioning](../part-02-infrastructure/README.md)** - Building the foundation
- **[Part 3: Code Deployment & CI/CD](../part-03-cicd/README.md)** - GitOps and progressive delivery
- **[Part 4: Database Setup](../part-04-database/README.md)** - Data layer best practices
- **[Part 5: Security Configuration](../part-05-security/README.md)** - Zero-trust implementation
- **[Part 6: Monitoring & Observability](./README.md)** - 👈 You are here
- **[Part 7: Disaster Recovery](../part-07-disaster-recovery/README.md)** - *(Coming Soon)*
- **[Part 8: Cost Optimization](../part-08-cost-optimization/README.md)** - *(Coming Soon)*

---

## 🤝 Contributing

Found an issue or have improvements? PRs are welcome!

1. Fork the repository
2. Create your feature branch
3. Test your changes thoroughly
4. Submit a Pull Request

---

## 📄 License

MIT License - See [LICENSE](../../LICENSE) for details

---

## 🌟 Support

⭐ **Star the repository** if this helped you!

📢 **Share your monitoring setup** in [Discussions](https://github.com/Salwan-Mohamed/kubernetes-production-journey/discussions)

💬 **Questions?** Open an [Issue](https://github.com/Salwan-Mohamed/kubernetes-production-journey/issues)

---

<div align="center">

**Built with ❤️ for production reliability**

[🏠 Main Repository](../../) • [📖 Article Series](../../README.md#article-series) • [💬 Discussions](https://github.com/Salwan-Mohamed/kubernetes-production-journey/discussions)

</div>