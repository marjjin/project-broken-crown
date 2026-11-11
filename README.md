# Project Broken Crown

RPG de acción 3D en tercera persona, ambientado en un mundo medieval de fantasía oscura.

**Plataforma objetivo: escritorio (Windows; Steam a futuro).** La versión web quedó descartada.

**Fase actual: 3 — IA de enemigos.** El **Soldado Corrompido** patrulla, detecta al jugador por vista (con paredes que bloquean), lo persigue con navegación 3D, ataca, recibe daño y muere. Se suma al combate de la fase 2 (espada, combo, ataque fuerte, esquiva, vida y stamina). Todavía no hay jefes, inventario, misiones ni persistencia.

Documentación técnica: [docs/COMBAT.md](docs/COMBAT.md) (combate) · [docs/ENEMIES.md](docs/ENEMIES.md) (enemigos e IA).

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Motor | **Godot 4.7.2 stable**, edición estándar (GDScript, *no* la edición .NET/C#) |
| Versión mínima esperada | Godot 4.4 (el código usa API estable desde 4.3; no se probó en versiones anteriores) |
| Plantillas de exportación | Solo para generar el `.exe`: plantilla **Windows x86_64** |
| Plugins externos | Ninguno |

Descarga oficial de Godot: <https://godotengine.org/download>

## Abrir y ejecutar

1. Abrí Godot y en el Project Manager elegí **Import** → seleccioná el archivo `project.godot` de esta carpeta.
2. La primera apertura reimporta los recursos (se crea la carpeta `.godot/`, que no se versiona).
3. Presioná **F5** (Run Project). La escena principal es `res://scenes/main/main.tscn`.

Desde la línea de comandos:

```bash
godot --path . # abre el juego directamente
godot --path . -e # abre el editor
```

## Controles

| Acción | Teclado / Mouse | Gamepad |
|---|---|---|
| Moverse | W A S D | Stick izquierdo |
| Cámara | Mouse (con el cursor capturado) | Stick derecho |
| Correr | Shift (mantener) | L3 (clic del stick izquierdo) |
| Saltar | Espacio | A / Cruz |
| Ataque ligero (combo de 3) | Clic izquierdo | RB / R1 |
| Ataque fuerte (30 stamina) | Clic derecho | RT / R2 |
| Esquiva (20 stamina) | Ctrl | B / Círculo |
| Liberar el mouse | Esc | — |
| Capturar el mouse | Clic izquierdo | — |
| Depuración de enemigos (mostrar/ocultar) | F3 | — |

Las teclas usan *physical keycodes*: WASD queda en la misma posición física con distribuciones AZERTY/QWERTZ.

El salto se desactiva sin tocar código: abrí `resources/player/default_movement_settings.tres` y desmarcá **Jump Enabled**.

- **Combo:** volvé a hacer clic durante el golpe para encadenar; el tercero hace más daño.
- **Esquiva:** con dirección, ruedas hacia ella; sin dirección, das un paso atrás.
- **Orientación:** el personaje siempre mira hacia donde apunta la cámara. W avanza, S retrocede, A/D se desplazan de costado, y los golpes salen hacia adelante de la cámara. Para volver al modo anterior (el personaje gira hacia donde camina), desmarcá **Face Camera Direction** en `resources/player/default_movement_settings.tres`.
- **Moverse atacando:** podés caminar y correr libremente mientras golpeás (configurable por arma con `attack_move_speed_multiplier`); el salto se bloquea hasta el final del golpe.
- **Clic para capturar:** el clic que captura el mouse no dispara un ataque.

### En el nivel

- **Maniquíes:** frente al punto de inicio. Muestran su vida y reaparecen a los 4 s, salvo el más lejano, que queda caído.
- **Trampa de prueba** (al sudeste, placa roja con postes): se ilumina en naranja y después daña 15 puntos cada 2,5 s. Sirve para probar la invulnerabilidad: esquivá justo cuando se pone roja.
- **Muerte:** si tu vida llega a 0, reaparecés a los 3 s.

Los ajustes del combate están en `resources/weapons/royal_guard_sword.tres` y `resources/player/default_action_settings.tres`. Ver [docs/COMBAT.md](docs/COMBAT.md).

### Arena de enemigos (fase 3)

La IA se prueba en una escena aparte, para no tocar el nivel principal: **`scenes/test/enemy_test_arena.tscn`**. Abrila desde el panel *Sistema de archivos* y presioná **F6** (*Ejecutar escena actual*). **F5** sigue abriendo el nivel principal.

- **Al empezar:** aparecés al sur, detrás de un muro. El Soldado Corrompido patrulla un rectángulo de cuatro puntos al norte.
- **Detección:** con la depuración (F3) ves sobre él su estado y su vida, el círculo de detección, los bordes de su campo de visión y la ruta de navegación en celeste. No te ve a través de los muros ni por la espalda, salvo que estés muy cerca.
- **Combate:** levanta la espada (preparación), golpea y se recupera. Esquivá justo cuando baja la espada para evitar el daño con la invulnerabilidad. Tus golpes lo aturden; después de un aturdimiento tiene unos instantes de inmunidad.
- **Perder la persecución:** corré (Shift), alejate o escondete detrás de un muro. A los 3 s sin verte vuelve a su patrulla.
- **Plataforma baja** (noroeste): podés subir saltando, él no. Se queda en el borde mirándote.
- **Datos del soldado:** `resources/enemies/corrupted_soldier.tres`. Ver [docs/ENEMIES.md](docs/ENEMIES.md).

## Estructura

```
project.godot                 Configuración (renderizador Compatibility, capas físicas, autoload)
export_presets.cfg            Preset de exportación Windows Desktop (más un preset Web sin uso)
scenes/
  main/main.tscn              Nivel de prueba: suelo, luz, paredes, rampa, escalones, pilares, túnel
  player/player.tscn          Personaje (CharacterBody3D + cápsula + CameraRig instanciado)
  camera/camera_rig.tscn      Rig de cámara: Yaw → PitchPivot → SpringArm3D → Camera3D
  level/box_obstacle.tscn     Caja estática reutilizable
  combat/training_dummy.tscn  Maniquí de entrenamiento
  combat/damage_pulse_trap.tscn  Trampa de prueba (daño periódico)
  ui/hud.tscn                 HUD mínimo (controles + estado)
  ui/combat_hud.tscn          Barras de vida/stamina y estado de acción
  enemies/corrupted_soldier.tscn  Soldado Corrompido (primer enemigo)
  level/test_environment.tscn Cielo + sol reutilizables para escenas de prueba
  test/enemy_test_arena.tscn  Arena de IA: navmesh, patrulla, muros de cobertura, plataforma
scripts/
  enemies/                    EnemyData, EnemyCharacter, EnemyPerception, EnemyNavigator,
                              EnemyMeleeAttack, EnemyBrain, EnemyDebugView
  level/runtime_navigation_region.gd  Genera el navmesh al cargar el nivel
  combat/                     Vida, stamina, hitbox, hurtbox, DamageInfo, WeaponData, PlayerActionSettings
  animation/                  Interfaz ActionAnimator + animaciones provisionales con Tweens
  player/player_action_controller.gd  Máquina de estados de combate
  level/training_dummy.gd, level/damage_pulse_trap.gd
  ui/combat_hud.gd
  core/input_actions.gd       Nombres de acciones como constantes (evita strings repetidos)
  core/input_bindings.gd      Autoload: registra los bindings de teclado y gamepad por defecto
  core/mouse_capture_controller.gd  Captura/liberación del cursor
  player/player_controller.gd Locomoción: gravedad, aceleración, carrera, salto, giro suave
  player/movement_settings.gd Resource con todos los parámetros ajustables
  camera/third_person_camera.gd  Rotación de cámara (mouse y stick) con límites de pitch
  level/box_obstacle.gd       Genera malla + colisión a partir de un único `size`
  ui/hud.gd                   Actualiza el HUD 4 veces por segundo
resources/
  player/default_movement_settings.tres
  player/default_action_settings.tres   Esquiva, aturdimiento, respawn
  weapons/royal_guard_sword.tres        Espada de la Guardia Real
  enemies/corrupted_soldier.tres        Estadísticas del Soldado Corrompido
  materials/grid_ground.tres
assets/shaders/grid_ground.gdshader  Grilla procedural del suelo (sin texturas)
tests/combat_tests.gd         Pruebas automatizadas fases 1-2 (headless)
tests/enemy_tests.gd          Pruebas automatizadas fase 3 (headless)
docs/COMBAT.md                Documentación técnica del combate
docs/ENEMIES.md               Documentación técnica de enemigos e IA
```

### Decisiones de diseño

- **Jugador y cámara desacoplados.** `PlayerController` solo conoce un `Node3D` cuya orientación define "adelante" (`orientation_reference`). No sabe que es una cámara. La cámara no sabe nada del jugador.
- **El cuerpo del jugador no rota.** Solo gira el nodo `Visual`. Así el rig de cámara puede ser hijo del jugador (hereda la posición, no la orientación) y la cápsula de colisión es estable.
- **La cámara no atraviesa paredes** porque `SpringArm3D` lanza una esfera (radio 0,25 m) contra la capa física `world`. El jugador está en la capa `player`, así que el brazo nunca choca con su propio personaje.
- **Parámetros en un Resource** (`MovementSettings`). Se pueden crear variantes (por ejemplo, para otros personajes) sin tocar código.
- **Bindings en código, no en `project.godot`.** Son legibles, fáciles de comparar en el control de versiones y van a servir de base para un menú de reasignación. Si una acción ya está definida en *Project Settings → Input Map*, el autoload la respeta y no la pisa.
- **`BoxObstacle`** (`@tool`) mantiene sincronizadas la malla y la colisión. Sus nodos hijos son internos: no se guardan en la escena ni se duplican al copiar el nodo.

- **Combate por composición:** los componentes de vida, stamina, hitbox y hurtbox son nodos independientes, reutilizables por enemigos y jefes. El combate controla al jugador solo mediante una API pequeña de `PlayerController` (bloquear input y forzar la velocidad horizontal), sin reescribir la locomoción.
- **IA separada en piezas:** el enemigo tiene datos (`EnemyData`), cuerpo, percepción, navegación, ataque y cerebro como nodos distintos. El cerebro decide y los demás ejecutan. El enemigo reutiliza el mismo sistema de daño que el jugador, así que la esquiva lo evita sin código extra. Encuentra al jugador por el grupo `player`, sin rutas de escena rígidas.

### Capas físicas

| Capa | Nombre | Uso |
|---|---|---|
| 1 | `world` | Escenario estático; la máscara del SpringArm3D |
| 2 | `player` | Cápsula del jugador |
| 3 | `player_hurtbox` | Zona dañable del jugador |
| 4 | `enemy_hurtbox` | Zona dañable de maniquíes y enemigos |
| 5 | `enemy` | Cuerpo físico de los enemigos (el jugador choca con ellos) |

## Renderizado

El renderizador actual es **Compatibility** (OpenGL 3.3), que se eligió cuando la web era un objetivo. Funciona bien en escritorio y en hardware modesto. Ahora que el objetivo es solo escritorio, se puede pasar a **Forward+** (Vulkan/D3D12) cuando se quieran gráficos más avanzados, como SSAO, glow, niebla volumétrica o muchas luces. Es un cambio de configuración, pero conviene hacerlo en una fase dedicada a lo visual.

## Exportación para Windows (verificada)

1. Instalá la plantilla **Windows x86_64**: *Editor → Administrar Plantillas de Exportación* → *Conectarse* → elegí un mirror → marcá *Windows x86_64* → instalar.
2. *Proyecto → Exportar…* → preset **Windows Desktop** (ya incluido, con PCK embebido) → **Exportar Proyecto** → `build/windows/BrokenCrown.exe`.
3. Ejecutá `BrokenCrown.exe`. Si exportaste con depuración, también se genera `BrokenCrown.console.exe`, que abre una consola con los errores.

Windows SmartScreen puede advertir porque el ejecutable no está firmado ("Más información → Ejecutar de todas formas").

## Pruebas automatizadas

```bash
godot --headless --path . --script res://tests/combat_tests.gd   # fases 1-2: 48 comprobaciones
godot --headless --path . --script res://tests/enemy_tests.gd    # fase 3: 52 comprobaciones
```

Las dos suites cargan las escenas reales: el nivel principal y la arena de enemigos. El código de salida es la cantidad de fallas. La suite de enemigos tarda alrededor de un minuto porque espera recorridos de patrulla reales.

## Checklist de la fase 3 (manual, en la arena con F6)

- [ ] El Soldado Corrompido aparece y patrulla entre los cuatro puntos, esperando en cada uno.
- [ ] Te detecta si entrás en su campo de visión (el texto dice "VE AL JUGADOR" y pasa a `Chase`).
- [ ] No te detecta detrás del muro central ni por la espalda (salvo muy cerca).
- [ ] Te persigue rodeando los muros (la línea celeste muestra la ruta).
- [ ] No atraviesa muros ni obstáculos.
- [ ] Si te escondés o te alejás corriendo, deja de perseguirte (`Return`) y vuelve a su patrulla.
- [ ] A distancia corta levanta la espada y ataca, y tu barra de vida baja.
- [ ] Si esquivás justo cuando baja la espada, aparece "Golpe evitado (invulnerable)".
- [ ] Tus ataques le bajan la vida (la ves en su etiqueta) y lo aturden.
- [ ] Al llegar a 0 cae, deja de atacar y a los 6 s desaparece.
- [ ] El nivel principal (F5) sigue funcionando como en las fases 1 y 2.
- [ ] No aparecen errores en el panel Salida/Depurador.

## Checklist de la fase 2 (manual)

- [ ] El personaje sigue moviéndose correctamente (fase 1 intacta).
- [ ] El clic izquierdo ejecuta ataques ligeros y el combo llega al tercer golpe (el HUD muestra `Ataque ligero 3/3`).
- [ ] El clic derecho ejecuta un ataque fuerte y la barra verde baja.
- [ ] Sin stamina suficiente, el ataque fuerte no sale y aparece "Stamina insuficiente".
- [ ] La stamina se regenera unos instantes después de gastarla.
- [ ] Ctrl ejecuta una esquiva que gasta stamina y no atraviesa paredes.
- [ ] Esquivando sobre la trampa justo en el pulso, aparece "Golpe evitado (invulnerable)".
- [ ] El maniquí muestra el daño, reacciona, cae al llegar a 0 y reaparece.
- [ ] Las barras de vida y stamina se actualizan.
- [ ] No aparecen errores en el panel Salida/Depurador.

## Checklist de aceptación de la fase 1 (en el editor)

- [ ] F5 inicia sin errores en el panel *Output* / *Debugger*.
- [ ] W/A/S/D mueven al personaje relativo a la cámara.
- [ ] El mouse gira la cámara. El pitch está limitado (no da la vuelta).
- [ ] Shift aumenta la velocidad (el HUD muestra `Corriendo: si`).
- [ ] Espacio salta. Los escalones al oeste (`JumpSteps`) requieren saltar.
- [ ] Al soltar las teclas, el personaje desacelera en lugar de frenar en seco.
- [ ] El personaje mira hacia donde apunta la cámara: S camina hacia atrás y A/D se desplazan de costado sin darse vuelta.
- [ ] Choca y se desliza contra paredes, pilares, cajas y el muro en ángulo.
- [ ] Sube la rampa (al este) hasta la plataforma.
- [ ] Al acercar la cámara a un pilar o entrar al túnel (sudoeste), la cámara se acorta y no atraviesa la geometría.
- [ ] Esc libera el cursor y un clic lo recaptura.
- [ ] Con un gamepad conectado, los sticks mueven al personaje y la cámara.

## Limitaciones conocidas

- **Validación:** la fase 1 se probó en Godot 4.7.2, tanto en el editor como en el build de Windows (AMD Radeon RX 6600, Compatibility). La fase 2 fue verificada jugando. La fase 3 pasa sus 52 pruebas automatizadas headless, pero falta probarla jugando.
- **Micro-stutter en monitores de más de 60 Hz:** el personaje se mueve en `_physics_process` (60 Hz) y no está activada la interpolación física. Esto se va a resolver en una fase posterior, cuando se defina el sistema de cámara definitivo.
- **Sin escalones automáticos:** `CharacterBody3D` no sube escalones por sí solo. Los desniveles de más de unos 10 cm requieren saltar (es intencional en el nivel de prueba).
- **Gamepad:** el mapeo usa la convención SDL (A = botón inferior). Los mandos no reconocidos pueden tener los ejes cambiados.
- **Proyecto dentro de OneDrive:** la sincronización puede bloquear archivos de `.godot/` durante la importación y provocar errores intermitentes. Se recomienda pausar OneDrive mientras trabajás, o mover el proyecto fuera de la carpeta sincronizada.
- **Animaciones provisionales:** son Tweens sobre primitivas. Los tiempos de golpe e invulnerabilidad dependen de los datos y no de la animación, así que lo visual puede no coincidir perfectamente con la ventana real de impacto.
- **Hitbox rectangular:** el golpe usa una caja frente al personaje durante la ventana activa, no sigue el arco de la espada.
- **Ataques solo en el suelo:** no hay ataques ni esquivas en el aire.
- **Trampa de prueba:** existe solo para probar daño e invulnerabilidad; no es contenido final.
- **Un solo enemigo y sin evasión entre agentes:** la evasión de `NavigationAgent3D` está desactivada. Varios enemigos se empujan físicamente, pero no se esquivan con inteligencia. Conviene activarla cuando haya grupos de enemigos.
- **El enemigo no reaparece:** el cuerpo desaparece a los 6 s. Las reapariciones (por ejemplo, al descansar) quedan para una fase posterior.
- **Navmesh generado al cargar:** es ideal para la arena de prueba. En niveles grandes conviene generarlo en el editor y desactivar `bake_on_ready`.
- **El enemigo no salta ni trepa:** se queda en el borde de cualquier desnivel de más de 25 cm.
- **El nivel principal no tiene enemigos:** viven en la arena de prueba, porque el nivel principal no tiene región de navegación.
