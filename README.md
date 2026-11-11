# Project Broken Crown

RPG de acción 3D en tercera persona, ambientado en un mundo medieval de fantasía oscura. Un antiguo miembro de la Guardia Real despierta en su propia tumba más de cien años después de haber sido traicionado por el rey.

**Plataforma objetivo: escritorio (Windows; Steam a futuro).** La versión web quedó descartada.

**Fase actual: 4 — Primer nivel, "El Despertar".** Es un nivel 3D explorable de seis sectores: cripta, catacumbas, cámara del Guardián y salida al exterior con vista a la Aldea Devastada. Incluye puertas, inscripciones, un coleccionable, una ruta secundaria, el checkpoint de la estatua de la Guardia Real, cuatro Soldados Corrompidos y ambientación con Forward+.

Se apoya en las fases anteriores:
- **Fase 1:** movimiento y cámara.
- **Fase 2:** combate, con espada, combo, ataque fuerte, esquiva, vida y stamina.
- **Fase 3:** IA de enemigos.

**Recursos 3D:** las paredes, los pisos y los techos usan texturas PBR, y el nivel incluye puertas dobles, una reja, braseros, escudos, estoques y rocas reales. Todo proviene de Poly Haven bajo licencia CC0 (ver [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md)).

Todavía no hay miniboss, inventario, misiones ni guardado en disco.

Documentación técnica:
- [docs/COMBAT.md](docs/COMBAT.md): combate.
- [docs/ENEMIES.md](docs/ENEMIES.md): enemigos e IA.
- [docs/LEVEL_THE_AWAKENING.md](docs/LEVEL_THE_AWAKENING.md): el nivel.
- [docs/INTERACTION.md](docs/INTERACTION.md): interacción, puertas, checkpoint y sesión.
- [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md): recursos externos (CC0) y sus licencias.

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Motor | **Godot 4.7.2 stable**, edición estándar (GDScript, *no* la edición .NET/C#) |
| GPU | Compatible con **Vulkan** o **Direct3D 12** (renderizador Forward+) |
| Plantillas de exportación | Solo para generar el `.exe`: plantilla **Windows x86_64** |
| Plugins externos | Ninguno |

Descarga oficial de Godot: <https://godotengine.org/download>

## Abrir y ejecutar

1. Abrí Godot y en el Project Manager elegí **Import** → seleccioná el archivo `project.godot` de esta carpeta.
2. Presioná **F5**. La escena principal es **El Despertar** (`res://scenes/levels/the_awakening/the_awakening.tscn`).
3. Otras escenas, abriéndolas y presionando **F6**:
   - `scenes/main/main.tscn`: campo de pruebas de movimiento y combate, con maniquíes y trampa (fases 1-2).
   - `scenes/test/enemy_test_arena.tscn`: arena de IA (fase 3).

## Controles

| Acción | Teclado / Mouse | Gamepad |
|---|---|---|
| Moverse | W A S D | Stick izquierdo |
| Cámara | Mouse (con el cursor capturado) | Stick derecho |
| Correr | Shift (mantener) | L3 |
| Saltar | Espacio | A / Cruz |
| Ataque ligero (combo de 3) | Clic izquierdo | RB / R1 |
| Ataque fuerte (30 stamina) | Clic derecho | RT / R2 |
| Esquiva (20 stamina) | Ctrl | B / Círculo |
| **Interactuar** (puertas, estatua, inscripciones, objetos) | **E** | X / Cuadrado |
| Mostrar/ocultar la ayuda de controles | F1 | — |
| Depuración de enemigos | F3 | — |
| Liberar / capturar el mouse | Esc / Clic izquierdo | — |

- **Orientación:** el personaje mira hacia donde apunta la cámara. W avanza, S retrocede, A/D se desplazan de costado, y los golpes salen hacia adelante. Se puede volver al modo anterior desmarcando **Face Camera Direction** en `resources/player/default_movement_settings.tres`.
- **Moverse atacando:** el movimiento es libre durante los golpes (`attack_move_speed_multiplier` del arma). El salto se bloquea hasta que termina el golpe.
- **Combo:** volvé a hacer clic durante el golpe. **Esquiva:** con dirección, ruedas hacia ella; sin dirección, das un paso atrás.

## El Despertar (resumen)

| Sector | Qué hay |
|---|---|
| A — Cámara funeraria | Inicio junto al sarcófago, lápida legible y puerta a la cripta |
| B — Pasillos de la cripta | Primer Soldado Corrompido e inscripción del juramento |
| C — Sala de la Guardia | **Estatua = checkpoint** (descansar con E). Sala segura, entre dos puertas |
| D — Catacumbas | 3 soldados. **Ruta secundaria:** saltá los escombros del pasillo este hasta la cripta oculta, con el **Medallón de la Guardia** y un altar de armas vacío |
| E — Cámara del Guardián | Arena vacía (reservada para un futuro miniboss) |
| F — Salida | Rampa ascendente hasta una terraza exterior con vista a la Aldea Devastada. Llegar ahí completa el nivel |

Al morir reaparecés a los 3 s en la última estatua activada, o en la tumba si no activaste ninguna. Ver [docs/LEVEL_THE_AWAKENING.md](docs/LEVEL_THE_AWAKENING.md) para el mapa y los detalles.

## Estructura

```
project.godot                 Configuración (Forward+, capas físicas, autoloads InputBindings y GameSession)
export_presets.cfg            Preset de exportación Windows Desktop (más un preset Web sin uso)
scenes/
  levels/the_awakening/       El Despertar: escena del nivel, 6 sectores, entorno y vista de la aldea
  level/                      BoxObstacle, CryptRoom (generador de salas), entorno de pruebas
  props/                      Pilar, antorcha, casa en ruinas, brasero, restos de la Guardia, escombros
  interaction/                Puerta, estatua-checkpoint, inscripción, altar de armas, medallón
  player/player.tscn          Personaje (movimiento, combate, interactor, cámara)
  camera/camera_rig.tscn      Rig de cámara: Yaw → PitchPivot → SpringArm3D → Camera3D
  enemies/corrupted_soldier.tscn  Soldado Corrompido
  combat/                     Maniquí de entrenamiento y trampa de prueba
  ui/                         HUD de ayuda (F1), HUD de combate y HUD de nivel (indicaciones + carteles)
  main/main.tscn              Campo de pruebas de las fases 1-2
  test/enemy_test_arena.tscn  Arena de IA de la fase 3
scripts/
  core/                       InputActions, InputBindings (autoload), GameSession (autoload), captura del mouse
  player/                     PlayerController, MovementSettings, PlayerActionController
  camera/                     ThirdPersonCamera
  combat/                     Vida, stamina, hitbox, hurtbox, DamageInfo, WeaponData, PlayerActionSettings
  animation/                  ActionAnimator + animaciones provisionales con Tweens
  enemies/                    EnemyData, EnemyCharacter, EnemyPerception, EnemyNavigator,
                              EnemyMeleeAttack, EnemyBrain, EnemyDebugView
  interaction/                Interactable, PlayerInteractor, Door, Checkpoint, Inscription, Collectible
  levels/                     LevelController, LevelExit
  level/                      BoxObstacle, CryptRoom, RuntimeNavigationRegion, TorchFlicker, maniquí, trampa
  ui/                         Hud, CombatHud, LevelHud
resources/                    Ajustes del jugador, arma, enemigo y materiales compartidos (piedra PBR)
assets/third_party/polyhaven/  Texturas y modelos CC0 descargados (1K)
tools/fetch_polyhaven_assets.sh  Vuelve a descargar esos recursos
tests/                        combat_tests.gd, enemy_tests.gd, level_tests.gd (headless)
docs/                         COMBAT.md, ENEMIES.md, LEVEL_THE_AWAKENING.md, INTERACTION.md
```

### Decisiones de diseño

- **Jugador y cámara desacoplados.** `PlayerController` solo conoce el `Node3D` que define "adelante". El cuerpo nunca rota; solo gira el nodo `Visual`.
- **La cámara no atraviesa paredes:** el `SpringArm3D` colisiona contra la capa `world`.
- **Parámetros en archivos de datos:** movimiento, arma, acciones y enemigo se ajustan sin tocar código.
- **Combate por composición:** vida, stamina, hitbox y hurtbox son nodos reutilizados por el jugador, los enemigos y la trampa. El combate controla al jugador solo mediante una API pequeña de `PlayerController`.
- **IA separada en piezas:** datos, cuerpo, percepción, navegación, ataque y cerebro. El enemigo usa el mismo sistema de daño, así que la esquiva lo evita sin código extra.
- **Interacción con un único contrato:** `Interactable`, más un `PlayerInteractor` en el jugador. Puertas, estatua, inscripciones y coleccionable solo reaccionan a la señal `interacted`.
- **Eventos de nivel por `GameSession`:** los objetos anuncian lo que pasa y la interfaz escucha. Ningún objeto del juego conoce al HUD.
- **Geometría generada y reemplazable:** las salas son `CryptRoom` (tamaño + aberturas). Se pueden cambiar por modelos sin tocar la lógica.

### Capas físicas

| Capa | Nombre | Uso |
|---|---|---|
| 1 | `world` | Escenario estático y hojas de puertas; la máscara del SpringArm3D y del navmesh |
| 2 | `player` | Cápsula del jugador |
| 3 | `player_hurtbox` | Zona dañable del jugador |
| 4 | `enemy_hurtbox` | Zona dañable de maniquíes y enemigos |
| 5 | `enemy` | Cuerpo físico de los enemigos |
| 6 | `interactable` | Áreas de interacción (`Interactable`) |

## Renderizado

**Forward+** (Vulkan/D3D12) desde la fase 4. El Despertar usa:
- niebla volumétrica tenue y niebla de distancia,
- SSAO, glow y tonemapping AgX,
- antorchas sin sombras con parpadeo por Tween,
- una única luz puntual con sombras (la estatua),
- luna direccional para el exterior.

Las escenas de prueba siguen funcionando con este renderizador.

Si alguna vez hiciera falta volver a **Compatibility** para hardware viejo: *Proyecto → Configuración del Proyecto → Renderizado → Renderer*. La niebla volumétrica no existe en ese modo.

## Exportación para Windows (verificada en fase 1)

1. Instalá la plantilla **Windows x86_64**: *Editor → Administrar Plantillas de Exportación*.
2. *Proyecto → Exportar…* → preset **Windows Desktop** → **Exportar Proyecto** → `build/windows/BrokenCrown.exe`.
3. Ejecutá `BrokenCrown.exe`, o `BrokenCrown.console.exe` si exportaste con depuración.

## Pruebas automatizadas

```bash
godot --headless --path . --script res://tests/combat_tests.gd   # fases 1-2: 48 comprobaciones
godot --headless --path . --script res://tests/enemy_tests.gd    # fase 3:   53 comprobaciones
godot --headless --path . --script res://tests/level_tests.gd    # fase 4:   88 comprobaciones (incluye recursos)
```

Cada suite carga escenas reales y devuelve como código de salida la cantidad de fallas. Las suites de enemigos y del nivel tardan entre uno y dos minutos porque esperan recorridos reales.

**Lo que las pruebas no cubren:** el aspecto visual (iluminación, niebla, legibilidad) y la sensación de juego. Eso requiere probar jugando.

## Checklist de la fase 4 (manual, F5)

- [ ] El nivel carga sin errores y aparecés junto al sarcófago, en la cámara funeraria.
- [ ] La lápida se lee con E. La puerta de la cámara se abre con E y no se puede atravesar cerrada.
- [ ] La cámara se comporta bien en los pasillos (se acorta contra las paredes).
- [ ] El primer soldado patrulla el salón B2, te detecta y te persigue (también a través de una puerta abierta).
- [ ] El combate funciona igual que en las fases 2 y 3.
- [ ] La Sala de la Guardia es segura (dos puertas). La estatua muestra "[E] Descansar".
- [ ] Descansar recupera vida y stamina, muestra "Punto de descanso" y la estatua se ilumina en dorado.
- [ ] Al morir reaparecés frente a la estatua, mirando hacia la sala, y todo funciona.
- [ ] En las catacumbas hay 3 soldados (uno hace guardia sin moverse).
- [ ] La ruta secundaria (pasillo este del osario) se pasa saltando los escombros. Ahí están el medallón (E para recogerlo) y el altar de armas.
- [ ] La Cámara del Guardián está vacía, con antorchas rojas.
- [ ] La rampa lleva a la terraza. Al llegar aparece el mensaje final y se ve la aldea a lo lejos.
- [ ] No podés caerte de la terraza.
- [ ] La iluminación es tenue pero permite navegar y combatir (ajustable, ver limitaciones).
- [ ] No aparecen errores en el panel Salida/Depurador.

Los checklists de las fases 1 a 3 siguen siendo válidos en sus escenas: `main.tscn` y `enemy_test_arena.tscn`.

## Limitaciones conocidas

- **Validación visual pendiente (fase 4):** las 189 pruebas automáticas pasan, pero el aspecto visual con Forward+ y los materiales PBR (niebla, brillo, legibilidad de la oscuridad, escala de las texturas) no se pudo verificar desde la terminal. Los valores de iluminación están en `scenes/levels/the_awakening/awakening_environment.tscn` y en `scenes/props/wall_torch.tscn`, y la escala de las texturas en el `uv1_scale` de `resources/materials/crypt_*.tres`.
- **Checkpoint solo de sesión:** no hay guardado en disco. Al cerrar el juego se pierde.
- **Los enemigos no reaparecen al descansar** (comportamiento soulslike pendiente). Los muertos desaparecen a los 6 s.
- **Las puertas no se cierran** una vez abiertas, y la cerradura (`locked`) existe pero no hay llaves todavía.
- **Coleccionable sin inventario:** solo queda registrado en la sesión.
- **Navmesh generado al cargar:** tarda una fracción de segundo en este nivel. Para niveles mucho más grandes conviene generarlo en el editor y desactivar `bake_on_ready`.
- **Sin evasión entre enemigos:** varios soldados se empujan físicamente pero no se esquivan con inteligencia.
- **El enemigo no salta ni trepa:** por eso no entra a la ruta secundaria ni sube a la terraza.
- **Micro-stutter en monitores de más de 60 Hz:** no está activada la interpolación física.
- **Animaciones provisionales:** Tweens sobre primitivas. El hitbox es rectangular y no sigue el arco de la espada.
- **Proyecto dentro de OneDrive:** la sincronización puede bloquear archivos de `.godot/` durante la importación.
- **Gamepad:** mapeo SDL. Los mandos no reconocidos pueden tener los ejes cambiados.
- **Puertas con jambas:** el modelo de puerta mide 2 m de ancho. Para no deformarlo, cada puerta agrega jambas de piedra y el vano queda en 2 m cuando hay puerta.
- **Peso del repositorio:** los recursos 1K suman unos 34 MB. Si crecen mucho, conviene usar Git LFS.
