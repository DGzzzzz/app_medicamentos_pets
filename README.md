# Medicamentos Pets

Aplicativo Android para controle de medicamentos de pets, com notificações automáticas de vencimento.

## Download

[![Download APK](https://img.shields.io/github/v/release/DGzzzzz/app_medicamentos_pets?label=Download%20APK&logo=android&color=2E7D32)](https://github.com/DGzzzzz/app_medicamentos_pets/releases/latest)

Baixe o APK mais recente em [Releases](https://github.com/DGzzzzz/app_medicamentos_pets/releases/latest) e instale diretamente no Android.

## Funcionalidades

- **Agendamentos** — Cadastre medicamentos com data de aplicação e validade
- **Pets** — Vincule cada medicamento a um pet específico
- **Notificações** — Receba alertas automáticos de vencimento próximo e medicamentos vencidos
- **Histórico** — Finalize agendamentos concluídos e consulte o histórico por pet
- **Perfil** — Autenticação com e-mail/senha ou Google, com foto de perfil

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| Framework | Flutter (Dart) |
| Backend / Auth / DB | Supabase |
| Notificações | flutter_local_notifications |
| Background tasks | Workmanager |

## Requisitos

- Android 5.0 (API 21) ou superior
- Conexão com internet

## Como instalar

1. Acesse [Releases](https://github.com/DGzzzzz/app_medicamentos_pets/releases/latest)
2. Baixe o arquivo `app-release.apk`
3. Abra o arquivo no celular e toque em **Instalar**
4. Se solicitado, permita a instalação de fontes desconhecidas

## Como compilar

```bash
# Clonar o repositório
git clone https://github.com/DGzzzzz/app_medicamentos_pets.git
cd app_medicamentos_pets

# Instalar dependências
flutter pub get

# Executar em debug
flutter run

# Gerar APK de release (requer key.properties configurado)
flutter build apk --release
```

### Configuração do signing (release)

Crie o arquivo `android/key.properties` (não commitado) com o seguinte conteúdo:

```properties
storePassword=sua_senha
keyAlias=seu_alias
keyPassword=sua_senha_da_chave
storeFile=app/keystore/release.jks
```

## Licença

Copyright (c) 2026 DGzzzzz. Todos os direitos reservados.

O código-fonte deste repositório é disponibilizado publicamente **apenas para fins de visualização e referência técnica**.

É **expressamente proibido**, sem autorização prévia e por escrito do autor:

- Copiar, reproduzir ou reutilizar qualquer parte do código
- Modificar, adaptar ou criar obras derivadas
- Distribuir, sublicenciar ou publicar o código ou qualquer derivado
- Usar o código, no todo ou em parte, em produtos comerciais ou não comerciais

Este projeto não é open source. A publicidade do repositório não implica concessão de qualquer licença de uso.

Para solicitações de uso ou parcerias, entre em contato pelo GitHub.
