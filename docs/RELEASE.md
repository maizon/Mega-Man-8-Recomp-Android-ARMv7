# Guia de Release manual

Este guia é para publicar um artefato que você revisou manualmente. Não dispara builds e não presume que qualquer APK existente esteja liberado para redistribuição.

## Antes de criar a Release

- [ ] Identifique exatamente o commit/tag e o APK que pretende publicar.
- [ ] Confirme que você tem os direitos e permissões necessários para todos os componentes do APK.
- [ ] Inspecione o conteúdo do APK. Não publique imagens de disco, BIOS, assets, música, vídeos, código gerado do jogo ou outros materiais protegidos sem autorização.
- [ ] Confirme se as bibliotecas nativas incluem `armeabi-v7a` e `arm64-v8a`, caso a Release seja anunciada como universal.
- [ ] Verifique assinatura, integridade do ZIP e hash SHA-256.
- [ ] Faça testes reais de instalação, inicialização e jogabilidade; descreva os resultados sem exagerar.
- [ ] Inclua as limitações conhecidas e os créditos/licenças necessários.

## Publicação manual no GitHub

1. Abra o repositório e acesse **Releases**.
2. Escolha **Draft a new release**.
3. Crie uma tag de versão que corresponda ao commit revisado.
4. Escreva notas com versão, arquiteturas, requisitos, limitações e resultados dos testes.
5. Anexe somente o APK que passou pela revisão de conteúdo e direitos.
6. Confira a página em modo de rascunho antes de publicar.

## Atenção ao conteúdo do jogo

Um APK universal não é automaticamente redistribuível. Se incluir código gerado a partir de Mega Man 8, assets ou outros elementos protegidos, não o publique sem confirmar que tem autorização para essa redistribuição. Não é suficiente remover os arquivos BIN/CUE do repositório se o APK ainda incorpora conteúdo protegido.

O artefato shell do CI não contém os dados necessários para representar uma versão completa e jogável; não o anuncie como o jogo completo.
