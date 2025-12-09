# AKS Demo Application - 네트워크 아키텍처 및 CI/CD 실습

Azure Kubernetes Service(AKS)를 활용한 Hub-Spoke 네트워크 아키텍처 구성과 GitHub Actions CI/CD 파이프라인 구현 실습 프로젝트입니다.

## 목차

1. [개념 이해](#1-개념-이해)
2. [아키텍처 구성도](#2-아키텍처-구성도)
3. [실습 환경](#3-실습-환경)
4. [Quick Start](#4-quick-start)
5. [상세 구성 가이드](#5-상세-구성-가이드)
6. [CI/CD 파이프라인](#6-cicd-파이프라인)
7. [운영 명령어](#7-운영-명령어)
8. [트러블슈팅](#8-트러블슈팅)

---

## 1. 개념 이해

### 1.1 AKS를 사용하는 이유

| 기존 VM 방식 | AKS (Kubernetes) 방식 |
|-------------|---------------------|
| 서버마다 환경이 다름 | 컨테이너로 환경 일관성 보장 |
| 수동 배포로 인한 실수 | 선언적 배포 (YAML로 원하는 상태 정의) |
| 스케일링 어려움 | 자동 스케일링 (HPA, Cluster Autoscaler) |
| 장애 복구 느림 | 자동 복구 (Pod 죽으면 자동 재시작) |
| 롤백 복잡 | 롤링 업데이트 / 간편한 롤백 |

### 1.2 AKS 동작 원리

```
❌ 잘못된 이해: "API 서버 주소를 코드에 적용하면 AKS에서 운영된다"

✅ 올바른 이해:
   코드 → Docker Image → ACR Push → kubectl apply → AKS 실행

   - 코드에는 AKS 관련 내용이 전혀 없음
   - 코드를 컨테이너 이미지로 패키징
   - 이미지를 레지스트리(ACR)에 저장
   - kubectl로 AKS에 배포 명령
```

### 1.3 API 서버의 역할

```
┌─────────────────────────────────────────────────────────────┐
│                    AKS Control Plane                         │
│                   (Azure가 무료로 관리)                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  API Server: kubectl 명령을 받아 클러스터 상태 관리   │    │
│  │  etcd: 클러스터 상태 저장소                          │    │
│  │  Scheduler: Pod를 어느 노드에 배치할지 결정          │    │
│  │  Controller: 원하는 상태 유지 (복제본 수 등)         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Worker Nodes                             │
│                   (사용자가 비용 지불)                        │
│        실제 애플리케이션 Pod가 실행되는 곳                    │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Hub-Spoke 네트워크 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Hub VNet (10.0.0.0/16)                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐    │
│  │  Firewall   │ │   Gateway   │ │      Bastion        │    │
│  │ 10.0.1.0/24 │ │ 10.0.2.0/24 │ │    10.0.3.0/26      │    │
│  └─────────────┘ └─────────────┘ └─────────────────────┘    │
└────────────────────────┬────────────────────────────────────┘
                         │ VNet Peering
┌────────────────────────┴────────────────────────────────────┐
│                  Spoke VNet (10.1.0.0/16)                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐    │
│  │ AKS System  │ │  AKS User   │ │    App Gateway      │    │
│  │ 10.1.1.0/24 │ │ 10.1.2.0/23 │ │    10.1.5.0/24      │    │
│  └─────────────┘ └─────────────┘ └─────────────────────┘    │
│  ┌─────────────┐ ┌─────────────────────────────────────┐    │
│  │ Internal LB │ │         Private Endpoint            │    │
│  │ 10.1.4.0/24 │ │         10.1.10.0/24                │    │
│  └─────────────┘ └─────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Hub-Spoke 장점:**
- 중앙 집중식 보안 관리 (Firewall, Bastion)
- 네트워크 분리로 보안 강화
- 공유 서비스 효율적 관리
- 확장성 (새 Spoke 추가 용이)

---

## 2. 아키텍처 구성도

### 2.1 전체 배포 흐름

```
┌──────────┐    Push     ┌──────────┐   Trigger    ┌─────────────────────┐
│  개발자   │ ─────────▶ │  GitHub  │ ───────────▶ │  GitHub Actions     │
└──────────┘             └──────────┘              │  CI/CD Pipeline     │
                                                   └──────────┬──────────┘
                                                              │
                                          ┌───────────────────┼───────────────────┐
                                          │                   │                   │
                                          ▼                   ▼                   ▼
                                   ┌────────────┐     ┌────────────┐     ┌────────────┐
                                   │   Build    │     │   Test     │     │   Push     │
                                   │   Image    │     │            │     │   to ACR   │
                                   └────────────┘     └────────────┘     └─────┬──────┘
                                                                               │
                                                                               ▼
                                                                    ┌──────────────────┐
                                                                    │  Azure Container │
                                                                    │  Registry (ACR)  │
                                                                    └────────┬─────────┘
                                                                             │ Pull
                                                                             ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AKS Cluster                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              kubectl apply                                        │  │
│  │                                    │                                              │  │
│  │                                    ▼                                              │  │
│  │                           ┌───────────────┐                                       │  │
│  │                           │  API Server   │                                       │  │
│  │                           └───────┬───────┘                                       │  │
│  │                                   │                                               │  │
│  │            ┌──────────────────────┼──────────────────────┐                       │  │
│  │            ▼                      ▼                      ▼                       │  │
│  │    ┌─────────────┐        ┌─────────────┐        ┌─────────────┐                │  │
│  │    │   Node 1    │        │   Node 2    │        │   Node 3    │                │  │
│  │    │  ┌───────┐  │        │  ┌───────┐  │        │  ┌───────┐  │                │  │
│  │    │  │ Pod 1 │  │        │  │ Pod 2 │  │        │  │ Pod 3 │  │                │  │
│  │    │  └───────┘  │        │  └───────┘  │        │  └───────┘  │                │  │
│  │    └─────────────┘        └─────────────┘        └─────────────┘                │  │
│  │                                   │                                              │  │
│  │                                   ▼                                              │  │
│  │                        ┌───────────────────┐                                     │  │
│  │                        │  LoadBalancer     │                                     │  │
│  │                        │  External IP      │                                     │  │
│  │                        └─────────┬─────────┘                                     │  │
│  └──────────────────────────────────┼───────────────────────────────────────────────┘  │
└─────────────────────────────────────┼──────────────────────────────────────────────────┘
                                      │
                                      ▼
                              ┌───────────────┐
                              │    사용자      │
                              └───────────────┘
```

### 2.2 IP 주소 계획

| 구성 요소 | CIDR | 용도 |
|----------|------|------|
| Hub VNet | 10.0.0.0/16 | 공유 서비스 |
| ├─ AzureFirewallSubnet | 10.0.1.0/24 | Azure Firewall |
| ├─ GatewaySubnet | 10.0.2.0/24 | VPN/ExpressRoute |
| ├─ AzureBastionSubnet | 10.0.3.0/26 | Azure Bastion |
| └─ snet-management | 10.0.4.0/24 | 관리 서버 |
| **Spoke VNet (AKS)** | **10.1.0.0/16** | **AKS 전용** |
| ├─ snet-aks-system | 10.1.1.0/24 | 시스템 노드 |
| ├─ snet-aks-user | 10.1.2.0/23 | 워크로드 노드 |
| ├─ snet-aks-ilb | 10.1.4.0/24 | 내부 LB |
| ├─ snet-appgw | 10.1.5.0/24 | App Gateway |
| └─ snet-privateendpoint | 10.1.10.0/24 | Private Endpoint |
| Service CIDR | 10.2.0.0/16 | K8s Service |
| DNS Service IP | 10.2.0.10 | CoreDNS |

---

## 3. 실습 환경

### 3.1 생성된 Azure 리소스

| 리소스 타입 | 이름 | 설명 |
|------------|------|------|
| Resource Group | `rg-aks-network-demo` | 전체 리소스 컨테이너 |
| Virtual Network | `vnet-hub` | Hub 네트워크 (10.0.0.0/16) |
| Virtual Network | `vnet-spoke-aks` | Spoke 네트워크 (10.1.0.0/16) |
| VNet Peering | `peer-hub-to-spoke-aks` | Hub→Spoke 연결 |
| VNet Peering | `peer-spoke-aks-to-hub` | Spoke→Hub 연결 |
| NSG | `nsg-aks-nodes` | AKS 노드 보안 그룹 |
| NSG | `nsg-appgw` | App Gateway 보안 그룹 |
| Route Table | `rt-aks-spoke` | AKS 라우팅 테이블 |
| AKS Cluster | `aks-demo-cluster` | Kubernetes 클러스터 |
| Container Registry | `acraksdemo66749` | 컨테이너 이미지 저장소 |

### 3.2 배포된 애플리케이션

| 항목 | 값 |
|------|-----|
| External IP | `4.230.74.213` |
| Image | `acraksdemo66749.azurecr.io/aks-demo-app:v2` |
| Replicas | 2~10개 (HPA 자동 조정) |
| Namespace | `demo-app` |

### 3.3 API 엔드포인트

| 엔드포인트 | 설명 |
|-----------|------|
| `GET /` | 메인 페이지 |
| `GET /health` | 헬스체크 (Liveness Probe) |
| `GET /ready` | 준비 상태 (Readiness Probe) |
| `GET /info` | Pod 정보 (hostname, IP) |
| `GET /api/items` | 샘플 API - 아이템 목록 |
| `POST /api/items` | 샘플 API - 아이템 생성 |
| `POST /api/echo` | 에코 API |

---

## 4. Quick Start

### 4.1 사전 요구사항

- Azure CLI 설치
- kubectl 설치
- Docker 설치 (로컬 테스트용)
- GitHub 계정

### 4.2 Azure 로그인

```bash
az login --tenant <tenant-id>
az account set --subscription <subscription-id>
```

### 4.3 AKS 연결

```bash
az aks get-credentials --resource-group rg-aks-network-demo --name aks-demo-cluster
kubectl get nodes
```

### 4.4 애플리케이션 배포

```bash
# 전체 매니페스트 배포
kubectl apply -f k8s/

# 배포 상태 확인
kubectl get pods -n demo-app
kubectl get svc -n demo-app
```

---

## 5. 상세 구성 가이드

### 5.1 네트워크 인프라 구성

```bash
# 1. 리소스 그룹 생성
az group create --name rg-aks-network-demo --location koreacentral

# 2. Hub VNet 생성
az network vnet create \
  --resource-group rg-aks-network-demo \
  --name vnet-hub \
  --address-prefix 10.0.0.0/16

# 3. Hub 서브넷 생성
az network vnet subnet create --vnet-name vnet-hub --name AzureFirewallSubnet --address-prefix 10.0.1.0/24
az network vnet subnet create --vnet-name vnet-hub --name GatewaySubnet --address-prefix 10.0.2.0/24
az network vnet subnet create --vnet-name vnet-hub --name AzureBastionSubnet --address-prefix 10.0.3.0/26

# 4. Spoke VNet 생성
az network vnet create \
  --resource-group rg-aks-network-demo \
  --name vnet-spoke-aks \
  --address-prefix 10.1.0.0/16

# 5. AKS 서브넷 생성
az network vnet subnet create --vnet-name vnet-spoke-aks --name snet-aks-system --address-prefix 10.1.1.0/24
az network vnet subnet create --vnet-name vnet-spoke-aks --name snet-aks-user --address-prefix 10.1.2.0/23

# 6. VNet Peering 구성
az network vnet peering create --name peer-hub-to-spoke-aks --vnet-name vnet-hub --remote-vnet vnet-spoke-aks --allow-vnet-access
az network vnet peering create --name peer-spoke-aks-to-hub --vnet-name vnet-spoke-aks --remote-vnet vnet-hub --allow-vnet-access
```

### 5.2 AKS 클러스터 생성

```bash
SUBNET_ID=$(az network vnet subnet show \
  --resource-group rg-aks-network-demo \
  --vnet-name vnet-spoke-aks \
  --name snet-aks-system \
  --query id -o tsv)

az aks create \
  --resource-group rg-aks-network-demo \
  --name aks-demo-cluster \
  --node-count 2 \
  --network-plugin azure \
  --vnet-subnet-id "$SUBNET_ID" \
  --service-cidr 10.2.0.0/16 \
  --dns-service-ip 10.2.0.10 \
  --generate-ssh-keys \
  --enable-managed-identity
```

### 5.3 ACR 생성 및 연결

```bash
# ACR 생성
az acr create --resource-group rg-aks-network-demo --name acraksdemo66749 --sku Basic --admin-enabled true

# AKS-ACR 연결
az aks update --resource-group rg-aks-network-demo --name aks-demo-cluster --attach-acr acraksdemo66749
```

### 5.4 이미지 빌드 및 배포

```bash
# ACR에서 이미지 빌드 (로컬 Docker 불필요)
az acr build --registry acraksdemo66749 --image aks-demo-app:v1 .

# AKS에 배포
kubectl apply -f k8s/
```

---

## 6. CI/CD 파이프라인

### 6.1 파이프라인 흐름

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Git Push   │───▶│   Build &   │───▶│  Push to    │───▶│  Deploy to  │
│  (main)     │    │    Test     │    │    ACR      │    │    AKS      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                                                                ▼
                                                         ┌─────────────┐
                                                         │  Rollback   │
                                                         │ (on fail)   │
                                                         └─────────────┘
```

### 6.2 GitHub Secrets 설정

| Secret Name | 값 |
|-------------|-----|
| `AZURE_CREDENTIALS` | Azure 서비스 주체 JSON |
| `ACR_USERNAME` | `acraksdemo66749` |
| `ACR_PASSWORD` | ACR admin 비밀번호 |

### 6.3 Azure 서비스 주체 생성

```bash
az ad sp create-for-rbac \
  --name "github-actions-aks-deploy" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-aks-network-demo \
  --sdk-auth
```

### 6.4 ACR 비밀번호 확인

```bash
az acr credential show --name acraksdemo66749 --query "passwords[0].value" -o tsv
```

---

## 7. 운영 명령어

### 7.1 배포 관리

```bash
# Pod 상태 확인
kubectl get pods -n demo-app -o wide

# 로그 확인
kubectl logs -n demo-app -l app=aks-demo --tail=50

# 실시간 로그
kubectl logs -n demo-app -l app=aks-demo -f

# 배포 업데이트
kubectl set image deployment/aks-demo-app aks-demo-app=acraksdemo66749.azurecr.io/aks-demo-app:v3 -n demo-app

# 롤백
kubectl rollout undo deployment/aks-demo-app -n demo-app

# 스케일링
kubectl scale deployment/aks-demo-app --replicas=5 -n demo-app
```

### 7.2 모니터링

```bash
# 리소스 사용량
kubectl top pods -n demo-app
kubectl top nodes

# HPA 상태
kubectl get hpa -n demo-app

# 이벤트 확인
kubectl get events -n demo-app --sort-by='.lastTimestamp'
```

### 7.3 디버깅

```bash
# Pod 상세 정보
kubectl describe pod <pod-name> -n demo-app

# Pod 내부 접속
kubectl exec -it <pod-name> -n demo-app -- /bin/sh

# 서비스 엔드포인트 확인
kubectl get endpoints -n demo-app
```

---

## 8. 트러블슈팅

### 8.1 ImagePullBackOff 오류

```bash
# 원인 확인
kubectl describe pod <pod-name> -n demo-app | grep -A5 Events

# ACR 연결 확인
az aks check-acr --resource-group rg-aks-network-demo --name aks-demo-cluster --acr acraksdemo66749.azurecr.io

# ACR 이미지 목록 확인
az acr repository show-tags --name acraksdemo66749 --repository aks-demo-app
```

### 8.2 Pod CrashLoopBackOff

```bash
# 로그 확인
kubectl logs <pod-name> -n demo-app --previous

# 리소스 제한 확인
kubectl describe pod <pod-name> -n demo-app | grep -A10 Limits
```

### 8.3 Service External IP Pending

```bash
# LoadBalancer 상태 확인
kubectl describe svc aks-demo-service -n demo-app

# NSG 규칙 확인
az network nsg rule list --nsg-name nsg-aks-nodes --resource-group rg-aks-network-demo -o table
```

---

## 프로젝트 구조

```
aks-demo-app/
├── .github/
│   └── workflows/
│       └── ci-cd.yaml          # GitHub Actions CI/CD 파이프라인
├── k8s/
│   ├── namespace.yaml          # Kubernetes 네임스페이스
│   ├── configmap.yaml          # 환경설정
│   ├── deployment.yaml         # 애플리케이션 배포
│   ├── service.yaml            # LoadBalancer 서비스
│   └── hpa.yaml                # 자동 스케일링
├── src/
│   ├── app.py                  # Flask 애플리케이션
│   └── requirements.txt        # Python 의존성
├── Dockerfile                  # 컨테이너 이미지 빌드
├── .dockerignore
├── .gitignore
├── README.md                   # 이 문서
├── SETUP-CICD.md              # CI/CD 설정 가이드
└── CLAUDE.md                   # 작업 이력
```

---

## 참고 자료

- [Azure AKS 공식 문서](https://docs.microsoft.com/azure/aks/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [GitHub Actions 문서](https://docs.github.com/actions)
- [Azure CNI 네트워킹](https://docs.microsoft.com/azure/aks/configure-azure-cni)
