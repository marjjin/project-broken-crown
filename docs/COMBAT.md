# Sistema de combate (Fase 2)

Documentación técnica del combate: arquitectura, componentes, parámetros y cómo extenderlo.

## Vista general

```
Player (CharacterBody3D, PlayerController)        ← locomoción de la fase 1
├── Visual
│   ├── Rig  (pivote animable: cuerpo, visor, WeaponPivot → espada)
│   └── AttackHitbox (Hitbox)                     ← detecta, no daña
├── Hurtbox (Hurtbox → HealthComponent)           ← recibe golpes
├── HealthComponent
├── StaminaComponent
├── ActionAnimator (PlaceholderActionAnimator)    ← presentación
├── ActionController (PlayerActionController)     ← máquina de estados
└── CameraRig
```

Flujo de un golpe:

```
PlayerActionController ──activate()──► Hitbox ──hit_detected(hurtbox)──► PlayerActionController
        │                                                                     │
        │                                     hurtbox.receive_hit(DamageInfo) ▼
        │                                         Hurtbox ──apply_damage──► HealthComponent
        │                                                                     │
        ▼                                                 damaged / died signals
 ActionAnimator (visual)                          ▼                ▼
                                         TrainingDummy        CombatHud
```

- **Detección y daño están separados.** El `Hitbox` solo emite `hit_detected`. El dueño del hitbox (jugador, trampa o, en el futuro, un enemigo) construye el `DamageInfo` y llama a `Hurtbox.receive_hit()`.
- **Un golpe por objetivo y por activación.** El `Hitbox` guarda los IDs de las entidades ya golpeadas y los limpia en cada `activate()`. Una entidad con varios hurtboxes también recibe un único golpe.
- **Sin daño por contacto.** El hitbox solo está activo dentro de la ventana `hit_start`–`hit_end` del ataque.
- **Objetivos válidos** por capas físicas, además de ignorar los hurtboxes de la propia entidad (`Hitbox.source`).

### Capas físicas

| Capa | Nombre | Quién la usa |
|---|---|---|
| 1 | `world` | Escenario y cuerpo del maniquí |
| 2 | `player` | Cápsula del jugador |
| 3 | `player_hurtbox` | Hurtbox del jugador. Máscara de los hitboxes enemigos y de la trampa |
| 4 | `enemy_hurtbox` | Hurtbox de maniquíes y enemigos. Máscara del hitbox del jugador |
| 5 | `enemy` | Cuerpo físico de los enemigos. El jugador lo incluye en su máscara para no atravesarlos |

Los enemigos (fase 3) usan exactamente este mismo circuito de daño. Ver [ENEMIES.md](ENEMIES.md).

Los hitboxes usan `collision_layer = 0`, `monitoring = true` y `monitorable = false`. Los hurtboxes usan `collision_mask = 0`, `monitoring = false` y `monitorable = true`.

## Componentes

| Script | Responsabilidad | Señales |
|---|---|---|
| `combat/health_component.gd` | Vida, invulnerabilidad, muerte y revivir | `health_changed`, `damaged`, `damage_prevented`, `invulnerability_changed`, `died`, `revived` |
| `combat/stamina_component.gd` | Consumo "todo o nada" y regeneración con retardo | `stamina_changed`, `consume_failed` |
| `combat/hitbox.gd` | Detección de hurtboxes durante una ventana activa | `hit_detected` |
| `combat/hurtbox.gd` | Puente entre la física y `HealthComponent` | `hit_received` |
| `combat/damage_info.gd` | Datos de un golpe (cantidad, fuente y nombre del ataque) | — |
| `combat/weapon_data.gd` | Resource con los datos del arma | — |
| `combat/player_action_settings.gd` | Resource con la esquiva, el aturdimiento y el respawn | — |
| `player/player_action_controller.gd` | Estados, reglas, combos, buffer y esquiva | `state_changed` |
| `animation/action_animator.gd` | Interfaz de animación (no-ops) | — |
| `animation/placeholder_action_animator.gd` | Animaciones provisionales con Tweens | — |
| `level/training_dummy.gd` | Reacciones del maniquí, caída y reaparición | — |
| `level/damage_pulse_trap.gd` | Trampa de prueba que daña de forma periódica | — |
| `ui/combat_hud.gd` | Barras y estado (solo por señales) | — |

`StaminaComponent` solo procesa mientras regenera. Con la barra llena no consume CPU.

## Máquina de estados

Es un enum simple dentro de `PlayerActionController`, a propósito sin framework.

| Estado | Entra por | Acepta | Sale a |
|---|---|---|---|
| `LOCOMOTION` | Fin de otra acción | Ataque ligero, ataque fuerte, esquiva (en el suelo) | Cualquier acción |
| `LIGHT_ATTACK` | Clic izq. | Durante la fase comprometida, nada; después de `combo_input_open`, guarda el input en el buffer. Durante la recuperación, cualquier acción | Siguiente golpe del combo, ataque fuerte, esquiva o `LOCOMOTION` |
| `HEAVY_ATTACK` | Clic der. con stamina suficiente | Igual que el ligero | Igual |
| `DODGE` | Ctrl con stamina suficiente y sin cooldown | Nada | `LOCOMOTION` (y arranca el cooldown) |
| `STAGGER` | Recibir daño (fuera de los i-frames) | Nada | `LOCOMOTION` después de `stagger_duration` |
| `DEAD` | Vida en 0 | Nada | Respawn después de `respawn_delay` |

Línea de tiempo de un ataque (en segundos desde el inicio):

```
0 ──── hit_start ════ hitbox activo ════ hit_end ──── duration ──── duration + recovery_time
[ comprometido: no se puede iniciar otra acción     ][ recuperación: combo / cancelar / moverse ]
          ▲ desde combo_input_open el input queda en el buffer y se ejecuta al llegar a duration
```

- Durante el golpe el jugador se mueve según `attack_move_speed_multiplier` (hoy 1 = libre) y el golpe sigue la dirección en la que se mueve. No puede saltar hasta la recuperación.
- Durante la recuperación tiene movimiento y salto completos, y la ventana de combo sigue abierta.
- Si la ventana expira, el siguiente ataque ligero vuelve al golpe 1.
- La esquiva usa `PlayerController.set_horizontal_override()`, pero `move_and_slide()` sigue corriendo en el controlador, así que **respeta las colisiones**. La velocidad decrece linealmente (`v = 2d/T · (1 − t/T)`), lo que recorre exactamente `dodge_distance` si no hay obstáculos.
- Sin dirección de movimiento, la esquiva es un paso atrás (configurable con `neutral_dodge_backwards`).

## Parámetros configurables

### `resources/weapons/royal_guard_sword.tres` (`WeaponData`)

| Parámetro | Valor | Descripción |
|---|---|---|
| `id` / `display_name` | `royal_guard_sword` / Espada de la Guardia Real | |
| `light_damage` | 12 | Daño base del golpe ligero |
| `light_combo_multipliers` | [1, 1, 1.5] | Multiplicador por golpe del combo. La longitud del array es la longitud del combo |
| `heavy_damage` | 30 | |
| `heavy_stamina_cost` | 30 | |
| `reach` / `hit_width` / `hit_height` | 1.6 / 1.4 / 1.4 m | Tamaño del hitbox frente al personaje |
| `light_duration`, `light_hit_start`, `light_hit_end` | 0.45 / 0.14 / 0.30 s | |
| `heavy_duration`, `heavy_hit_start`, `heavy_hit_end` | 0.90 / 0.50 / 0.68 s | |
| `attack_move_speed_multiplier` | 1.0 | Velocidad de movimiento durante el golpe (1 = libre, 0 = clavado en el lugar hasta la recuperación). El salto queda bloqueado durante el golpe |
| `combo_input_open` | 0.15 s | Desde cuándo se guarda el siguiente input en el buffer |
| `recovery_time` | 0.35 s | Ventana para encadenar después de cada ataque |

`WeaponData.validate()` avisa por consola si las ventanas son incoherentes.

### `resources/player/default_action_settings.tres` (`PlayerActionSettings`)

| Parámetro | Valor |
|---|---|
| `dodge_stamina_cost` | 20 |
| `dodge_duration` | 0.42 s |
| `dodge_distance` | 4.2 m |
| `dodge_invulnerability_start` / `_end` | 0.04 / 0.30 s |
| `dodge_cooldown` | 0.2 s |
| `neutral_dodge_backwards` | true |
| `stagger_duration` | 0.4 s |
| `respawn_delay` | 3 s |

### En las escenas

- `Player/HealthComponent.max_health` = 100
- `Player/StaminaComponent`: `max_stamina` = 100, `regen_per_second` = 30, `regen_delay` = 0.8 s
- `TrainingDummy`: `HealthComponent.max_health` = 100 y `respawn_delay` = 4 s (0 = no reaparece; `DummyFar` en el nivel usa 0)
- `DamagePulseTrap`: `damage` = 15, `cycle_time` = 2.5 s, `warning_time` = 0.6 s, `active_time` = 0.15 s

## Cómo extender

- **Arma nueva:** creá un `.tres` de tipo `WeaponData` y asignalo en `ActionController.weapon`. No hace falta tocar código.
- **Enemigo:** ya implementado en la fase 3 (`EnemyMeleeAttack`), con `HealthComponent`, un `Hurtbox` en la capa 4 y un `Hitbox` con máscara en la capa 3. Ver [ENEMIES.md](ENEMIES.md).
- `ActionAnimator` sumó `play_attack(windup, active, recovery)` (ataque genérico en tres fases) y `play_hit(interrupting = true)`. Con `false` el golpe solo hace destellar al personaje, sin cortar su pose.
- **Animaciones reales:** creá un script que extienda `ActionAnimator` y use `AnimationPlayer`/`AnimationTree` en sus métodos, y reemplazá el nodo `ActionAnimator`. Las reglas del juego (ventanas e i-frames) dependen de los datos, no de la animación, así que no cambian. Si en el futuro se quiere que la animación marque los tiempos, se pueden usar *method tracks* que llamen a `hitbox.activate()`.

## Pruebas automatizadas

`tests/combat_tests.gd` carga el nivel real y verifica 48 condiciones: movimiento, golpes sin duplicados, combo, ventanas, stamina, reglas de estado, i-frames, esquiva contra paredes, muerte del maniquí, daño y respawn del jugador, trampa, eventos de input reales y HUD.

```bash
godot --headless --path . --script res://tests/combat_tests.gd
```

El código de salida es la cantidad de fallas (0 significa que todo pasó). La carpeta `tests/` está excluida de las exportaciones.
