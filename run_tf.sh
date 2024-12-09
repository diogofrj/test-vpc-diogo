#!/usr/bin/env bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'

NC='\033[0m'

# Verificação de dependências
#command -v jq >/dev/null 2>&1 || { echo -e "${RED}Erro: jq não está instalado${NC}"; exit 1; }

# Diretório do Terraform
TERRAFORM_DIR="."


# Função para configurar backend remoto
configure_backend() {
    echo -e "${YELLOW}Configurando Backend Remoto${NC}"
    echo -e "${ORANGE}Selecione o provedor do backend:${NC}"
    echo "1) AWS S3"
    echo "2) Azure Storage"
    read -p "Escolha (1-2): " backend_choice

    case $backend_choice in
        1)
            echo -e "${YELLOW}Configurando Backend AWS S3${NC}"
            read -p "Nome do bucket S3: " bucket_name
            read -p "Nome da chave do estado (ex: terraform.tfstate): " key_name
            read -p "Região AWS: " aws_region
            
            # Gerando nome único do bucket
            full_bucket_name="${bucket_name}$(uuidgen | tr -d - | tr '[:upper:]' '[:lower:]')"
            
            # Criando bucket S3 via AWS CLI
            echo -e "${YELLOW}Criando bucket S3...${NC}"
            if [ "${aws_region}" = "us-east-1" ]; then
                aws s3api create-bucket \
                    --bucket "${full_bucket_name}" \
                    --region "${aws_region}"
            else
                aws s3api create-bucket \
                    --bucket "${full_bucket_name}" \
                    --region "${aws_region}" \
                    --create-bucket-configuration LocationConstraint="${aws_region}"
            fi

            # Habilitando versionamento do bucket
            aws s3api put-bucket-versioning \
                --bucket "${full_bucket_name}" \
                --versioning-configuration Status=Enabled

            # Criando arquivo de configuração do backend
            cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "${full_bucket_name}"
    key    = "${key_name}"
    region = "${aws_region}"
  }
}
EOF
            echo -e "${GREEN}Arquivo backend.tf criado com sucesso!${NC}"
            echo -e "${YELLOW}Deseja migrar o estado agora? (s/n)${NC}"
            read -p "Resposta: " migrate_now
            
            if [ "$migrate_now" = "s" ] || [ "$migrate_now" = "S" ]; then
                echo -e "${YELLOW}Executando terraform init -migrate-state -var-file=backend.tf${NC}"
                terraform init -migrate-state -var-file=backend.tf
            else
                echo -e "${YELLOW}Você pode migrar o estado posteriormente executando: terraform init -migrate-state -var-file=backend.tf${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}Configurando Backend Azure Storage${NC}"
            read -p "Nome da conta de armazenamento: " storage_account
            read -p "Nome do container: " container_name
            read -p "Nome da chave do estado: " key_name
            read -p "Grupo de recursos: " resource_group
            read -p "Localização: " location
            
            # Gerando nome único para a conta de armazenamento
            full_storage_name="${storage_account}$(uuidgen | tr -d - | tr '[:upper:]' '[:lower:]' | cut -c1-24)"
            
            # Criando conta de armazenamento via Azure CLI
            echo -e "${YELLOW}Criando conta de armazenamento...${NC}"
            az storage account create \
                --name "${full_storage_name}" \
                --resource-group "${resource_group}" \
                --location "${location}" \
                --sku Standard_LRS

            # Criando container
            echo -e "${YELLOW}Criando container...${NC}"
            az storage container create \
                --name "${container_name}" \
                --account-name "${full_storage_name}"
            
            # Criando arquivo de configuração do backend
            cat > backend.tf << EOF
terraform {
  backend "azurerm" {
    storage_account_name = "${full_storage_name}"
    container_name       = "${container_name}"
    key                 = "${key_name}"
  }
}
EOF
            echo -e "${GREEN}Arquivo backend.tf criado com sucesso!${NC}"
            echo -e "${YELLOW}Deseja migrar o estado agora? (s/n)${NC}"
            read -p "Resposta: " migrate_now
            
            if [ "$migrate_now" = "s" ] || [ "$migrate_now" = "S" ]; then
                echo -e "${YELLOW}Executando terraform init -migrate-state -var-file=backend.tf${NC}"
                terraform init -migrate-state -var-file=backend.tf
            else
                echo -e "${YELLOW}Você pode migrar o estado posteriormente executando: terraform init -migrate-state -var-file=backend.tf${NC}"
            fi
EOF
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}Recursos criados e arquivo backend.tf gerado com sucesso!${NC}"
}


###### Funções de validação
validate_terraform_dir() {
    if [ ! -d "$TERRAFORM_DIR" ]; then
        echo -e "${RED}Erro: Diretório Terraform não encontrado${NC}"
        exit 1
    else
        echo -e "${GREEN}Diretório Terraform encontrado: $TERRAFORM_DIR${NC}"
    fi
}
validate_tfvars() {
    if [ ! -f "$TERRAFORM_DIR/common.tfvars" ]; then
        echo -e "${RED}Erro: Arquivo common.tfvars não encontrado${NC}"
        exit 1
    else
        echo -e "${GREEN}Arquivo common.tfvars encontrado: $TERRAFORM_DIR/common.tfvars${NC}"
    fi
}
###### Funções principais
init() {
    echo -e "${YELLOW}Inicializando Terraform...${NC}"
    terraform -chdir="$TERRAFORM_DIR" init -upgrade
    # terraform -chdir="$TERRAFORM_DIR" init -backend-config=backend.hcl
}
fmt() {
    echo -e "${YELLOW}Formatando arquivos Terraform...${NC}"
    terraform -chdir="$TERRAFORM_DIR" fmt -recursive
}
validate() {
    echo -e "${YELLOW}Validando arquivos Terraform...${NC}"
    terraform -chdir="$TERRAFORM_DIR" validate
}
plan() {
    echo -e "${YELLOW}Executando Terraform Plan...${NC}"
    terraform -chdir="$TERRAFORM_DIR" plan -no-color -out=tf.plan #-var-file=common.tfvars 
    terraform -chdir="$TERRAFORM_DIR" show -json tf.plan > tf_plan.json
    terraform -chdir="$TERRAFORM_DIR" show -no-color tf.plan > tf_plan.hcl
}
show() {
    echo -e "${YELLOW}Executando Terraform Show...${NC}"
    terraform -chdir="$TERRAFORM_DIR" show -no-color -json tf.plan | jq
}

apply() {
    echo -e "${YELLOW}Executando Terraform Apply...${NC}"
    terraform -chdir="$TERRAFORM_DIR" apply -auto-approve tf.plan #-var-file=common.tfvars 
}
outputs() {
    echo -e "${YELLOW}Executando Terraform Outputs...${NC}"
    terraform -chdir="$TERRAFORM_DIR" output -json
}
destroy() {
    echo -e "${RED}Atenção: Isso irá destruir toda a infraestrutura!${NC}"
    read -p "Você tem certeza? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform -chdir="$TERRAFORM_DIR" destroy -auto-approve # -var-file=common.tfvars 
    fi
}
workspace() {
    case "$2" in
        list)
            terraform -chdir="$TERRAFORM_DIR" workspace list
            ;;
        new)
            terraform -chdir="$TERRAFORM_DIR" workspace new "$3"
            ;;
        select)
            terraform -chdir="$TERRAFORM_DIR" workspace select "$3"
            ;;
        *)
            echo -e "${RED}Comando workspace inválido. Use: workspace [list|new|select] [nome]${NC}"
            exit 1
            ;;
    esac
}
console() {
    echo -e "${YELLOW}Abrindo console do Terraform...${NC}"
    terraform -chdir="$TERRAFORM_DIR" console
}
infracost() {
    #INFRACOST_API_KEY=ico-MMklJXBnHBncpnaQ7AAmLjoPt2Ni8BIX
    echo -e "${YELLOW}Executando Infracost...${NC}"
    if [ -z "$INFRACOST_API_KEY" ]; then
        echo -e "${RED}Erro: Variável INFRACOST_API_KEY não está definida: Acesse https://www.infracost.io/docs/#2-get-api-key para obter a chave${NC}"
        exit 1
    else
        docker run --rm -e INFRACOST_API_KEY=${INFRACOST_API_KEY} -v $(pwd)/$TERRAFORM_DIR:/code/ infracost/infracost:ci-latest breakdown --path /code/
    fi
}

###### Funções de segurança
checkov() {
    echo -e "${YELLOW}Executando Checkov...${NC}"
    docker run --tty --volume $(pwd)/$TERRAFORM_DIR:/tf --workdir /tf bridgecrew/checkov --directory /tf --quiet --compact
}
tfsec() {
    echo -e "${YELLOW}Executando análise de segurança...${NC}"
    docker run --rm -it -v "$(pwd)/$TERRAFORM_DIR:/src" aquasec/tfsec --tfvars-file /src/common.tfvars --force-all-dirs --soft-fail --concise-output /src 
}
tflint() {
    echo -e "${YELLOW}Executando análise de lint...${NC}"
    # docker run --rm -it -v "$(pwd)/$TERRAFORM_DIR:/src" wata727/tflint --recursive --config=/src/.tflint.hcl /src
    docker run --rm -v $(pwd)/$TERRAFORM_DIR:/data -t ghcr.io/terraform-linters/tflint --recursive
}
terrascan() {
    echo -e "${YELLOW}Executando análise de segurança...${NC}"
    
    # Procura por providers em todos os arquivos .tf
    if grep -r 'provider "aws"' "$TERRAFORM_DIR"/*.tf >/dev/null 2>&1; then
        echo -e "${YELLOW}Analisando provider AWS...${NC}"
        docker run --rm -it -v "$(pwd)/$TERRAFORM_DIR:/iac" -w /iac tenable/terrascan scan -t aws -o human
    fi

    if grep -r 'provider "azurerm"' "$TERRAFORM_DIR"/*.tf >/dev/null 2>&1; then
        echo -e "${YELLOW}Analisando provider Azure...${NC}"
        docker run --rm -it -v "$(pwd)/$TERRAFORM_DIR:/iac" -w /iac tenable/terrascan scan -t azure -o human
    fi

    if grep -r 'provider "google"' "$TERRAFORM_DIR"/*.tf >/dev/null 2>&1; then
        echo -e "${YELLOW}Analisando provider GCP...${NC}"
        docker run --rm -it -v "$(pwd)/$TERRAFORM_DIR:/iac" -w /iac tenable/terrascan scan -t gcp -o human
    fi

    # Se nenhum provider for encontrado
    if ! grep -r 'provider "\(aws\|azurerm\|google\)"' "$TERRAFORM_DIR"/*.tf >/dev/null 2>&1; then
        echo -e "${RED}Erro: Nenhum provider AWS, Azure ou GCP encontrado!${NC}"
        exit 1
    fi
}
kics() {
    echo -e "${YELLOW}Executando análise de segurança...${NC}"
    docker run -t -v $(pwd)/$TERRAFORM_DIR:/path checkmarx/kics:latest scan -p /path -o terraform  --exclude-severities 'info,low' --minimal-ui
}




###### Funções de documentação
setup_docs_structure() {
    echo -e "${YELLOW}Configurando estrutura de documentação...${NC}"
    
    # Array com diretórios necessários
    directories=(
        "docs"
        "docs/architecture"
        "docs/architecture/diagrams"
        "docs/guides"
        "docs/operations"
        "docs/security"
        "docs/images"
    )

    # Criando diretórios
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${YELLOW}Criando diretório $dir${NC}"
            mkdir -p "$dir"
        else
            echo -e "${GREEN}Diretório $dir já existe${NC}"
        fi
    done

    # Array com arquivos necessários
    declare -A files=(
        ["docs/.header.md"]="# Módulo Terraform: Nome do Projeto

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)

Este módulo é responsável por criar recursos na AWS para [descrição do propósito].

## Arquitetura

![Arquitetura](./docs/images/architecture.png)

## Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- Permissões necessárias:
  - ec2:*
  - vpc:*"

        ["docs/.footer.md"]="## Contribuição

1. Faça um fork do projeto
2. Crie sua branch de feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## Licença

Copyright © 2024 [Nome da Empresa]

## Contato

- Time DevOps - devops@empresa.com
- Time SRE - sre@empresa.com"

        [".terraform-docs.yml"]="formatter: \"markdown table\"

version: \"\"

header-from: \"docs/.header.md\"
footer-from: \"docs/.footer.md\"

recursive:
  enabled: true
  path: modules

sections:
  show-all: true

content: |-
  {{ .Header }}

  ## Índice

  - [Requisitos](#requisitos)
  - [Providers](#providers)
  - [Recursos](#recursos)
  - [Inputs](#inputs)
  - [Outputs](#outputs)
  
  {{ .Requirements }}
  
  {{ .Providers }}
  
  {{ .Resources }}
  
  {{ .Inputs }}
  
  {{ .Outputs }}
  
  {{ .Footer }}

output:
  file: \"README.md\"
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->

settings:
  anchor: true
  color: true
  default: true
  description: true
  escape: true
  hide-empty: false
  html: true
  indent: 2
  lockfile: true
  read-comments: true
  required: true
  sensitive: true
  type: true"
    )

    # Criando arquivos se não existirem
    for file in "${!files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${YELLOW}Criando arquivo $file${NC}"
            echo -e "${files[$file]}" > "$file"
        else
            echo -e "${GREEN}Arquivo $file já existe${NC}"
        fi
    done
}

gera_docs() {
    echo -e "${YELLOW}Verificando estrutura de documentação...${NC}"
    
    # Verifica se a estrutura de documentação existe
    if [ ! -d "docs" ] || [ ! -f ".terraform-docs.yml" ]; then
        echo -e "${YELLOW}Estrutura de documentação não encontrada. Criando...${NC}"
        setup_docs_structure
    fi

    echo -e "${YELLOW}Gerando documentação...${NC}"
    
    # Verifica se terraform-docs está instalado
    if ! command -v terraform-docs &> /dev/null; then
        echo -e "${RED}terraform-docs não está instalado. Por favor, instale primeiro.${NC}"
        echo -e "${YELLOW}Visite: https://terraform-docs.io/user-guide/installation/${NC}"
        return 1
    fi
    
    # Gera documentação
    terraform-docs -c .terraform-docs.yml .
    
    echo -e "${GREEN}Documentação gerada com sucesso!${NC}"
}


# Processamento dos argumentos da linha de comando
main() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Erro: Nenhum comando especificado${NC}"
        echo -e "${YELLOW}Comandos disponíveis:${NC}"
        echo -e "${ORANGE}  Funções de configuração do Backend: (RUN IT ONCE)${NC}"
        echo -e "    configure_backend        - Configura o backend remoto"
        echo -e "${GREEN}  Funções de validação:${NC}"
        echo -e "    validate_terraform_dir   - Valida se o diretório Terraform existe"
        echo -e "    validate_tfvars          - Valida se o arquivo common.tfvars existe"
        echo -e "${GREEN}  Funções principais:${NC}"
        echo -e "    init                     - Inicializa o Terraform"
        echo -e "    validate                 - Valida o plano de execução"
        echo -e "    fmt                      - Formata os arquivos Terraform"
        echo -e "    plan                     - Gera o plano de execução"
        echo -e "    show                     - Exibe o plano de execução com JQ"
        echo -e "    infracost                - Verifica os custos da infraestrutura"
        echo -e "    apply                    - Aplica as mudanças"
        echo -e "    outputs                  - Exibe os outputs do Terraform"
        echo -e "    destroy                  - Destrói toda a infraestrutura"
        echo -e "    workspace                - Gerencia os workspaces"
        echo -e "    console                  - Abre o console do Terraform"
        echo -e "${GREEN}  Funções de segurança:${NC}"
        echo -e "    checkov                  - Executa o Checkov"
        echo -e "    tfsec                    - Executa o Tfsec"
        echo -e "    tflint                   - Executa o Tflint"
        echo -e "    terrascan                - Executa o Terrascan"
        echo -e "    kics                     - Executa o Kics"
        echo -e "${GREEN}  Funções de documentação:${NC}"
        echo -e "    setup_docs_structure     - Configura a estrutura de documentação"
        echo -e "    gera_docs                - Gera a documentação"
        exit 1
    fi

    comando=$1
    case $comando in
        "configure_backend")
            configure_backend
            ;;
        "validate_terraform_dir")
            validate_terraform_dir
            ;;
        "validate_tfvars")
            validate_tfvars
            ;;
        "init")
            init
            ;;
        "validate")
            validate
            ;;
        "plan")
            plan
            ;;
        "show")
            show
            ;;
        "infracost")
            infracost
            ;;
        "fmt")
            fmt
            ;;
        "apply")
            apply
            ;;
        "outputs")
            outputs
            ;;
        "destroy")
            destroy
            ;;
        "workspace")
            workspace "$@"
            ;;
        "console")
            console
            ;;
        "checkov")
            checkov
            ;;
        "tfsec")
            tfsec
            ;;
        "tflint")
            tflint
            ;;
        "terrascan")
            terrascan
            ;;
        "kics")
            kics
            ;;
        "setup_docs_structure")
            setup_docs_structure
            ;;
        "gera_docs")
            gera_docs
            ;;
        *)
            echo -e "${RED}Erro: Comando inválido${NC}"
            echo -e "${YELLOW}Comandos disponíveis:${NC}"
            echo -e "${ORANGE}  Funções de configuração do Backend: (RUN IT ONCE)${NC}"
            echo -e "    configure_backend        - Configura o backend remoto"
            echo -e "${GREEN}  Funções de validação:${NC}"
            echo -e "    validate_terraform_dir   - Valida se o diretório Terraform existe"
            echo -e "    validate_tfvars          - Valida se o arquivo common.tfvars existe"
            echo -e "${GREEN}  Funções principais:${NC}"
            echo -e "    init                     - Inicializa o Terraform"
            echo -e "    validate                 - Valida o plano de execução"
            echo -e "    fmt                      - Formata os arquivos Terraform"
            echo -e "    plan                     - Gera o plano de execução"
            echo -e "    show                     - Exibe o plano de execução com JQ"
            echo -e "    infracost                - Verifica os custos da infraestrutura"
            echo -e "    apply                    - Aplica as mudanças"
            echo -e "    outputs                  - Exibe os outputs do Terraform"
            echo -e "    destroy                  - Destrói toda a infraestrutura"
            echo -e "    workspace                - Gerencia os workspaces"
            echo -e "    console                  - Abre o console do Terraform"
            echo -e "${GREEN}  Funções de segurança:${NC}"
            echo -e "    checkov                  - Executa o Checkov"
            echo -e "    tfsec                    - Executa o Tfsec"
            echo -e "    tflint                   - Executa o Tflint"
            echo -e "    terrascan                - Executa o Terrascan"
            echo -e "    kics                     - Executa o Kics"
            echo -e "${GREEN}  Funções de documentação:${NC}"
            echo -e "    setup_docs_structure     - Configura a estrutura de documentação"
            echo -e "    gera_docs                - Gera a documentação"
            ;;
    esac
}

# Executa o script
main "$@"

