# Mega Man 8 Recomp — Android (Universal ARMv7 + ARM64)

**Maintainer:** Maizon — [GitHub](https://github.com/maizon) · [Instagram](https://instagram.com/maicon_nasciment0)

Projeto independente de portabilidade Android baseado no [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp), no framework Android [PSXRecomp](https://github.com/dguillot-gh/psxrecomp-android) e no [SDL](https://github.com/libsdl-org/SDL).

> **Estado: experimental.** O APK de shell produzido pelo CI serve para validar o pacote Android e as bibliotecas nativas; não é um jogo completo nem uma versão jogável de Mega Man 8. Não há garantia de FPS ou compatibilidade em dispositivos específicos.

## Aviso importante: conteúdo e direitos autorais

- Este repositório pretende distribuir código-fonte e documentação, não imagens de disco, BIOS, assets, música, vídeos, dados proprietários ou código gerado a partir do jogo.
- Mega Man, Mega Man 8 e seus elementos protegidos pertencem aos respectivos titulares. Este projeto é independente, não oficial e não é afiliado, patrocinado ou endossado pela Capcom.
- Não publique nem distribua ROMs, arquivos BIN/CUE/ISO, BIOS, assets, código gerado do jogo ou APK que incorpore conteúdo protegido sem obter as permissões necessárias.
- Compilar, modificar ou renomear um arquivo não concede direitos de redistribuição. Usar uma cópia pessoal também não significa automaticamente que seja permitido distribuir um APK derivado.
- Os projetos upstream e dependências mantêm suas próprias licenças. Consulte [avisos de terceiros](docs/THIRD_PARTY_NOTICES.md) antes de reutilizar ou redistribuir componentes.
- Este repositório não declara uma licença geral para todo o código do projeto. Não adicione uma licença ampla sem confirmar que você tem os direitos sobre cada parte abrangida.

**A publicação deste código não garante risco jurídico zero.** Revise o histórico Git, todos os arquivos e o APK exato que pretende publicar. Este README não é aconselhamento jurídico.

## Recursos e arquitetura

- Integração Android direcionada a ARMv7 (32-bit) e ARM64 (64-bit).
- Scripts de preparação de dependências e patches de compatibilidade.
- Workflow público para compilar/validar o shell sem dados do jogo.
- Fluxo local opcional de geração/compilação completa, que exige dados fornecidos localmente pelo usuário e não autoriza a redistribuição do resultado.
- Relatórios de desempenho e limitações em [docs/ANDROID-ARMV7-PERFORMANCE.md](docs/ANDROID-ARMV7-PERFORMANCE.md).

### Limitações conhecidas

- O artefato shell do CI não é jogável.
- O runtime smoke test não inclui o código gerado do jogo.
- O desempenho no Allwinner H726 ainda não foi diagnosticado; foi reportado desempenho de aproximadamente 1–2 FPS. Selecionar OpenGL na configuração não comprova que o renderizador OpenGL inicializou com sucesso.
- Vulkan, GPUs Mali e desempenho em dispositivos físicos continuam experimentais.
- Uma compilação bem-sucedida não substitui testes reais de instalação, execução, estabilidade e desempenho.

## Compilação do shell (sem dados do jogo)

Requisitos de referência: JDK 17, Git, Python 3, Gradle 8.9, Android SDK/NDK e CMake nas versões fixadas pelo workflow.

1. Clone este repositório.
2. Execute `bash scripts/prepare-upstream.sh`.
3. Obtenha SDL3 na versão/commit fixados no workflow, no caminho `third_party/SDL`.
4. Execute `gradle -p android --no-daemon clean assembleDebug`.

O shell não inclui os dados do jogo e não deve ser anunciado como uma versão jogável. Para as versões exatas da toolchain, consulte [android.yml](.github/workflows/android.yml).

## Compilação local completa

O script `scripts/build-full-android.sh` é um fluxo técnico local e pode exigir uma imagem de disco compatível fornecida pelo usuário. Use apenas materiais cuja utilização seja legal para você. O resultado pode conter código derivado ou conteúdo protegido: **não o publique nem o distribua sem confirmar que tem autorização para todos os componentes incluídos**.

Não envie imagens de disco, BIOS, código gerado do jogo ou APKs completos para o repositório, Issues, Pull Requests, Releases ou artefatos públicos do Actions.

Consulte [guia de compilação](docs/BUILDING.md) e [guia de Release manual](docs/RELEASE.md).

## APK universal e publicação manual

Um APK universal pode conter bibliotecas nativas para `armeabi-v7a` e `arm64-v8a`. Isso não significa que o jogo esteja completo ou funcione corretamente em ambas as arquiteturas.

Antes de publicar um APK manualmente:
1. Confirme a origem e os direitos de todos os componentes incluídos.
2. Verifique o conteúdo do APK e as bibliotecas nativas para ambas as arquiteturas.
3. Não publique assets, BIOS, imagem de disco ou código gerado do jogo sem autorização.
4. Informe a versão, o SHA-256, as arquiteturas e o estado real dos testes.
5. Não apresente o APK shell como jogo completo.

Veja [docs/RELEASE.md](docs/RELEASE.md). O CI atual valida artefatos de desenvolvimento sem dados do jogo; não é um canal de distribuição de uma versão completa.

## Créditos

- **Maizon** — integração Android, automação de build e investigação de desempenho.
- [Mega-Man-8-Recomp](https://github.com/omegakatana92/Mega-Man-8-Recomp) — projeto upstream de recompilação.
- [PSXRecomp Android framework fork](https://github.com/dguillot-gh/psxrecomp-android) — integração do runtime Android.
- [SDL](https://github.com/libsdl-org/SDL) — biblioteca multimídia multiplataforma.

Os créditos não substituem o cumprimento das licenças e permissões de cada projeto.
