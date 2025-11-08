# Part 6: Monitoring & Observability - Production Implementation

## 🎯 Overview

This directory contains **production-ready monitoring and observability configurations** for Kubernetes, based on the principles outlined in Part 6 of the article series. The implementation provides complete visibility into your production environment through metrics, logs, and traces.

## 📋 What's Inside

### Core Components

- **Prometheus Stack** - Metrics collection and alerting
- **Thanos** - Long-term metrics storage and global querying
- **Loki** - Log aggregation and querying
- **Jaeger** - Distributed tracing
- **Grafana** - Unified visualization
- **AlertManager** - Intelligent alert routing

### Architecture

```
Application Pods
      |
      |-- Metrics (15s scrape) --> Prometheus --> Thanos (S3)
      |
      |-- Logs (stdout/stderr) --> Promtail --> Loki (S3)
      |
      |-- Traces (5% sample) --> OTel Collector --> Jaeger (ES)
      |
      v
   Grafana (Unified View)
      |
      v
  AlertManager (PagerDuty/Slack)
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.31+)
- `kubectl` configured
- `helm` v3.13+
- S3/GCS bucket for long-term storage
- (Optional) Elasticsearch for Jaeger

### 1. Deploy Base Monitoring Stack

```bash
# Deploy Prometheus Operator
./scripts/deploy-prometheus.sh

# Deploy Thanos
./scripts/deploy-thanos.sh

# Deploy Loki
./scripts/deploy-loki.sh

# Deploy Jaeger
./scripts/deploy-jaeger.sh

# Import Grafana Dashboards
./scripts/import-dashboards.sh
```

### 2. Validate Deployment

```bash
# Run comprehensive validation
./scripts/validate-monitoring.sh

# Expected output:
# ✓ All monitoring pods running (24/24)
# ✓ All Prometheus targets up (156/156)
# ✓ Loki receiving logs (47 streams)
# ✓ Grafana dashboards loaded (15 dashboards)
# ✓ AlertManager receiving alerts
# ✓ Thanos components running (6 pods)
```

### 3. Access Dashboards

```bash
# Grafana (username: admin, password: from secret)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000

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

## 📁 Directory Structure

```
part-06-monitoring/
├── README.md                          # This file
├── prometheus/
│   ├── kube-prometheus-stack-values.yaml   # Main Prometheus config
│   ├── servicemonitors/
│   │   ├── patient-api-monitor.yaml
│   │   ├── auth-service-monitor.yaml
│   │   └── database-monitor.yaml
│   ├── rules/
│   │   ├── alerts.yaml                     # Production alert rules
│   │   ├── slo-recording-rules.yaml        # SLO calculations
│   │   └── recording-rules.yaml            # Performance optimization
│   └── alertmanager/
│       └── alertmanager-config.yaml        # Alert routing config
├── thanos/
│   ├── thanos-values.yaml                  # Thanos configuration
│   └── s3-config.yaml                      # S3 backend config
├── loki/
│   ├── loki-values.yaml                    # Loki configuration
│   ├── promtail-values.yaml                # Log shipping config
│   └── retention-policies.yaml             # Log retention rules
├── jaeger/
│   ├── jaeger-values.yaml                  # Jaeger configuration
│   ├── otel-collector-values.yaml          # OpenTelemetry config
│   └── sampling-config.yaml                # Trace sampling rules
├── grafana/
│   ├── dashboards/
│   │   ├── kubernetes-cluster.json
│   │   ├── application-red-metrics.json
│   │   ├── slo-dashboard.json
│   │   ├── database-performance.json
│   │   └── alert-overview.json
│   └── datasources/
│       └── datasources.yaml
├── application-instrumentation/
│   ├── go/
│   │   ├── metrics-example.go              # Go metrics instrumentation
│   │   ├── logging-example.go              # Structured logging
│   │   └── tracing-example.go              # Distributed tracing
│   ├── python/
│   │   ├── metrics_example.py
│   │   ├── logging_example.py
│   │   └── tracing_example.py
│   └── java/
│       ├── MetricsExample.java
│       ├── LoggingExample.java
│       └── TracingExample.java
├── scripts/
│   ├── deploy-prometheus.sh                # Deploy Prometheus stack
│   ├── deploy-thanos.sh                    # Deploy Thanos
│   ├── deploy-loki.sh                      # Deploy Loki
│   ├── deploy-jaeger.sh                    # Deploy Jaeger
│   ├── import-dashboards.sh                # Import Grafana dashboards
│   ├── validate-monitoring.sh              # Comprehensive validation
│   ├── generate-test-load.sh               # Load testing
│   └── backup-monitoring.sh                # Backup configs
├── examples/
│   ├── healthcare-platform/
│   │   ├── deployment.yaml
│   │   ├── servicemonitor.yaml
│   │   └── alerts.yaml
│   └── synthetic-monitoring/
│       ├── blackbox-config.yaml
│       └── probes.yaml
├── runbooks/
│   ├── high-error-rate.md
│   ├── latency-slo-breach.md
│   ├── pod-crashloop.md
│   ├── database-connection-pool.md
│   └── disk-space-alert.md
└── docs/
    ├── architecture.md                     # Architecture overview
    ├── metrics-guide.md                    # Metrics instrumentation guide
    ├── logging-guide.md                    # Logging best practices
    ├── tracing-guide.md                    # Distributed tracing guide
    ├── alerting-strategy.md                # Alert design principles
    ├── slo-guide.md                        # SLO/SLI implementation
    ├── troubleshooting.md                  # Common issues
    └── cost-optimization.md                # Cost management
```

## 🔧 Configuration

### Prometheus Configuration

The Prometheus stack is deployed using the kube-prometheus-stack Helm chart with custom values:

**Key Features:**
- ✅ 15-second scrape interval
- ✅ 15-day local retention
- ✅ High availability (2 replicas)
- ✅ Remote write to Thanos
- ✅ Automatic service discovery
- ✅ Resource limits and requests

**Configuration File:** `prometheus/kube-prometheus-stack-values.yaml`

### Thanos Configuration

Thanos extends Prometheus with unlimited retention and global querying:

**Components:**
- **Query**: Unified query interface
- **Store Gateway**: Access historical data
- **Compactor**: Downsample and compact
- **Receiver**: Remote write endpoint

**Storage:**
- Raw data: 30 days
- 5-minute resolution: 90 days
- 1-hour resolution: 1 year

**Configuration File:** `thanos/thanos-values.yaml`

### Loki Configuration

Loki provides cost-effective log aggregation:

**Key Features:**
- ✅ Label-based indexing (not full-text)
- ✅ S3 backend for storage
- ✅ Distributed mode (read/write separation)
- ✅ Retention by label (30-180 days)
- ✅ JSON log parsing

**Configuration File:** `loki/loki-values.yaml`

### Jaeger Configuration

Jaeger provides distributed tracing:

**Key Features:**
- ✅ OpenTelemetry Collector integration
- ✅ 5% sampling (100% for errors)
- ✅ Elasticsearch backend
- ✅ 7-day retention
- ✅ Service dependency graphs

**Configuration Files:**
- `jaeger/jaeger-values.yaml`
- `jaeger/otel-collector-values.yaml`

## 📊 Pre-Built Dashboards

### 1. Kubernetes Cluster Overview
- Node resource usage (CPU, memory, disk)
- Pod status and distribution
- Network traffic
- PV usage

### 2. Application RED Metrics
- Request rate
- Error rate
- Duration (latency percentiles)

### 3. SLO Performance
- Availability tracking
- Error budget consumption
- Latency SLO compliance

### 4. Database Performance
- Connection pool utilization
- Query duration percentiles
- Transaction rate
- Slow query detection

### 5. Alert Overview
- Active alerts
- Alert history
- MTTR metrics
- Silence management

## 🚨 Alert Rules

### Critical Alerts (PagerDuty)
- Service completely down
- Error rate > 5%
- Latency SLO breach (p95 > 2s)
- Database connection pool exhausted
- Pod OOMKill imminent

### Warning Alerts (Slack)
- Elevated error rate (1-5%)
- High memory usage (85%)
- Pod restart loop
- Slow database queries

**All alerts include:**
- Clear summary and description
- Runbook link
- Dashboard link
- Suggested actions

**Alert Files:**
- `prometheus/rules/alerts.yaml`
- `prometheus/alertmanager/alertmanager-config.yaml`

## 📈 SLO Tracking

### Defined SLOs

**Patient API:**
- **Availability**: 99.9% (43.2 min downtime/month)
- **Latency**: 95% of requests < 500ms
- **Throughput**: > 100 req/s sustained

**Error Budget Alerts:**
- Fast burn rate (30x): Critical
- Moderate burn rate (10x): Warning
- Budget exhausted: Feature freeze

**Configuration:** `prometheus/rules/slo-recording-rules.yaml`

## 🧪 Testing

### Generate Test Load

```bash
# Generate traffic to verify metrics
./scripts/generate-test-load.sh

# This will:
# - Send 10,000 requests
# - Mix of success and error responses
# - Verify metrics appear in Prometheus
# - Validate logs in Loki
# - Check traces in Jaeger
```

### Validation Checklist

```bash
# Run full validation suite
./scripts/validate-monitoring.sh

# Manual checks:
kubectl get pods -n monitoring
kubectl get servicemonitors -n monitoring
kubectl get prometheusrules -n monitoring
```

## 💰 Cost Optimization

### Storage Costs (Monthly - AWS us-east-1)

```
Prometheus:
  - EBS (100GB × 2): $20
  - Compute (t3.large × 2): $120

Thanos:
  - S3 (2TB): $46
  - Compute (t3.medium × 4): $120

Loki:
  - S3 (500GB): $12
  - Compute (t3.large × 3): $180

Jaeger:
  - Elasticsearch (3 nodes): $280
  - Compute: $60

Grafana:
  - Compute (t3.small): $30

Total: ~$886/month
Cost per request: $0.00006
```

### Optimization Tips

1. **Use Spot Instances**: Save 70% on compute
2. **Optimize Retention**: Balance history vs cost
3. **Efficient Labeling**: Avoid high cardinality
4. **Smart Sampling**: 5% traces, 100% errors
5. **Log Filtering**: Drop debug logs in production

**See:** `docs/cost-optimization.md`

## 🔍 Troubleshooting

### Common Issues

**Prometheus OOM**
```bash
# Check series count
kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -- \
  curl localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName'

# If > 10M series, check for high cardinality labels
```

**Loki Not Receiving Logs**
```bash
# Check Promtail pods
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail --tail=100

# Verify Loki ingester
kubectl logs -n monitoring -l app.kubernetes.io/component=write
```

**Alerts Not Firing**
```bash
# Check AlertManager config
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Test alert routing
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
curl -XPOST http://localhost:9093/api/v1/alerts -d '[{...}]'
```

**Full Guide:** `docs/troubleshooting.md`

## 📚 Documentation

- **[Architecture Overview](docs/architecture.md)** - System design and components
- **[Metrics Guide](docs/metrics-guide.md)** - Instrumentation patterns
- **[Logging Guide](docs/logging-guide.md)** - Structured logging best practices
- **[Tracing Guide](docs/tracing-guide.md)** - Distributed tracing setup
- **[Alerting Strategy](docs/alerting-strategy.md)** - Alert design principles
- **[SLO Guide](docs/slo-guide.md)** - Service Level Objectives
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Cost Optimization](docs/cost-optimization.md)** - Reduce monitoring costs

## 🎯 Real-World Examples

### Healthcare Platform

Complete monitoring setup for a healthcare platform processing 500K requests/day:

```bash
cd examples/healthcare-platform

# Deploy application with monitoring
kubectl apply -f deployment.yaml
kubectl apply -f servicemonitor.yaml

# Deploy custom alerts
kubectl apply -f alerts.yaml

# Verify metrics
kubectl port-forward -n healthcare svc/patient-api 8080:8080
curl http://localhost:8080/metrics
```

**Includes:**
- Patient API with instrumentation
- Custom SLO tracking
- HIPAA compliance logging
- Production alert rules

## 🔄 Continuous Improvement

### Day 2 Operations

1. **Review Alert Frequency**
   - Tune noisy alerts
   - Add missing alerts
   - Update thresholds

2. **Optimize Queries**
   - Add recording rules for slow queries
   - Use Prometheus optimization tools

3. **Dashboard Refinement**
   - Add custom business metrics
   - Create team-specific views

4. **Cost Management**
   - Review retention policies
   - Optimize sampling rates
   - Right-size resources

## 🤝 Contributing

Improvements welcome! Please:

1. Test changes thoroughly
2. Update documentation
3. Follow existing patterns
4. Add examples where helpful

## 📄 License

MIT License - See [LICENSE](../LICENSE)

## 🔗 Related Articles

- **Part 5**: [Security Configuration](../part-05-security/README.md)
- **Part 7**: [Disaster Recovery](../part-07-disaster-recovery/README.md)
- **Part 8**: [Cost Optimization](../part-08-cost-optimization/README.md)

---

**Questions or Issues?** Open an issue or start a discussion!

**⭐ If this helped you**, please star the repository and share with your team!