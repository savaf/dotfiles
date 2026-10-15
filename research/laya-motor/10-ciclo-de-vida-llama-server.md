# Ciclo de vida de llama-server (b11622) para Clef-Flash

Ticket: `.scratch/laya-motor/issues/10-ciclo-de-vida-llama-server.md`. Medido el 2026-10-14 en WSL2 (Ubuntu, systemd `--user`), RTX 3080 10 GB, llama.cpp b11622 (CUDA 12.8), `Clef-Flash-Q4_K_M.gguf` (6,5 GB). Fuentes: `llama-server --help` del binario b11622, `tools/server/README.md` y `server-context.cpp` en la etiqueta `b11622` de ggml-org/llama.cpp, y mediciones propias. Todo con puertos de prueba (18931/18932) y unidades `clefr-test*` ya eliminadas; no se tocó la config real.

## Resumen

- **Descarga a los 2 min: existe, `--sleep-idle-seconds N`** (defecto -1 = off). Descarga modelo y KV de la memoria; la siguiente petición lo recarga sola. El proceso sigue vivo, así que el apagado a los 5 min hay que hacerlo fuera.
- **Apagado a los 5 min: llama-server no lo ofrece** (no hay flag de salida por inactividad). Sí sirve `.socket` + `systemd-socket-proxyd --exit-idle-time` + backend `StopWhenUnneeded=yes`, probado aquí.
- **Trampa de tamaño de prompt**: por defecto `n_batch = n_ubatch = 512` y todo el prompt de Clef debe caber en un batch; con más de 512 tokens la respuesta es HTTP 500. Hay que lanzar con `-ub 2048 -b 2048` (o más).
- **Concurrencia**: aunque haya 4 slots, las peticiones se atienden en serie (~57 ms cada una). Con 3 clientes a la vez el peor espera ~180 ms. No hace falta tocar `-np`.

## 1. Flags relevantes (`--help` b11622)

| Necesidad | Flag / env | Notas |
|---|---|---|
| Dormir por inactividad | `--sleep-idle-seconds N` | README, "Sleeping on Idle" (PR #18228). `GET /health`, `/props`, `/models`, `/metrics` no cuentan como actividad ni despiertan. No tiene variable de entorno documentada en `--help`. |
| Estado dormido | `GET /props` → `"is_sleeping": true` | `/props` pide `--api-key` si está activa (devolvió 401 sin clave; `/health` es público). |
| Bind | `--host` (defecto `127.0.0.1`, acepta lista o rutas `*.sock`), `--port` (defecto 9931) | Defecto ya es solo loopback. También acepta socket Unix (`--host /ruta/x.sock`), no probado. |
| Auth | `--api-key KEY` (lista separada por comas, env `LLAMA_API_KEY`), `--api-key-file FNAME` | Medido: sin clave o con clave mala → 401 en `/v1/systemone`; `/health` queda público. Preferir `--api-key-file` para que la clave no salga en `ps`. |
| GPU | `-ngl 99` | VRAM 6,6 GB (6 639 MiB con base 596 MiB). |
| Slots | `-np N` (defecto auto: 4), `-kvu` | Con `-c 4096 -np 1` la VRAM es igual (6 633 MiB): pesos dominan. Sin `-c` el log muestra `n_ctx_slot = 262144` (contexto del modelo), recomendable fijar `-c` para no reservar KV de más. |
| Batch | `-b`, `-ub` (defecto 2048 / 512; con embeddings el log avisa `n_batch = n_ubatch = 512`) | Ver sección 4. |
| Socket activation | no existe | `grep LISTEN_FDS\|sd_listen` en `server.cpp`/`server-context.cpp` b11622: sin resultados. llama-server no hereda sockets; hace falta proxy. |

## 2. Router mode (`--models-dir` / `--models-preset`, sin `-m`)

Probado con `--models-dir ~/clef-probe/models --sleep-idle-seconds 8`:

- El router arranca en 0,18 s, `/health` = 200 con 0 VRAM extra (590 MiB) y 1 proceso. `GET /models` lista `Clef-Flash-Q4_K_M` con `status.value = "unloaded"` y `architecture.output_modalities = ["decisions"]` (detectable sin cargar, README "Using multiple models").
- La primera petición con `"model":"Clef-Flash-Q4_K_M"` lanza un proceso hijo (procs: 2) y tarda 1,99 s (pesos en caché de página). Tras el idle el hijo queda `sleeping` (VRAM 834 MiB, el hijo sigue vivo) y la petición siguiente despierta en 1,72 s.
- El router **no se apaga solo**; sigue residente (proceso extra, RAM baja, 0 VRAM). Añade un proceso y un salto interno por petición sin ganar nada para un único modelo. Solo compensaría con varios modelos (`--models-max`, defecto 4). Conclusión: para un solo Clef, modo single + `--sleep-idle-seconds` + proxy de apagado es más simple.

## 3. Señal de listo

- El puerto se abre casi al instante; `/health` devolvió, en orden: `000` (conexión rechazada, ~8 ms), `503` ("Loading model", desde ~0,12 s) y `200` `{"status":"ok"}` al terminar de cargar (README: 503 = cargando, 200 = listo).
- Importante para `systemd-socket-proxyd`: como el puerto escucha mientras carga, el proxy conectaría antes de tiempo. En la prueba con `ExecStartPost` que espera `curl -sf /health` hasta 200 (bucle de 50 ms, tope 10 s) el cliente en frío vio 200 sin errores. Sin esa espera el primer cliente recibiría 503 del backend.
- Durante el sleep `/health` sigue en 200 (no está en el conjunto que despierta), así que `/health` no distingue dormido; usar `/props.is_sleeping` si hace falta.

## 4. Concurrencia y tamaño de prompt para `/v1/systemone`

- README: Clef "lee todas las preguntas en un prompt y las decide juntas"; el prompt entero se evalúa en un batch y "must fit in `--ubatch-size`"; un servidor Clef solo sirve `/v1/systemone` (no hay generación de texto).
- **Medido (defecto)**: estado de ~160 palabras (393 tokens) → 200; ~400 palabras (738 tokens) → HTTP 500 `input (738 tokens) is too large to process. increase the physical batch size (current batch size: 512)`; 1 543 tokens → 500. **Con `-ub 2048 -b 2048`**: 738 tokens → 183 ms, 1 543 tokens → 381 ms, todos 200. El hook debe truncar el prompt o el servidor subir `-ub`; recomendado `-ub 2048 -b 2048` más truncado en el cliente.
- **Concurrencia (4 slots, `-np 1` da lo mismo)**: 3 clientes simultáneos → 64, 121, 175 ms (wall 177 ms): se atienden en serie, ~57 ms cada uno, todos 200. 8 clientes → el último a 459 ms, todos 200, sin 503. Los slots no paralelizan la decisión; con un uso real (pocas Decisiones simultáneas) no hace falta cola propia. No verifiqué que las respuestas bajo paralelismo sean idénticas a las secuenciales con estados distintos (las de la prueba usaban el mismo estado).

## 5. Latencias (WSL2, GPU)

Las cifras de arranque son con el modelo en caché de página salvo donde se indica.

| Medida | Resultado |
|---|---|
| Arranque en frío, VRAM libre (590 MiB) hasta `/health` 200 | **2,56 s** (caché de página caliente) |
| Igual tras `posix_fadvise(DONTNEED)` sobre el .gguf (caché de página descartada, aprox.) | **3,58 s** |
| Primera petición tras `ready` | 77-372 ms (calentamiento CUDA) |
| Petición caliente (30 seguidas) | mediana 57 ms, p95 60-63 ms, máx 69-76 ms |
| Despertar tras sleep (VRAM 832 → 6 652 MiB) | **1,96 s** (pesos en caché de página) |
| VRAM en sleep | 832-842 MiB (≈ 250 MiB por encima de la base de 590: contexto CUDA) |
| RSS tras cargar | ~1,17 GB (resto mmap) |

Nota: el sleep libera ~5,8 GB de VRAM pero deja ~250 MiB y el proceso; solo la salida del proceso devuelve todo (VRAM volvió a 580-590 MiB tras la parada).

## 6. Patrón systemd `--user` con llama-server (probado)

Unidades de prueba, con tiempos acortados (sleep 8 s, proxy exit-idle 20 s; en real 120 s y 300 s):

```ini
# clef.socket
[Socket]
ListenStream=127.0.0.1:18932
[Install]
WantedBy=sockets.target

# clef.service  (el proxy; el nombre debe coincidir con el .socket)
[Unit]
Requires=clef-llama.service
After=clef-llama.service
[Service]
ExecStart=/usr/lib/systemd/systemd-socket-proxyd --exit-idle-time=20s 127.0.0.1:18931

# clef-llama.service
[Unit]
StopWhenUnneeded=yes
[Service]
Environment=LD_LIBRARY_PATH=<llama dir>:<cudart dir>:/usr/lib/wsl/lib
WorkingDirectory=<llama dir>
ExecStart=<llama dir>/llama-server -m <gguf> -ngl 99 -c 4096 -ub 2048 -b 2048 --host 127.0.0.1 --port 18931 --api-key-file <f> --sleep-idle-seconds 120
ExecStartPost=/bin/sh -c 'i=0; until curl -sf http://127.0.0.1:18931/health >/dev/null; do i=$((i+1)); [ $i -gt 200 ] && exit 1; sleep 0.05; done'
TimeoutStartSec=30
```

Resultados (ciclo completo):

1. Reposo: socket `active`, proxy/llama `inactive`, 0 procesos, 581 MiB.
2. Primera petición por el socket (frío): **2,14 s**; llama y proxy pasan a `active`, 6 632 MiB.
3. 3 paralelos calientes: 76/131/186 ms.
4. A los 12 s sin uso: llama dormido (832 MiB), unidades siguen activas; la petición siguiente por el socket tarda 1,78 s (despertar).
5. A los 28 s sin uso: proxy `inactive` (salió por idle), llama parado por `StopWhenUnneeded`, 0 procesos, 586 MiB.
6. 3 paralelos en frío por el socket: 2,20/2,28/2,34 s, todos 200; vuelve a quedar todo parado tras el idle.

Detalles:
- El `.socket` exige un `.service` del mismo nombre (primer intento con `clefr-test-proxy.service` falló con "Socket service ... not loaded"). El proxy es ese servicio.
- `StopWhenUnneeded` + `Requires=` del proxy sobre el backend es lo que apaga llama-server al salir el proxy; el sleep (120 s) queda dentro de los 300 s del proxy, cumpliendo "duerme a los 2 min, sale a los 5".
- La espera de `ExecStartPost` es necesaria (el puerto abre antes de terminar de cargar, sección 3). llama-server no hace `sd_notify`.
- Un cliente que mantenga la conexión abierta cuenta como actividad para `--exit-idle-time`; los clientes de los hooks deben cerrar la conexión (urllib lo hace).
- Misma clase de patrón ya probada con Laya (ticket 03); aquí solo cambia el backend y la espera de listo.

## 7. macOS

No probado (no hay Mac). Por lo leído:
- llama-server no consume sockets heredados (sin `LISTEN_FDS`), y launchd no tiene equivalente de `--exit-idle-time`, así que `launchd` `Sockets` no basta (ya concluido en el ticket 03). Sigue haciendo falta el lanzador propio en stdlib ("lazyd"), que escucha, lanza llama-server al primer cliente, hace de proxy y mata el proceso tras 5 min.
- Con `lazyd` el servidor puede llevar `--sleep-idle-seconds 120` igual que en Linux; la espera de listo es `/health` = 200.
- Pendiente de verificar en Apple Silicon: binario Metal de la release b11622+ para macOS arm64, que `Clef-Flash-Q4_K_M` quepa y su latencia (el mapa lo marca "por verificar"). Sin GPU capaz se mantiene el Fallo abierto.

## Recomendación para el diseño

Linux/WSL: tres unidades como arriba, con `-ub 2048 -b 2048`, `-c 4096`, `--host 127.0.0.1`, `--api-key-file`, `--sleep-idle-seconds 120`, `--exit-idle-time=300s`, `-ngl 99`. No usar router mode. Presupuesto del hook: ~2-3,6 s en frío (supera el umbral de 5 s solo con disco muy lento), ~60 ms caliente, hasta ~180 ms con 3 simultáneos. macOS: lazyd.
