# CI/CD Setup for Bicep Infrastructure Deployment

GitHub Actions를 사용한 Bicep 인프라 자동 배포 설정 가이드입니다.

## Prerequisites

1. Azure Subscription
2. GitHub Repository
3. Azure AD App Registration (Federated Credentials)

## Step 1: Azure AD App Registration 생성

### 1.1 App Registration 생성

```bash
# Azure CLI 로그인
az login

# App Registration 생성
az ad app create --display-name "github-aks-deploy"

# Service Principal 생성
az ad sp create --id <app-id>

# Subscription에 Contributor 권한 부여
az role assignment create \
  --assignee <app-id> \
  --role "Contributor" \
  --scope "/subscriptions/4c1714bf-8c37-4d10-99a5-5aaf03a4092f"
```

### 1.2 Federated Credentials 설정 (OIDC)

Azure Portal에서:
1. **Azure Active Directory** → **App registrations** → 생성한 앱 선택
2. **Certificates & secrets** → **Federated credentials** → **Add credential**
3. 설정:
   - **Federated credential scenario**: GitHub Actions deploying Azure resources
   - **Organization**: `ddunjae`
   - **Repository**: `aks-deploy`
   - **Entity type**: Branch
   - **GitHub branch name**: `main`
   - **Name**: `github-main-branch`

또는 CLI로:

```bash
# Federated Credential JSON 파일 생성
cat > federated-credential.json << EOF
{
  "name": "github-main-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ddunjae/aks-deploy:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

# Federated Credential 추가
az ad app federated-credential create \
  --id <app-id> \
  --parameters federated-credential.json
```

## Step 2: GitHub Secrets 설정

GitHub Repository → Settings → Secrets and variables → Actions에서 다음 secrets를 추가:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AZURE_CLIENT_ID` | App Registration Client ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `JUMPBOX_PASSWORD` | Jumpbox VM 관리자 비밀번호 | `SecureP@ssw0rd!` |
| `SSH_PUBLIC_KEY` | AKS 노드용 SSH 공개키 | `ssh-rsa AAAA...` |
| `ACR_NAME` | (Optional) ACR 이름 | `acraksdemo66749` |

### SSH 키 생성

```bash
# SSH 키 생성
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aks-demo-key -N ""

# 공개키 확인
cat ~/.ssh/aks-demo-key.pub
```

## Step 3: Workflow 설정

### 자동 트리거

다음 경우에 워크플로우가 자동으로 실행됩니다:

1. **Push to main**: `infra/` 폴더 내 파일 변경 시
2. **Pull Request**: `infra/` 폴더 변경이 포함된 PR 생성 시

### 수동 실행

GitHub Repository → Actions → Deploy Infrastructure (Bicep) → Run workflow

옵션:
- **environment**: `demo`, `dev`, `prod`
- **action**:
  - `validate` - 템플릿 유효성 검사만
  - `what-if` - 변경사항 미리보기
  - `deploy` - 실제 배포
- **location**: Azure 리전 (기본: `koreacentral`)

## Workflow 구조

```
deploy-infra.yaml
│
├── validate          # Bicep 린트, 빌드, 유효성 검사
│
├── what-if          # 변경사항 분석 (PR 또는 수동 실행)
│   └── PR 코멘트 작성
│
├── deploy           # 실제 인프라 배포
│   └── 배포 결과 출력
│
├── verify           # 배포 검증
│   ├── AKS 상태 확인
│   └── 네트워크 구성 확인
│
└── cleanup-on-failure  # 실패 시 알림
```

## 배포 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                    Pull Request 생성                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Validate (Lint, Build, Validate)               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                What-If Analysis                              │
│            (PR에 변경사항 코멘트 작성)                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │  PR Merge
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Deploy                                    │
│            (실제 인프라 배포)                                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Verify                                    │
│            (AKS, 네트워크 상태 검증)                          │
└─────────────────────────────────────────────────────────────┘
```

## Environment Protection Rules (선택사항)

Production 환경에 추가 보호를 위해:

1. GitHub Repository → Settings → Environments
2. `prod` 환경 생성
3. Protection rules 설정:
   - Required reviewers 추가
   - Wait timer 설정 (예: 5분)
   - Deployment branches: `main`만 허용

## Troubleshooting

### 인증 오류

```
Error: AADSTS700024: Client assertion is not within its valid time range
```

**해결**: Federated Credential 설정 확인, subject가 정확한지 확인

### 권한 오류

```
Error: The client does not have authorization to perform action
```

**해결**: Service Principal에 Contributor 권한이 있는지 확인

```bash
az role assignment list --assignee <app-id> --output table
```

### Bicep 빌드 오류

```
Error: Unable to find module 'xxx'
```

**해결**: 모듈 경로가 상대 경로로 올바르게 설정되었는지 확인

## 관련 링크

- [Azure OIDC Authentication](https://docs.microsoft.com/azure/developer/github/connect-from-azure)
- [Bicep GitHub Actions](https://docs.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions)
- [GitHub Environments](https://docs.github.com/actions/deployment/targeting-different-environments)
