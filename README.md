# Monitoring Stack

## Overview

This repository contains a containerized observability platform designed
to provide infrastructure and application monitoring for Linux
environments.

The platform combines metrics collection, visualization, alerting,
endpoint monitoring, automation, and Infrastructure as Code into a
unified deployment workflow.

Key capabilities include:

-   Infrastructure monitoring
-   Container monitoring
-   Service availability monitoring
-   Metrics collection and retention
-   Alerting and notification workflows
-   Automated deployment and validation
-   Infrastructure as Code using Terraform

------------------------------------------------------------------------

## Architecture

The platform consists of the following core components:

-   Prometheus
-   Grafana
-   Alertmanager
-   Blackbox Exporter
-   Node Exporter
-   cAdvisor

Prometheus collects metrics from exporters and monitored services,
stores time-series data, and provides the foundation for alerting and
visualization.

Refer to the architecture diagrams located in:

``` text
docs/architecture.png
docs/architecture.svg
docs/architecture.dot
```

------------------------------------------------------------------------

## Technology Stack

  Category                 Technology
  ------------------------ -------------------
  Infrastructure as Code   Terraform
  Container Runtime        Docker Compose
  Monitoring               Prometheus
  Visualization            Grafana
  Alerting                 Alertmanager
  Host Monitoring          Node Exporter
  Container Monitoring     cAdvisor
  Endpoint Monitoring      Blackbox Exporter
  Automation               GNU Make
  Validation               Python

------------------------------------------------------------------------

## Infrastructure as Code

Terraform configurations are located under:

``` text
terraform/aws/
```

The Terraform configuration provides the foundation for provisioning
monitoring infrastructure in AWS environments.

### Terraform Commands

``` bash
make tf-init
make tf-up
make tf-status
make tf-down
```

### Terraform Validation

``` bash
terraform -chdir=terraform/aws fmt
terraform -chdir=terraform/aws validate
```

------------------------------------------------------------------------

## Deployment

Start the monitoring platform:

``` bash
make up
```

Verify deployment:

``` bash
make status
```

View logs:

``` bash
make logs
```

Stop services:

``` bash
make down
```

------------------------------------------------------------------------

## Operations

Reload Prometheus configuration:

``` bash
make reload-prom
```

Display active Prometheus targets:

``` bash
make targets
```

Display loaded Prometheus rule groups:

``` bash
make rules
```

Configure Blackbox Exporter:

``` bash
make blackbox-setup
```

------------------------------------------------------------------------

## Grafana Management

Verify Grafana health:

``` bash
make grafana-health
```

Import dashboards:

``` bash
make grafana-import-node
make grafana-import-docker
make grafana-import-blackbox
```

Organize dashboards:

``` bash
make dashboards-tidy
```

------------------------------------------------------------------------

## Validation

Smoke testing is performed through an automated Python validation
workflow.

Run validation:

``` bash
make smoke-test
```

Validation verifies:

-   Grafana availability
-   Prometheus availability
-   Exporter availability
-   Metrics ingestion
-   Basic monitoring functionality

------------------------------------------------------------------------

## Project Structure

``` text
.
├── config/
├── docs/
├── scripts/
├── terraform/
│   └── aws/
├── tools/
├── compose.yaml
├── Makefile
└── README.md
```

------------------------------------------------------------------------

## Skills Demonstrated

-   Infrastructure as Code (Terraform)
-   Linux Systems Administration
-   Monitoring and Observability
-   Containerization
-   Automation Engineering
-   Configuration Management
-   Incident Response Readiness
-   Platform Engineering Concepts
-   AWS Infrastructure Fundamentals
-   Operational Documentation

------------------------------------------------------------------------

## Future Enhancements

Planned enhancements include:

-   Remote Terraform state management (S3 + DynamoDB)
-   Automated infrastructure provisioning workflows
-   High availability deployment models
-   Centralized log aggregation
-   Cloud-native deployment targets
-   CI/CD pipeline integration
-   Automated backup and recovery workflows

------------------------------------------------------------------------

## License

Copyright (c) 2026 Tim Heverin

This project is licensed under the MIT License. See the LICENSE file for full license terms.
