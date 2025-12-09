# CI/CD 파이프라인 설정 가이드

이 문서는 GitHub Actions를 사용하여 AKS에 자동 배포하는 CI/CD 파이프라인을 설정하는 방법을 설명합니다.

## 사전 요구사항

- GitHub 저장소
- Azure 구독
- Azure CLI 설치

## 1단계: Azure 서비스 주체 생성

GitHub Actions가 Azure에 인증할 수 있도록 서비스 주체를 생성합니다.

```bash
# 서비스 주체 생성
az ad sp create-for-rbac \
  --name "github-actions-aks-demo" \
  --role contributor \
  --scopes /subscriptions/4c1714bf-8c37-4d10-99a5-5aaf03a4092f/resourceGroups/rg-aks-network-demo \
  --sdk-auth
```

출력 예시:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "4c1714bf-8c37-4d10-99a5-5aaf03a4092f",
  "tenantId": "299692cc-a833-4659-b8d4-3a7cdf6a66c2",
  ...
}
```

## 2단계: GitHub Secrets 설정

GitHub 저장소 > Settings > Secrets and variables > Actions에서 다음 시크릿을 추가합니다:

| Secret Name | 값 | 설명 |
|-------------|-----|------|
| `AZURE_CREDENTIALS` | 위 JSON 전체 | Azure 로그인용 |
| `ACR_USERNAME` | `acraksdemo66749` | ACR 사용자명 |
| `ACR_PASSWORD` | ACR 비밀번호 | ACR admin 비밀번호 |

### ACR 자격증명 가져오기
```bash
# ACR admin 비밀번호 확인
az acr credential show --name acraksdemo66749 --query "passwords[0].value" -o tsv
```

## 3단계: GitHub 저장소에 푸시

```bash
cd ~/aks-demo-app

# Git 초기화
git init
git add .
git commit -m "Initial commit: AKS demo application"

# GitHub 저장소 연결 (저장소 먼저 생성 필요)
git remote add origin https://github.com/YOUR_USERNAME/aks-demo-app.git
git branch -M main
git push -u origin main
```

## 4단계: 파이프라인 동작 확인

main 브랜치에 푸시하면 자동으로:
1. 코드 테스트
2. Docker 이미지 빌드
3. ACR에 이미지 Push
4. AKS에 배포
5. 배포 상태 확인

## 파이프라인 흐름

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Git Push   │ ──▶ │    Build     │ ──▶ │   Deploy     │
│   (main)     │     │   & Test     │     │   to AKS     │
└──────────────┘     └──────────────┘     └──────────────┘
                            │                    │
                            ▼                    ▼
                     ┌──────────────┐     ┌──────────────┐
                     │  Push Image  │     │  Rollback    │
                     │   to ACR     │     │  (on fail)   │
                     └──────────────┘     └──────────────┘
```

## 수동 배포 명령어

CI/CD 없이 수동으로 배포하려면:

```bash
# 1. ACR에서 이미지 빌드
az acr build --registry acraksdemo66749 --image aks-demo-app:v3 .

# 2. AKS 연결
az aks get-credentials --resource-group rg-aks-network-demo --name aks-demo-cluster

# 3. 배포
kubectl set image deployment/aks-demo-app aks-demo-app=acraksdemo66749.azurecr.io/aks-demo-app:v3 -n demo-app

# 4. 상태 확인
kubectl rollout status deployment/aks-demo-app -n demo-app
```

## 트러블슈팅

### 이미지 Pull 오류
```bash
# ACR-AKS 연결 확인
az aks check-acr --resource-group rg-aks-network-demo --name aks-demo-cluster --acr acraksdemo66749.azurecr.io
```

### Pod 상태 확인
```bash
kubectl describe pod -n demo-app -l app=aks-demo
kubectl logs -n demo-app -l app=aks-demo --tail=50
```

### 롤백
```bash
kubectl rollout undo deployment/aks-demo-app -n demo-app
```
