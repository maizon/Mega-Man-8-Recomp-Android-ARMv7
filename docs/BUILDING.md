# Guia de compilação

## A. Shell Android sem dados do jogo

Este caminho serve para compilar o invólucro Android e validar a integração de plataforma. Não produz, por si só, um jogo completo.

### Requisitos

Use as versões indicadas em `.github/workflows/android.yml`: JDK 17, Gradle 8.9, Android SDK Platform 35, Build Tools 35.0.0, NDK 27.2.12479018 e CMake 3.22.1, além de Git e Python 3.

### Passos gerais

1. Clone o repositório.
2. Execute `bash scripts/prepare-upstream.sh` para obter/preparar as revisões públicas fixadas.
3. Clone SDL na versão indicada pelo workflow para `third_party/SDL`.
4. Compile com `gradle -p android --no-daemon clean assembleDebug`.

O caminho exato de dependências pode variar conforme ambiente e as instruções mantidas no workflow. Não inclua dados do jogo na compilação pública de shell.

## B. Compilação completa local

O script `scripts/build-full-android.sh` é opcional e exige os inputs do jogo localmente. Use apenas dados que você tem direito de utilizar. A compilação pode gerar código derivado do jogo; a posse de uma imagem de disco não concede automaticamente o direito de publicar ou redistribuir o resultado.

Não faça upload de ROMs, BIOS, assets, código gerado ou APK completo para o GitHub Actions, repositório público ou Release sem autorização expressa para os componentes relevantes.

## Verificação

Uma compilação bem-sucedida prova apenas que o processo de build terminou. Ela não comprova jogabilidade, desempenho, compatibilidade física ou autorização para redistribuição. Teste separadamente cada arquitetura e dispositivo-alvo.
