# Claude Code 작업 이력

이 문서는 Claude Code를 사용하여 수행한 AKS 네트워크 아키텍처 및 CI/CD 파이프라인 구성 작업의 상세 이력을 기록합니다.

---

## 작업 개요

| 항목 | 내용 |
|------|------|
| **작업일** | 2025-12-09 ~ 2025-12-10 |
| **목적** | Azure AKS 환경에서 Hub-Spoke 네트워크 아키텍처 구성 및 CI/CD 파이프라인 구현 |
| **Azure 구독** | Visual Studio Enterprise 구독 - MPN (4c1714bf-8c37-4d10-99a5-5aaf03a4092f) |
| **테넌트** | 299692cc-a833-4659-b8d4-3a7cdf6a66c2 |
| **리전** | Korea Central |

---

## 작업 단계별 이력

### Phase 1: 개념 설명 및 아키텍처 설계

**요청:** AKS 네트워크 토폴로지와 핵심 인프라 설계 업무에 대한 개념 설명

**수행 내용:**
1. AKS를 사용하는 이유 설명 (VM 방식 vs Container 방식)
2. Hub-Spoke 네트워크 아키텍처 개념 설명
3. 네트워크 구성도 ASCII art로 시각화
4. IP 주소 계획표 작성
5. CNI 선택 가이드 (Azure CNI vs Kubenet)

**산출물:**
- Hub-Spoke 아키텍처 다이어그램
- IP 주소 계획표
- 네트워크 플로우 다이어그램

---

### Phase 2: Azure 인프라 구성

**요청:** 실제 Azure 환경에 네트워크 아키텍처 구성

**수행 명령어:**

```bash
# 1. Azure 로그인
az login --tenant 299692cc-a833-4659-b8d4-3a7cdf6a66c2

# 2. 구독 설정
az account set --subscription 4c1714bf-8c37-4d10-99a5-5aaf03a4092f

# 3. 리소스 그룹 생성
az group create --name rg-aks-network-demo --location koreacentral

# 4. Hub VNet 생성
az network vnet create --name vnet-hub --address-prefix 10.0.0.0/16

# 5. Hub 서브넷 생성
az network vnet subnet create --name AzureFirewallSubnet --address-prefix 10.0.1.0/24
az network vnet subnet create --name GatewaySubnet --address-prefix 10.0.2.0/24
az network vnet subnet create --name AzureBastionSubnet --address-prefix 10.0.3.0/26
az network vnet subnet create --name snet-management --address-prefix 10.0.4.0/24

# 6. Spoke VNet 생성
az network vnet create --name vnet-spoke-aks --address-prefix 10.1.0.0/16

# 7. AKS 서브넷 생성
az network vnet subnet create --name snet-aks-system --address-prefix 10.1.1.0/24
az network vnet subnet create --name snet-aks-user --address-prefix 10.1.2.0/23
az network vnet subnet create --name snet-aks-ilb --address-prefix 10.1.4.0/24
az network vnet subnet create --name snet-appgw --address-prefix 10.1.5.0/24
az network vnet subnet create --name snet-privateendpoint --address-prefix 10.1.10.0/24

# 8. VNet Peering 구성
az network vnet peering create --name peer-hub-to-spoke-aks --vnet-name vnet-hub --remote-vnet vnet-spoke-aks
az network vnet peering create --name peer-spoke-aks-to-hub --vnet-name vnet-spoke-aks --remote-vnet vnet-hub

# 9. NSG 생성 및 연결
az network nsg create --name nsg-aks-nodes
az network nsg create --name nsg-appgw
az network nsg rule create --name Allow-GatewayManager --priority 100 --nsg-name nsg-appgw

# 10. Route Table 생성 및 연결
az network route-table create --name rt-aks-spoke
```

**생성된 리소스:**
- Resource Group: `rg-aks-network-demo`
- VNets: `vnet-hub`, `vnet-spoke-aks`
- Subnets: 9개
- NSGs: `nsg-aks-nodes`, `nsg-appgw`
- Route Table: `rt-aks-spoke`
- VNet Peerings: 2개

---

### Phase 3: AKS 클러스터 생성

**수행 명령어:**

```bash
# AKS 클러스터 생성 (Azure CNI 사용)
az aks create \
  --resource-group rg-aks-network-demo \
  --name aks-demo-cluster \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --network-plugin azure \
  --vnet-subnet-id "/subscriptions/.../subnets/snet-aks-system" \
  --service-cidr 10.2.0.0/16 \
  --dns-service-ip 10.2.0.10 \
  --generate-ssh-keys \
  --enable-managed-identity
```

**생성된 리소스:**
- AKS Cluster: `aks-demo-cluster`
- Node Pool: 2개 노드 (Standard_DS2_v2)
- Managed Identity: 자동 생성

---

### Phase 4: 샘플 애플리케이션 개발

**생성한 파일:**

1. **src/app.py** - Flask API 애플리케이션
   - 헬스체크 엔드포인트 (`/health`, `/ready`)
   - Pod 정보 엔드포인트 (`/info`)
   - 샘플 CRUD API (`/api/items`)

2. **src/requirements.txt** - Python 의존성
   ```
   Flask==3.0.0
   gunicorn==21.2.0
   Werkzeug==3.0.1
   ```

3. **Dockerfile** - Multi-stage 빌드
   - Stage 1: 의존성 설치
   - Stage 2: 프로덕션 이미지 (non-root user)
   - Healthcheck 포함

---

### Phase 5: ACR 구성 및 이미지 빌드

**수행 명령어:**

```bash
# ACR 생성
az acr create --name acraksdemo66749 --sku Basic --admin-enabled true

# ACR-AKS 연결
az aks update --name aks-demo-cluster --attach-acr acraksdemo66749

# 이미지 빌드 (ACR Tasks 사용 - 로컬 Docker 불필요)
az acr build --registry acraksdemo66749 --image aks-demo-app:v1 .
az acr build --registry acraksdemo66749 --image aks-demo-app:v2 .  # 권한 문제 수정 후
```

**트러블슈팅:**
- 초기 v1 이미지에서 `PermissionError: [Errno 13] Permission denied: '/app/app.py'` 발생
- 원인: Dockerfile에서 `COPY` 후 파일 소유권이 root로 설정됨
- 해결: `COPY --chown=appuser:appuser src/app.py .` 로 수정

---

### Phase 6: Kubernetes 매니페스트 작성

**생성한 파일:**

1. **k8s/namespace.yaml**
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: demo-app
   ```

2. **k8s/configmap.yaml**
   - 환경변수 설정 (APP_VERSION, ENVIRONMENT)

3. **k8s/deployment.yaml**
   - Replicas: 3
   - Liveness/Readiness/Startup Probes
   - Resource limits/requests
   - Rolling update strategy

4. **k8s/service.yaml**
   - Type: LoadBalancer
   - Port: 80 → 8080

5. **k8s/hpa.yaml**
   - Min: 2, Max: 10
   - CPU/Memory 기반 스케일링

---

### Phase 7: AKS 배포

**수행 명령어:**

```bash
# AKS 자격증명 가져오기
az aks get-credentials --resource-group rg-aks-network-demo --name aks-demo-cluster

# 매니페스트 배포
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# 배포 상태 확인
kubectl get pods -n demo-app
kubectl get svc -n demo-app
```

**배포 결과:**
- External IP: `4.230.74.213`
- 3개 Pod 정상 Running
- LoadBalancer 서비스 생성됨

---

### Phase 8: CI/CD 파이프라인 구성

**생성한 파일:** `.github/workflows/ci-cd.yaml`

**파이프라인 구조:**
1. **Build Job**
   - 코드 체크아웃
   - Python 테스트
   - Docker 이미지 빌드
   - ACR Push

2. **Deploy Job**
   - AKS 자격증명 설정
   - kubectl apply
   - Rollout status 확인
   - External IP 가져오기

3. **Rollback Job** (실패 시)
   - 자동 롤백 수행

**트러블슈팅:**
- 초기 파이프라인에서 이미지 태그 불일치 발생
- 원인: `github.sha` (40자) vs `docker/metadata-action` 짧은 SHA (7자)
- 해결: 짧은 SHA를 명시적으로 생성하여 build→deploy 간 전달

---

### Phase 9: GitHub 연동

**수행 명령어:**

```bash
# Git 초기화
git init
git branch -m main

# 커밋
git add .
git commit -m "Initial commit: AKS demo application with CI/CD pipeline"

# GitHub 원격 저장소 연결
git remote add origin https://github.com/ddunjae/aks-deploy.git

# 푸시
git push -u origin main --force
```

**GitHub Secrets 설정 필요:**
- `AZURE_CREDENTIALS`: Azure 서비스 주체 JSON
- `ACR_USERNAME`: acraksdemo66749
- `ACR_PASSWORD`: ACR admin 비밀번호

---

## 생성된 Azure 서비스 주체

```json
{
  "clientId": "<CLIENT_ID>",
  "clientSecret": "<CLIENT_SECRET>",
  "subscriptionId": "<SUBSCRIPTION_ID>",
  "tenantId": "<TENANT_ID>"
}
```

> **Note:** 실제 값은 GitHub Secrets에 `AZURE_CREDENTIALS`로 저장되어 있습니다.
> 서비스 주체 재생성이 필요한 경우 아래 명령어를 사용하세요:
> ```bash
> az ad sp create-for-rbac --name "github-actions-aks-deploy" --role contributor --scopes /subscriptions/<sub-id>/resourceGroups/rg-aks-network-demo --sdk-auth
> ```

---

## 발생한 이슈 및 해결

### Issue 1: Docker 이미지 권한 문제
- **증상:** Pod CrashLoopBackOff, `PermissionError`
- **원인:** Dockerfile에서 non-root user 사용 시 파일 소유권 문제
- **해결:** `COPY --chown=appuser:appuser` 사용

### Issue 2: CI/CD 이미지 태그 불일치
- **증상:** ImagePullBackOff, 이미지를 찾을 수 없음
- **원인:** build job에서 짧은 SHA, deploy job에서 긴 SHA 사용
- **해결:** 짧은 SHA를 output으로 전달하여 일관성 유지

### Issue 3: 로컬에서 External IP 접근 불가
- **증상:** curl 타임아웃
- **원인:** 로컬 네트워크에서 Azure Public IP 접근 제한 (WSL 환경)
- **해결:** kubectl exec로 Pod 내부에서 테스트

---

## 정리 명령어 (리소스 삭제 시)

```bash
# 리소스 그룹 전체 삭제 (모든 리소스 포함)
az group delete --name rg-aks-network-demo --yes --no-wait

# 서비스 주체 삭제
az ad sp delete --id e03db869-fe43-4a23-8b3c-3edf9fc336ee
```

---

## 다음 단계 (권장)

1. **Azure Firewall 추가** - Egress 트래픽 제어
2. **Azure Bastion 추가** - 보안 접속
3. **Application Gateway + AGIC** - L7 로드밸런싱
4. **Private Endpoint** - PaaS 서비스 연결 (SQL, Storage 등)
5. **Azure Monitor** - 모니터링 및 알림 설정
6. **Azure Key Vault** - 시크릿 관리

---

## Phase 10: Jump Box VM 구성 및 AKS 노드 접속 (2025-12-10)

### 10.1 Azure 구성도 생성

**요청:** 두 리소스 그룹(`rg-aks-network-demo`, `MC_rg-aks-network-demo_aks-demo-cluster_koreacentral`) 기준 Azure 구성도 생성

**수행 내용:**
- 리소스 그룹의 모든 리소스 조회
- VNet, 서브넷, 피어링 정보 수집
- AKS 클러스터 네트워크 구성 확인
- ASCII art 기반 아키텍처 구성도 작성

### 10.2 Jump Box VM 생성

**요청:** AKS 노드 접속을 위한 Jump Box VM 생성

**수행 명령어:**
```bash
az vm create \
  --resource-group rg-aks-network-demo \
  --name vm-jumpbox \
  --image Ubuntu2204 \
  --vnet-name vnet-hub \
  --subnet snet-management \
  --size Standard_B2s \
  --admin-username conortest \
  --admin-password 'qwert12345!!' \
  --authentication-type password \
  --public-ip-address pip-jumpbox \
  --nsg nsg-jumpbox \
  --location koreacentral
```

**생성된 리소스:**
| 항목 | 값 |
|------|-----|
| VM 이름 | `vm-jumpbox` |
| Public IP | `4.217.191.222` |
| Private IP | `10.0.4.4` |
| 서브넷 | `snet-management (10.0.4.0/24)` |
| OS | Ubuntu 22.04.5 LTS |
| Size | Standard_B2s |

### 10.3 VM에 Azure CLI 및 kubectl 설치

**수행 명령어 (VM 내부에서):**
```bash
# Azure CLI 설치
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# kubectl 및 kubelogin 설치
az aks install-cli
```

### 10.4 VM Managed Identity에 AKS 역할 할당

```bash
# AKS Cluster User Role 할당
az role assignment create \
  --assignee <VM_PRINCIPAL_ID> \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope <AKS_ID>

# AKS Cluster Admin Role 할당
az role assignment create \
  --assignee <VM_PRINCIPAL_ID> \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope <AKS_ID>
```

### 10.5 NSG 규칙 추가 (HTTP 허용)

**문제 발견:** LoadBalancer External IP로 접속 시 Connection Timeout 발생

**원인 분석:**
- `nsg-aks-nodes` NSG에 HTTP(80) 인바운드 허용 규칙이 없음
- 기본 규칙 `DenyAllInBound`가 인터넷 트래픽 차단

**해결:**
```bash
az network nsg rule create \
  --resource-group rg-aks-network-demo \
  --nsg-name nsg-aks-nodes \
  --name Allow-HTTP-Inbound \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80
```

**결과:**
```bash
curl http://4.230.74.213
# {"environment":"production","message":"Welcome to AKS Demo Application!","version":"1.0.0"}
```

### 10.6 AKS 노드 접속 테스트

**kubectl debug를 통한 노드 접속:**
```bash
kubectl debug node/aks-systempool-64021530-vmss000001 -it --image=mcr.microsoft.com/cbl-mariner/busybox:2.0
```

**노드 정보:**
| 항목 | 값 |
|------|-----|
| 노드 이름 | `aks-systempool-64021530-vmss000001` |
| Internal IP | `10.1.1.4` |
| OS | Ubuntu 22.04.5 LTS |
| Kubernetes | v1.32.9 |
| Container Runtime | containerd://1.7.29-1 |

---

## 발생한 이슈 및 해결 (추가)

### Issue 4: LoadBalancer IP 접속 불가
- **증상:** External IP `4.230.74.213`로 curl 시 Connection Timeout
- **원인:** `nsg-aks-nodes` NSG에 HTTP(80) 인바운드 규칙 없음
- **해결:** `Allow-HTTP-Inbound` 규칙 추가 (Priority 100)

### Issue 5: VM에서 kubectl 인증 실패
- **증상:** `localhost:8080 connection refused` 오류
- **원인:** kubelogin으로 kubeconfig 변환 필요
- **해결:** `kubelogin convert-kubeconfig -l msi` 실행

---

## 현재 인프라 상태 요약

### 네트워크 구성
```
Hub VNet (10.0.0.0/16)
├── AzureFirewallSubnet (10.0.1.0/24) - 예약됨
├── GatewaySubnet (10.0.2.0/24) - 예약됨
├── AzureBastionSubnet (10.0.3.0/26) - 예약됨
└── snet-management (10.0.4.0/24) - vm-jumpbox 배포됨
         │
         │ VNet Peering (Connected)
         ▼
Spoke VNet (10.1.0.0/16)
├── snet-aks-system (10.1.1.0/24) - AKS 시스템 노드
├── snet-aks-user (10.1.2.0/23) - AKS 사용자 노드
├── snet-aks-ilb (10.1.4.0/24) - Internal LB
├── snet-appgw (10.1.5.0/24) - App Gateway
└── snet-privateendpoint (10.1.10.0/24) - Private Endpoint
```

### 주요 접속 정보
| 서비스 | 접속 주소 |
|--------|----------|
| 데모 앱 | http://4.230.74.213 |
| Jump Box SSH | ssh conortest@4.217.191.222 |
| AKS API | aks-demo-c-rg-aks-network-d-4c1714-wcmvde2f.hcp.koreacentral.azmk8s.io |

---

## 참고 문서

- [Azure AKS 네트워킹 개념](https://docs.microsoft.com/azure/aks/concepts-network)
- [Hub-Spoke 토폴로지](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [GitHub Actions for Azure](https://docs.microsoft.com/azure/developer/github/github-actions)
- [AKS 노드 접속 방법](https://docs.microsoft.com/azure/aks/node-access)
