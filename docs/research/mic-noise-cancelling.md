# Supresión de ruido del micrófono para Discord (Arch/Omarchy, PipeWire)

Nota de investigación, fecha 2026-11-08. Solo hechos y comparación; **no recomienda ni decide**.
Todo lo marcado *(no verificado)* o *(inferencia)* no está confirmado por una fuente primaria.

## 0. Estado de la máquina (verificado localmente)

- PipeWire 1.6.9, WirePlumber 0.5.18, `pipewire-pulse` 1.6.9 (`pacman -Q`).
- Fuente por defecto: "Fifine Microphone Mono" (`wpctl status`); también C920 y audio integrado.
  Un stream "Brave input" captura de la Fifine.
- **Discord no está instalado como app nativa.** Existe como *webapp de Omarchy*: `~/.local/share/applications/Discord.desktop`
  con `Exec=omarchy-launch-webapp https://discord.com/channels/@me`, declarado en `packages/omarchy-webapps.txt`
  (`Discord|https://discord.com/app|...`). `omarchy-launch-webapp` lo abre en el navegador por defecto
  (aquí Brave, un Chromium). `flatpak` no está instalado; `pacman -Qs discord` y `command -v discord vesktop` no devuelven nada.
- Existe `discord` en `extra` (`pacman -Si`: `1:1.0.164-1`) y en AUR hay `vesktop`, `vesktop-bin`, `equibop-bin`, `webcord` (ver §8).
- No hay `~/.config/pipewire/`; sí `~/.config/wireplumber/wireplumber.conf.d/` (2 ficheros ajenos al tema, bluetooth y KEF).
- Cómo se declaran paquetes: `packages/arch-apps.txt` (instalado con `yay -S --needed` por `scripts/install-packages.sh`, repos + AUR;
  `docs/omarchy.md` línea ~320). Los paquetes Stow se listan en `STOW_PACKAGES` de `scripts/modules/stow.sh` (usa `--no-folding`).
  Ojo: `arch-apps.txt` es "apps GUI"; no hay hoy un manifiesto aparte para librerías/plugins de audio *(observación local)*.

## 1. Krisp integrado de Discord en Linux

**Qué dice la fuente oficial.** El [Krisp FAQ de Discord](https://support.discord.com/hc/en-us/articles/360040843952-Krisp-FAQ)
(editado 2025-03-25 según la API del Help Center) afirma:

- "Krisp is supported on Windows, Linux, Mac, Android, and iOS" (Mac requiere CPU Apple y macOS 12+).
- El modelo corre en el dispositivo; "no data is ever sent to Krisp's servers".
- "As of October 30, 2023, Krisp is available on Chrome and Firefox desktop browsers." (Brave no se menciona: *no verificado* si funciona en Brave.)
- Si el uso de CPU es muy alto, "Krisp will automatically turn off".
- Se activa con el icono de *Noise Suppression* durante una llamada, o en Ajustes > Voz y vídeo > *Noise Suppression* > Krisp.
- Solo filtra **tu** salida, no el ruido de los demás.
- Con buen micro en entorno silencioso "you may notice a decline in voice quality".

**Historial no oficial.** Hilos de la comunidad de Discord (p. ej. [Krisp not present on Linux Builds](https://support.discord.com/hc/ko/community/posts/4404507692695-Krisp-Noise-Cancellation-not-present-on-Linux-Builds),
[Bring Krisp to Linux](https://support.discord.com/hc/de/community/posts/1500000015181-Bring-Krisp-or-other-noise-reduction-to-Linux))
muestran que durante años no estuvo en Linux; comentarios dispersos dicen que llegó vía Canary/Flatpak, y otro usuario en Arch decía no verlo.
No pude abrir esos hilos (403) y solo vi extractos de búsqueda: tratarlos como *no verificado*.

**Respuesta a "¿existe/funciona?"**: según el FAQ oficial, existe en el cliente de escritorio Linux y en Chrome/Firefox.
Cuál es el comportamiento real en *este* Brave, y por qué un usuario concreto no lo ve, no se pudo confirmar con fuente primaria;
hay que probarlo en la máquina (Ajustes > Voz y vídeo).

**Estándar vs Krisp.** La guía oficial de [Voice & Video troubleshooting](https://support.discord.com/hc/en-us/articles/360045138471-Discord-Voice-and-Video-Troubleshooting-Guide)
menciona los ajustes *Auto Sensitivity*, *Noise Suppression*, *Echo Cancellation*, *Noise Reduction* y *Automatic Gain Control*
(en escritorio/móvil) y sugiere desactivar Krisp si empeora el audio. No encontré documentación oficial que defina exactamente qué hace
la opción "Estándar" (en clientes basados en WebRTC suele ser el supresor del propio motor; *inferencia, no verificada*).

**Límite estructural.** Krisp solo actúa dentro de Discord y solo sobre la voz saliente de Discord; no ayuda a otras apps. Es propietario (módulo de Krisp).

## 2. Filtro a nivel PipeWire: `filter-chain` + RNNoise / DeepFilterNet

[Docs oficiales del módulo](https://docs.pipewire.org/page_module_filter_chain.html): `libpipewire-module-filter-chain` construye un grafo con
LADSPA/LV2/etc.; usa un stream de captura (entrada) y uno de playback (salida); con `playback.props = { media.class = Audio/Source }`
aparece como **micrófono virtual**. Opciones: `node.description`, `filter.graph`, `capture.props`, `playback.props`.
Para LADSPA: `type = ladspa`, `plugin` (nombre del `.so` buscado en la ruta de plugins), `label`, `control`.
La propia doc trae un ejemplo con `ladspa/librnnoise_ladspa` y `label = noise_suppressor_stereo` (`~/.config/pipewire/filter-chain.conf.d/...`).

### 2a. RNNoise (paquete `noise-suppression-for-voice`)

- Plugin LADSPA `/usr/lib/ladspa/librnnoise_ladspa.so` (también LV2 mono/estéreo y VST) según [archlinux.org files](https://archlinux.org/packages/extra/x86_64/noise-suppression-for-voice/files/json/).
- [README upstream](https://github.com/werman/noise-suppression-for-voice#pipewire): crear `~/.config/pipewire/pipewire.conf.d/99-input-denoising.conf`
  con `libpipewire-module-filter-chain`, `label = noise_suppressor_mono`, controles `VAD Threshold (%)` (README sugiere 85-95 % en general; el ejemplo usa 50),
  `VAD Grace Period (ms)` (200), `Retroactive VAD Grace (ms)` (0, añade latencia); `capture.props` con `node.passive = true`, `audio.rate = 48000`;
  `playback.props` con `media.class = Audio/Source`. Fuente virtual: "Noise Canceling source". Reiniciar: `systemctl restart --user pipewire.service`.
- Limitaciones declaradas por upstream: solo 48 kHz; el estéreo duplica recursos (no recomendado); "Loud non-voice sounds such as keyboard clicks are only reduced when speech is present"
  (README, resumido); Chromium ignora los dispositivos *monitor*; no mejora micros malos y puede empeorar la voz.
- **Cambios recientes de PipeWire que afectan a la config** ([Arch Wiki: PipeWire](https://wiki.archlinux.org/title/PipeWire), sección "Noise suppression for voice"):
  "the instructions on GitHub are mostly usable but out of date"; desde PipeWire 1.6.3 el módulo solo busca plugins en rutas predefinidas
  ([commit](https://github.com/PipeWire/pipewire/commit/6bc07dfe0e18043aaf99f866b2c37f20e4a5e065): "Don't accept absolute library paths that are not in the search path");
  y desde 1.4.10 puede hacer falta fijar mono con `audio.channels = 1` y `audio.position = [ MONO ]` en `capture.props` y `playback.props`.
  La máquina tiene 1.6.9, así que ambas notas aplican. *(Inferencia: `/usr/lib/ladspa` está en la ruta de búsqueda por defecto, por lo que el `.so` del paquete de Arch debería ser válido; no lo probé.)*
- La Arch Wiki sugiere además `swh-plugins` para una *gate*.

### 2b. DeepFilterNet (paquete `deepfilternet-ladspa`)

- [README del plugin LADSPA](https://github.com/Rikorose/DeepFilterNet/blob/main/ladspa/README.md): "minimum latency is 20 ms (STFT processing)" más la latencia del host; ejemplos para fuente (micrófono) y sink.
- Ejemplo oficial [`deepfilter-mono-source.conf`](https://github.com/Rikorose/DeepFilterNet/blob/main/ladspa/filter-chain-configs/deepfilter-mono-source.conf):
  `label = deep_filter_mono`, control `"Attenuation Limit (dB)"` (100 = sin límite; 6-12 poca reducción, 18-24 media), `audio.rate = 48000`,
  `audio.position = [MONO]`, `capture.props.node.passive = true`, `playback.props.media.class = Audio/Source`. El ejemplo se ejecuta con
  `pipewire -c filter-chain.conf` (proceso aparte) y usa ruta absoluta `/usr/lib/ladspa/libdeep_filter_ladspa.so`.
- El paquete de Arch instala `/usr/lib/ladspa/libdeep_filter_ladspa.so` y los mismos ejemplos en `/usr/share/doc/deepfilternet-ladspa/examples/` ([files](https://archlinux.org/packages/extra/x86_64/deepfilternet-ladspa/files/json/)).
- Mantenimiento: repo con push 2026-11-06, pero el último release es v0.5.6 (2023-08-31) (`gh api`).

## 3. EasyEffects

- Aplicación Qt/Kirigami sobre PipeWire; en `extra`: `easyeffects` (web: 8.3.2-1, 2026-11-01; mi DB local de pacman mostraba 8.3.0-1, desactualizada). Depende de `rnnoise`, `speexdsp`, `webrtc-audio-processing`, `lilv`... ([archlinux.org](https://archlinux.org/packages/extra/x86_64/easyeffects/)).
  Opcionales: `calf`, `lsp-plugins-lv2`, `zam-plugins-lv2`, etc. El README upstream ([wwmm/easyeffects](https://github.com/wwmm/easyeffects)) lista RNNoise, SpeexDSP, DeepFilterNet y HushMic (DPDFNet).
- Plugins relevantes para el micro (docs en `src/contents/docs/plugins/` del repo):
  - **Noise Reduction** ([rnnoise.md](https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/plugins/rnnoise.md)): RNNoise, modelo estándar, admite modelos propios.
  - **Speech Processor** ([speex.md](https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/plugins/speex.md)): preprocesador Speex; "less computational resources" que RNNoise "at the cost of sacrificing noise suppression quality".
  - **Deep Noise Remover** ([deepfilternet.md](https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/plugins/deepfilternet.md)): "Each [model] must be installed separately" (DeepFilterNet o DPDFNet vía HushMic).
    Parámetros: Attenuation Limit, umbrales, buffer de procesamiento (más buffer = más latencia). La doc admite que algunos máximos de UI son casi inútiles (Post Filter Beta máx. 0.05 dB). *Inferencia*: `deepfilternet-ladspa` sería el candidato para proveer el modelo en Arch (el paquete `easyeffects` no depende de él); no lo verifiqué instalando.
  - También: Gate, Expander, Echo Canceller, Compressor, Equalizer, De-esser.
- Integración: procesa los streams de entrada de apps ("Process All Input Streams") y/o expone "Easy Effects Source" ([general.md](https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/user_interface/general.md)).
  "Launch Service at System Startup" lo arranca como servicio al iniciar sesión. Hay servidor local (`socat` a `$XDG_RUNTIME_DIR/EasyEffectsServer`) para cargar presets: `load_preset:input:<nombre>` ([local_server.md](https://github.com/wwmm/easyeffects/blob/master/src/contents/docs/user_interface/local_server.md)).
- Presets: ficheros JSON, comunidad en la [wiki Community presets](https://github.com/wwmm/easyeffects/wiki/Community-presets) (no la abrí). Arch Wiki avisa de un problema de Firefox con el stream del micro ([issue 957](https://github.com/wwmm/easyeffects/issues/957#issuecomment-830640221)).
- Inconvenientes: es una app con GUI y daemon; dotfiles de presets viven en `~/.config/easyeffects/` (ruta *no verificada* aquí).

## 4. NoiseTorch

- [Repo noisetorch/NoiseTorch](https://github.com/noisetorch/NoiseTorch) (README: "NoiseTorch-ng", PulseAudio o PipeWire; RNNoise). Crea "Filtered Microphone" (y "Filtered Headphones" para salida). Umbral de VAD hasta 95 %; 0 % solo atenúa sin cerrar la puerta. Latencia inherente declarada: 10 ms.
- **Mantenimiento**: último release v0.12.2 (2022-06-17); último commit 2025-01-13 (`gh api`); 70 issues abiertas. El README documenta un "suspected security breach of the update server and code repository"; auditoría comunitaria no halló código malicioso y las actualizaciones ahora salen de la página de releases.
  Necesita `setcap CAP_SYS_RESOURCE` (README) o, en AUR, `polkit`.
- Arch: **no está en repos oficiales**. AUR: `noisetorch` 0.12.2-5 (mantenedor g3tchoo, modificado 2026-08-11, 74 votos, compila con go/cmake), `noisetorch-bin` 0.12.2-1 (2022-06-21), `noisetorch-git` (huérfano, 2023-08-06) (AUR RPC). La Arch Wiki lo lista como alternativa y enlaza un servicio systemd para autoarranque.
- Depende de `pulse-native-provider` (cubierto por `pipewire-pulse`).

## 5. Evitar que Discord procese encima, y elegir el micrófono virtual

- Discord ofrece (guía oficial) *Noise Suppression*, *Echo Cancellation*, *Noise Reduction* y *Automatic Gain Control* como ajustes; apagar o fijar en "None" los que se solapan con el filtro de PipeWire es lo que la guía permite probar activando/desactivando. En web/Brave estos toggles corresponden a los *constraints* de captura del navegador (`echoCancellation`, `noiseSuppression`, `autoGainControl` de WebRTC) *(inferencia, no verificada en fuente de Discord)*.
- La combinación (filtro PipeWire + Krisp + AGC de Discord) no está documentada oficialmente; Discord solo avisa de que Krisp puede degradar calidad en micros buenos.
- Elegir el micro: en Discord, Ajustes > Voz y vídeo > Dispositivo de entrada; el filtro aparece como fuente `Audio/Source` ("Noise Canceling source", "DeepFilter Noise Canceling Source", "Filtered Microphone" o "Easy Effects Source").
  A nivel sistema: `wpctl set-default <id>` (visible en `wpctl status`). Chromium ignora fuentes *monitor* (README de noise-suppression-for-voice): la fuente virtual debe ser `Audio/Source` real, no un monitor.
- Con filter-chain el nodo `capture.props.node.passive = true` hace que solo procese mientras alguien use la fuente virtual (semántica de PipeWire; ejemplo en la doc oficial).

## 6. Ruido de teclado y ventiladores

Lo que dicen las fuentes:
- RNNoise/VAD: NoiseTorch menciona "keyboard, computer fans, trains" como objetivo; con umbral alto cierra la puerta cuando no detecta voz. El README de noise-suppression-for-voice aclara que sonidos fuertes no vocales solo se reducen cuando hay voz.
- DeepFilterNet: según README upstream, reducción mayor ("higher quality noise suppression than conventional methods" en la doc de EasyEffects). Control `Attenuation Limit`.
- Speex (EasyEffects): el más ligero pero con menos calidad (doc EasyEffects).
- Ruido de ventilador estacionario (modo Ultra al 100 %) es el caso clásico de reducción espectral; no encontré benchmark primario que compare las opciones con ventilador. *No verificado*: comparación objetiva de calidad.
- Latencia: NoiseTorch 10 ms inherentes; DeepFilterNet LADSPA ≥ 20 ms; RNNoise opera en tramas de 10 ms (inferencia desde NoiseTorch); EasyEffects añade buffer configurable en DeepFilterNet. CPU: README de DFN y EasyEffects no dan cifras; RNNoise mono es el más ligero según notas de upstream (estéreo duplica consumo). Sin medidas propias.
- Causa física: el ruido del ventilador entra por el micro; reducir RPM o distancia/ganancia actúa antes de cualquier filtro (observación, fuera del alcance de las fuentes).

## 7. Reproducibilidad en estos dotfiles (hechos del repo)

- Paquetes de `extra` (`noise-suppression-for-voice`, `deepfilternet-ladspa`, `easyeffects`) y AUR (`noisetorch`) se instalan con `yay -S --needed` si se añaden a `packages/arch-apps.txt` (comentario del archivo: "se instalan con yay (repos oficiales + AUR)").
  Alternativamente `packages/pacman-cli.txt` (CLI) — no inspeccioné su semántica exacta.
- Config de filter-chain: un paquete Stow nuevo, p. ej. `pipewire/.config/pipewire/pipewire.conf.d/99-input-denoising.conf`, añadido a `STOW_PACKAGES` en `scripts/modules/stow.sh` (CLAUDE.md, "Añadir un paquete Stow nuevo"). `~/.config/pipewire/` hoy no existe, así que no hay conflicto con ficheros reales.
  El bootstrap usa `--no-folding`, de modo que enlaza el fichero, no el directorio.
- Hay precedente de conf de WirePlumber en `~/.config/wireplumber/wireplumber.conf.d/` (fuera de este repo según lo observado; no verifiqué si otro paquete Stow lo gestiona).
- EasyEffects: presets JSON como paquete Stow + autoarranque (opción de servicio de la app o `exec-once` de Hyprland; no verificado cómo gestiona Omarchy sus autostarts).
- NoiseTorch: el estado (módulo cargado) no es declarativo; autoarranque vía systemd unit (wiki de NoiseTorch).

## 8. Discord: cómo está instalado hoy y alternativas de cliente

- Hoy: webapp de Omarchy en Brave (ver §0). Krisp en navegador: FAQ dice Chrome/Firefox (§1).
- Repos: `extra/discord 1:1.0.164-1` (pacman -Si; cliente oficial Electron).
- AUR (RPC, 2026-11-08): `vesktop` 1.6.9-1 (2026-11-06), `vesktop-bin` 1.6.9-1 (2026-11-05, 171 votos), `equibop-bin` 3.3.2-1 (2026-10-23), `webcord` 4.14.0-1 (2026-07-12). Vesktop es cliente de terceros con Vencord (describe "improved Linux support"); se debe verificar su política de Krisp (no verificado).
- Un cliente de terceros distinto del oficial no tiene garantía de Krisp; Discord documenta Krisp para sus propios clientes.

## 9. Tabla comparativa

| Opción | Paquete exacto (verificado) | Motor | Alcance | Mantenimiento | Declarativo en dotfiles | Riesgos |
|---|---|---|---|---|---|---|
| Krisp de Discord | (ninguno; integrado) | Krisp (propietario, local) | Solo Discord | Oficial Discord; FAQ 2025-03-25 | Sí (nada que instalar; ajuste manual) | Se desactiva con CPU alta; no verificado en Brave |
| filter-chain + RNNoise | `noise-suppression-for-voice` (extra, 1.22-1 en web, 2026-10-26) | RNNoise + VAD | Todo el sistema (fuente virtual) | Upstream: commit 2026-10-25, último release en GitHub v1.10 pero tags v1.22 | Stow `pipewire/.config/pipewire/pipewire.conf.d/*.conf` + pacman | Cambios de PipeWire 1.4.10/1.6.3 (mono, rutas); solo 48 kHz; VAD puede cortar voz |
| filter-chain + DeepFilterNet | `deepfilternet-ladspa` (extra, 0.5.6-1, 2026-10-06) | DeepFilterNet | Todo el sistema | Upstream: push 2026-11-06, release v0.5.6 (2023) | Igual que arriba | Latencia ≥20 ms; más CPU (sin cifras); ruta absoluta del ejemplo puede chocar con regla de 1.6.3 |
| EasyEffects | `easyeffects` (extra, 8.3.2-1, 2026-11-01) | RNNoise, Speex, DeepFilterNet (aparte), +EQ, gate, etc. | Todo el sistema (micro y salida) | Muy activo (push 2026-11-07) | Stow de presets + paquete; autoarranque como servicio | Daemon+GUI; DFN requiere paquete aparte; issue Firefox/micro |
| NoiseTorch | `noisetorch` (AUR 0.12.2-5, 2026-08-11); `-bin` (2022), `-git` (huérfano) | RNNoise | Todo el sistema | Último release 2022-06, último commit 2025-01; incidente de seguridad (auditado) | Parcial (AUR + unidad systemd; carga no declarativa) | setcap/polkit, AUR, mantenimiento mínimo |

## 10. Preguntas abiertas

1. ¿Krisp aparece de verdad en Discord web dentro de Brave? El FAQ cita Chrome/Firefox; Brave no está confirmado. Probarlo antes de comparar.
2. ¿Qué hace exactamente "Estándar" frente a Krisp y se apila con el filtro de PipeWire? No hay documentación oficial.
3. ¿Qué calidad real tienen RNNoise vs DeepFilterNet con el ruido del ventilador a 100 %? No hay benchmark primario; requiere prueba propia con la Fifine.
4. ¿Cuánta CPU y latencia añaden en esta máquina? Solo hay cifras de latencia mínima (10 ms NoiseTorch, 20 ms DFN), ninguna de CPU.
5. ¿Funciona el `.so` de `deepfilternet-ladspa` en `filter-chain` con PipeWire 1.6.9 con ruta absoluta, o hay que usar nombre relativo? La regla de 1.6.3 rechaza rutas absolutas fuera de la ruta de búsqueda; `/usr/lib/ladspa` debería estar dentro, no probado.
6. ¿`easyeffects` 8.3.x carga el modelo de `deepfilternet-ladspa` de Arch? La doc dice que debe instalarse aparte; el empaquetado de Arch no lo declara como dependencia.
7. ¿Dónde declarar estos paquetes: `arch-apps.txt` (GUI/AUR) o un manifiesto nuevo? Y cómo arrancar EasyEffects/filter-chain en Omarchy (servicio de usuario vs `exec-once`).
8. ¿Se prefiere seguir con la webapp o pasar a `discord` (extra) / `vesktop` (AUR)? Afecta a Krisp, a `--user-data-dir` del patrón de webapps y a la lista de paquetes.
9. Los detalles de Anubis en archlinux.org (AUR web, wiki directa) bloquearon WebFetch; usé la API JSON de la wiki, la RPC de AUR y la API de paquetes de archlinux.org.

## Fuentes

- https://docs.pipewire.org/page_module_filter_chain.html
- https://wiki.archlinux.org/title/PipeWire (vía API de MediaWiki)
- https://github.com/werman/noise-suppression-for-voice
- https://github.com/Rikorose/DeepFilterNet (ladspa/README.md, filter-chain-configs)
- https://github.com/wwmm/easyeffects (README y docs)
- https://github.com/noisetorch/NoiseTorch
- https://support.discord.com/hc/en-us/articles/360040843952-Krisp-FAQ
- https://support.discord.com/hc/en-us/articles/360045138471-Discord-Voice-and-Video-Troubleshooting-Guide
- https://archlinux.org/packages/ (extra: easyeffects, noise-suppression-for-voice, deepfilternet-ladspa, rnnoise, discord)
- https://aur.archlinux.org/rpc/ (noisetorch*, vesktop*, equibop-bin, webcord, deepfilternet-*)
