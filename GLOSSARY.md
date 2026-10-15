# Motor de decisiones local

Delegar decisiones cerradas y baratas de Claude Code a un modelo "Sistema 1" local (Clef-Flash), en vez de
gastarlas en el modelo grande.

## Language

**Decisión**:
Una pregunta con respuesta cerrada (elegir de una lista fija, sí/no o escala) que se resuelve sin
generar texto libre.
_Avoid_: clasificación, routing (como sustantivo genérico)

**Motor de decisiones**:
El servicio local que resuelve Decisiones; hoy, Clef-Flash.
_Avoid_: router, clasificador, Jev, Laya

**Fallo abierto**:
Cuando el Motor no responde a tiempo o no está disponible, Claude Code sigue con su comportamiento
por defecto como si el Motor no existiera.
_Avoid_: fallback

**Respaldo**:
El motor secundario (Haiku 5.5) que decide cuando la confianza del Motor de decisiones no llega al umbral.
_Avoid_: Maestro, fallback

**Caso en reserva**:
Un caso de uso del Motor que se documenta como mejora posible pero no se construye en este esfuerzo.
_Avoid_: caso en sombra (choca con Modo sombra)

**Modo sombra**:
El Motor decide y se registra su respuesta, pero Claude Code no la aplica.
