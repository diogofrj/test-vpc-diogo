<!-- BEGIN_TF_DOCS -->
# Módulo Terraform: Nome do Projeto

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)

Este módulo é responsável por criar recursos na AWS para [descrição do propósito].

## Arquitetura

![Arquitetura](./docs/images/architecture.png)

## Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado
- Permissões necessárias:
  - ec2:*
  - vpc:*

## Índice

- [Requisitos](#requisitos)
- [Providers](#providers)
- [Recursos](#recursos)
- [Inputs](#inputs)
- [Outputs](#outputs)

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.80.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.80.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.2 |

## Resources

| Name | Type |
|------|------|
| [aws_vpc.example](https://registry.terraform.io/providers/hashicorp/aws/5.80.0/docs/resources/vpc) | resource |
| [local_file.vpc_id](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

No inputs.

## Outputs

No outputs.

## Contribuição

1. Faça um fork do projeto
2. Crie sua branch de feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## Licença

Copyright © 2024 [Nome da Empresa]

## Contato

- Time DevOps - devops@empresa.com
- Time SRE - sre@empresa.com
<!-- END_TF_DOCS -->