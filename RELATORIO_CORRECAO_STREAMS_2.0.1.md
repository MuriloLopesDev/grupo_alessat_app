# Grupo Alessat App 2.0.1 — gerenciamento de streams

Data: 07/08/2026

## Integração utilizada

O mosaico é montado localmente. Para cada câmera selecionada, o aplicativo
solicita o live media ao Moovsec:

```text
GET https://moovsec.alessat.com.br:3000/dvr/{deviceSerial}/livemedia
    ?channel={canal}
    &streamType=SubStream
    &forceStreamType=true
    &thumbnail=true
```

Após receber uma URL HLS (`.m3u8`), o aplicativo abre a mídia com `media_kit`.
O conteúdo é servido pelo endereço informado pela API, normalmente no serviço
`https://moovsec.alessat.com.br:3010`.

## Correções da versão 2.0.1

- Limite de 32 câmeras simultâneas por visualização, conforme requisito do
  cliente.
- Limite rígido de cinco chamadas simultâneas à API, com fila FIFO.
- Timeout de 15 segundos por chamada e reutilização das conexões HTTP.
- Máximo de cinco tentativas de preparação por câmera.
- Backoff de 1, 2, 4 e 8 segundos entre tentativas.
- Deduplicação por dispositivo e canal.
- Bloqueio de carregamentos concorrentes da mesma câmera.
- Cancelamento lógico de respostas pertencentes a mosaicos já fechados.
- Encerramento aguardado dos players antigos antes da abertura dos novos.
- Cancelamento das inscrições vinculadas aos players descartados.
- Remoção das reconexões automáticas ilimitadas; após erro do player, a
  interface oferece reconexão manual controlada.

## Efeito esperado

Uma câmera indisponível deixa de consultar a API após a quinta tentativa.
Trocas rápidas de mosaico não podem criar vários players para o mesmo canal, e
uma resposta atrasada não pode reabrir um stream removido. Cada instância do
aplicativo mantém no máximo 32 sessões HLS simultâneas.

## Validação recomendada

Durante a homologação, acompanhar a quantidade de sessões/processos nos
serviços das portas 3000 e 3010 ao abrir, trocar e fechar mosaicos de 32
câmeras.
