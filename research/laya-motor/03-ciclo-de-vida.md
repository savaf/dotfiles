# Laya: arranque bajo demanda y apagado por inactividad

Ticket: `.scratch/laya-motor/issues/03-arranque-bajo-demanda.md`. Fecha: 2026-10-14.
Fuentes: código de `laya` 0.4.7 (wheel de PyPI, `laya/serve.py`), man pages de systemd y
`launchd.plist(5)`, y medidas propias en esta máquina (WSL2, 8 cores lógicos, 16 GB, ext4 en disco real,
Python 3.14, torch 2.14.1+cpu, `LAYA_THREADS=4`).

## Conclusión corta

1. `laya-serve` solo habla **TCP** (`LAYA_HOST`/`LAYA_PORT`), con bind por defecto **`0.0.0.0:8000`**.
   Auth opcional por Bearer. No tiene UDS, ni activación por socket, ni salida del proceso por inactividad.
2. Lo que sí tiene: `LAYA_IDLE_UNLOAD_SECONDS` descarga los checkpoints (no mata el proceso) y carga
   perezosa con `LAYA_PRELOAD=0`. Eso cubre los "2 min" de forma nativa; los "5 min" hay que ponerlos fuera.
3. Con systemd `--user`: `.socket` + `systemd-socket-proxyd --exit-idle-time=` + backend con
   `StopWhenUnneeded=yes`. **Probado aquí y funciona** (arranque en frío ~3,3 s, apagado completo al
   expirar el idle). Sirve para Arch, Bazzite y WSL2 con `systemd=true`.
4. macOS: launchd tiene activación por socket pero **no** apagado por inactividad ni proxy equivalente,
   y `laya-serve` no hace `launch_activate_socket`. Hace falta un lanzador/proxy propio.
5. Recomendación: un único mecanismo portable (un proxy pequeño en Python, "lazyd") evita mantener dos
   rutas; systemd-socket-proxyd es la opción nativa si se acepta tener dos rutas (Linux / macOS).

## 1. Qué ofrece `laya-serve` 0.4.7

Fuente: `laya/serve.py` (docstring de módulo, `create_app`, `main`).

| Aspecto | Comportamiento |
|---|---|
| Transporte | Solo TCP. `main()` llama `uvicorn.run(create_app(), host=LAYA_HOST, port=LAYA_PORT, ...)`; no hay opción UDS ni `fd`. |
| Bind por defecto | `LAYA_HOST=0.0.0.0`, `LAYA_PORT=8000`. Expuesto a toda la red salvo que se fije `127.0.0.1`. |
| Auth | `LAYA_API_KEY`: si está, exige `Authorization: Bearer <clave>` (comparación `hmac.compare_digest`). `/health` sin clave devuelve solo liveness. Sin variable no hay auth. |
| Carga | `LAYA_PRELOAD` (def. 1) carga los checkpoints **antes** de abrir el puerto. Con `0` el puerto abre en ~1 s y el modelo se carga en la primera petición. |
| Descarga por inactividad | `LAYA_IDLE_UNLOAD_SECONDS` (def. 0 = off). Una tarea `_idle_reaper` comprueba cada `min(N/4, 5)` s y llama `router.unload()` en el hilo de inferencia. El proceso sigue vivo; la siguiente petición recarga. |
| Terminar el proceso | No existe. Ninguna variable ni endpoint apaga el servidor por inactividad. |
| Serialización | Inferencia en un `ThreadPoolExecutor(max_workers=1)` más un `asyncio.Lock` (`gate`): una pasada a la vez. Las peticiones concurrentes esperan en cola. `LAYA_MAX_CONCURRENT` (def. 16) acota las admitidas; el exceso recibe **503**. |
| Durante la carga | Con `PRELOAD=0` la carga ocurre dentro de la primera petición (en el worker); las demás esperan en el `gate`. `/health` responde mientras tanto (el bucle de eventos no se bloquea). Con `PRELOAD=1` nada responde hasta terminar la carga. |
| Otros | `LAYA_MODELS` (qué precargar), `LAYA_MAX_LOADED` (def. 2), `LAYA_THREADS`, `LAYA_DEVICE`, `LAYA_ROOT_PATH`, `LAYA_EXTRA_MODELS`. API: `POST /v1/systemone`, `POST /v1/systemone/batch`, `GET /health`. |

Atajo verificado: `laya.serve:create_app` se puede lanzar con uvicorn como factory y entonces **sí**
admite UDS (`uvicorn laya.serve:create_app --factory --uds RUTA`) y `--fd N`. Probado: `GET /health`
por `curl --unix-socket` respondió. Es API interna (no documentada como contrato), pero evita exponer TCP.
Con `--uds` el control de acceso pasa a ser los permisos del fichero; con TCP loopback cualquier proceso
local del equipo puede hablar con el servidor, así que conviene `LAYA_API_KEY`.

## 2. Medidas en esta máquina (WSL2, CPU)

Script de medida: servidor en `127.0.0.1`, cliente HTTP, `LAYA_PRELOAD=0`, `LAYA_IDLE_UNLOAD_SECONDS=10`.
Modelo por defecto del router (`HF_HOME` dedicado, 808 MB en disco tras la primera ejecución; no se
comprobó qué checkpoint concreto se descargó).

| Medida | Valor |
|---|---|
| Descarga de pesos (primera vez, red) | 98 s en la primera petición (808 MB); precargar el bundle completo la subió a 153 s |
| Puerto abierto tras lanzar (PRELOAD=0) | ~1,0 s (RSS 320 MB) |
| Primera petición, pesos ya en disco | 2,4 s (arranque total ~3,4 s) |
| RSS con el modelo cargado | ~2,15 GB (~3,5 GB con dos checkpoints residentes) |
| Petición caliente (`/v1/systemone`, 1 pregunta `choice`) | mín. 100 ms, mediana 105 a 117 ms, máx. ~140 ms |
| Tras el unload por idle | RSS baja a 0,67 GB en una prueba y solo a 1,96 GB en otra (el allocator no devuelve todo); el proceso sigue vivo |
| Primera petición tras el unload | 0,5 a 0,6 s (recarga desde page cache) |

Lectura: el arranque en frío de Python+torch+modelo ronda 3 a 4,5 s con pesos en caché de disco; la
recarga tras el unload es ~0,5 s. La RAM no vuelve a la base con el unload (hasta 2 GB retenidos), por eso
terminar el proceso a los 5 min es lo que de verdad libera memoria. Hay que presupuestar la descarga inicial
de los pesos (800 MB a 1,2 GB) como paso de instalación, no como latencia de primera petición.
Los números son de una sola máquina y muestra pequeña; el inicio frío real depende de si los pesos están
en el page cache.

## 3. systemd `--user` (Arch/Omarchy, Bazzite, WSL2 con `systemd=true`)

Esta máquina: WSL2 con `/etc/wsl.conf` `systemd=true`, systemd 259, `systemctl --user` en estado `running`,
`/usr/lib/systemd/systemd-socket-proxyd` presente. Bazzite (Fedora atómico) y Omarchy (Arch) traen systemd
de serie; el venv/uv del usuario vive en `$HOME`, así que no hay problema con el sistema inmutable.

Patrón probado (nombres de PoC, ya eliminados; los tiempos están reducidos: unload 20 s, proxy 40 s):

```ini
# laya-backend.service
[Unit]
StopWhenUnneeded=yes
[Service]
Type=exec
Environment=LAYA_HOST=127.0.0.1 LAYA_PORT=18771 LAYA_PRELOAD=0 LAYA_IDLE_UNLOAD_SECONDS=120 LAYA_THREADS=4
ExecStart=%h/.local/share/laya/venv/bin/laya-serve
# laya-serve no hace sd_notify: sin esto el proxy conecta antes de que abra el puerto y descarta la petición
ExecStartPost=/usr/bin/timeout 60 /bin/bash -c 'until (exec 3<>/dev/tcp/127.0.0.1/18771) 2>/dev/null; do sleep 0.1; done'

# laya-proxy.socket
[Socket]
ListenStream=127.0.0.1:18770      # o %t/laya.sock para UDS
[Install]
WantedBy=sockets.target

# laya-proxy.service
[Unit]
Requires=laya-backend.service
After=laya-backend.service
[Service]
ExecStart=/usr/lib/systemd/systemd-socket-proxyd --exit-idle-time=300s 127.0.0.1:18771
```

Resultados medidos:

- Antes de la primera petición: socket activo, proxy y backend `inactive`.
- 3 clientes concurrentes en frío: todos respondieron `billing` en 3,3 a 3,5 s (muro 3,48 s); el
  backend atiende en serie por el `gate` pero a ~0,1 s cada una no se nota.
- Petición caliente: 0,09 s a través del proxy.
- Al expirar `--exit-idle-time` el proxy sale y `StopWhenUnneeded=yes` para el backend: ambos `inactive`
  (comprobado a ~55 s con el valor de prueba de 40 s).
- Siguiente petición: re-arranque en 4,5 s.
- Limpieza hecha: units desenlazadas, sin procesos `laya-serve`.

Notas:

- `--exit-idle-time` cuenta desde que no hay **conexiones**; con keep-alive abierto desde un cliente
  no expira. Los clientes deben cerrar la conexión por petición (hooks de Claude Code con `curl` lo hacen).
- Valores objetivo del ticket: `LAYA_IDLE_UNLOAD_SECONDS=120` y `--exit-idle-time=300s`. El proxy cuenta
  conexiones y Laya peticiones, pero con una conexión por petición ambos relojes coinciden.
- Alternativa sin proxy: `ExecStart=uvicorn laya.serve:create_app --factory --fd 3` con `.socket`
  (activación directa). Ahorra un proceso pero depende de API interna y sigue sin apagado por idle, así que
  el proxy sigue siendo necesario para los 5 min.
- Para que el servicio persista sin sesión abierta hace falta `loginctl enable-linger`; no es necesario si
  la socket se levanta al iniciar sesión (WSL2 arranca systemd al abrir la distro).

Fuentes: `systemd-socket-proxyd(8)` (`--exit-idle-time`), `systemd.socket(5)`,
`systemd.unit(5)` (`StopWhenUnneeded=`), `sd_listen_fds(3)`; todas en
<https://www.freedesktop.org/software/systemd/man/>.

## 4. macOS: launchd

Fuente: `launchd.plist(5)` (<https://keith.github.io/xcode-man-pages/launchd.plist.5.html>, espejo de la man page).

- Existe activación por socket: clave `Sockets` (`SockServiceName`, `SockNodeName`, `SockPathName`), pero
  el trabajo debe recoger los descriptores con `launch_activate_socket(3)`. `laya-serve` no lo hace, así que
  launchd no se puede poner delante tal cual.
- No hay apagado por inactividad temporizado. `TimeOut` "no se implementa"; `EnablePressuredExit` es por
  presión de memoria, no por tiempo, y no se respeta con `KeepAlive` true.
- No hay equivalente a `systemd-socket-proxyd` ni a `StopWhenUnneeded`.
- Por tanto, en macOS el idle-exit lo tiene que hacer un proceso nuestro. Opciones: (a) un agente launchd
  que ejecute el mismo proxy "lazyd" de la sección 5 en el puerto/UDS público (el agente arranca con la
  sesión, ocupa pocos MB), o (b) el cliente-lanzador sin demonio de la sección 5.
- Además, el instalador de torch para macOS x86 está más limitado (el extra `onnx` fija `numpy<2` en
  Darwin x86_64, según metadatos del paquete); no se probó aquí.

## 5. Alternativa sin systemd (macOS, WSL sin systemd, contenedores)

Dos variantes, ambas con el mismo contrato (puerto/UDS fijo, un solo servidor):

1. **Cliente lanza + lockfile.** El hook de Claude Code intenta conectar; si falla, toma `flock` sobre
   `$XDG_RUNTIME_DIR/laya.lock`, relanza `laya-serve` detached (`setsid`), espera `/health` y reintenta.
   El flock evita doble arranque con varias sesiones. Falta el apagado: el servidor no sale solo, así que
   hace falta un reaper (cron/launchd `StartInterval`) o un wrapper. Más piezas móviles.
2. **"lazyd" en Python (~40 líneas, solo stdlib `asyncio`).** Escucha en el puerto/UDS público, al primer
   cliente lanza `laya-serve` en loopback con `LAYA_IDLE_UNLOAD_SECONDS`, espera el puerto, hace de proxy
   TCP y mata al hijo tras 300 s sin conexiones. Es el análogo exacto de socket-proxyd y funciona igual en
   todos los OS; se supervisa con systemd (como servicio normal, arranque con la sesión) o launchd
   (`RunAtLoad`). Sin dependencias nuevas. No se implementó ni se midió aquí.

## 6. Matriz por OS

| OS | Mecanismo recomendado | Estado |
|---|---|---|
| Arch/Omarchy | systemd `--user`: socket + socket-proxyd + backend | Mismo patrón; no se probó en esta distro, systemd 259 aquí |
| Ubuntu WSL2 (`systemd=true`) | igual | **Probado** |
| Bazzite | igual (Fedora, systemd; venv en `$HOME`) | No probado; mismo systemd |
| macOS | agente launchd que ejecuta lazyd (o cliente-lanzador) | No probado; launchd no ofrece idle-exit |
| Sin systemd | lazyd lanzado por el cliente con flock | No probado |

## Riesgos y huecos

- Datos de un solo host; latencias de otros equipos pueden variar.
- La descarga inicial (800 MB a ~1,2 GB según qué checkpoints) no cabe en la latencia bajo demanda: precalentar en el instalador.
- `--uds`/`--fd` con `create_app --factory` no es contrato público de Laya 0.4.x.
- No se midió RAM sin torch ni la ruta ONNX; no se probó macOS ni Bazzite.
