# AI Agent Portfolio Project - Context & Decisions

## Project Overview

Building a personal portfolio website maintained by AI agents with local K3s dev environment and AWS ECS production deployment.

## Key Decisions

- **Agent Framework**: LangGraph (orchestration) + CrewAI (specialized workers)
- **LLM**: Claude API (primary), GPT-4 (fallback)
- **Local Dev**: K3s in Multipass VMs (fully laptop-contained, including MariaDB)
- **Production**: AWS ECS Fargate + RDS MariaDB + SQS
- **Database**: MariaDB (local & prod)

## Agent Roles

1. **Infrastructure Agent**: Manages Terraform, AWS resources, deployments
2. **Website Agent**: Creates and maintains portfolio content and code
3. **QA/Security Agent**: Tests, security scanning, code review
4. **Supervisor Agent**: Orchestrates tasks, ensures quality, escalates issues

## Current Phase

Setting up local development environment in Multipass with K3s and MariaDB.

## Next Steps

1. Audit existing local dev code
2. Build fully laptop-contained Multipass environment
3. Implement first agent (Infrastructure)
