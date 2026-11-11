# Enemigos e IA (Fase 3)

Documentación técnica del primer enemigo, el **Soldado Corrompido**, y de la arquitectura de IA reutilizable para los próximos enemigos.

## Escena: `scenes/enemies/corrupted_soldier.tscn`

```
CorruptedSoldier (CharacterBody3D, EnemyCharacter)   capa 5 "enemy", máscara world+player+enemy
├── CollisionShape3D                                 cápsula física
├── Visual (gira hacia donde mira)
│   ├── Rig → Body, Helmet, Eyes, WeaponPivot → Blade
│   └── AttackHitbox (Hitbox)                        máscara: player_hurtbox
├── Hurtbox (Hurtbox → HealthComponent)              capa: enemy_hurtbox
├── HealthComponent                                  max_health se toma de EnemyData
├── ActionAnimator (PlaceholderActionAnimator)
├── MeleeAttack (EnemyMeleeAttack)                   preparación / activo / recuperación + cooldown
├── Perception (EnemyPerception)                     distancia + campo de visión + raycast
├── Navigator (EnemyNavigator : NavigationAgent3D)
├── Brain (EnemyBrain)                               máquina de estados
└── DebugView (EnemyDebugView)                       opcional, se alterna con F3
```

### Separación de responsabilidades

| Script | Qué hace | Qué NO hace |
|---|---|---|
| `enemies/enemy_data.gd` | Todos los números del enemigo (Resource) | Lógica |
| `enemies/enemy_character.gd` | Gravedad, aceleración, `move_and_slide`, giro | Decidir a dónde ir |
| `enemies/enemy_perception.gd` | ¿Veo al objetivo? Guarda la última posición conocida | Moverse o atacar |
| `enemies/enemy_navigator.gd` | Rutas con recálculo limitado | Decidir el destino |
| `enemies/enemy_melee_attack.gd` | Tiempos del ataque, activar el hitbox, comprobar la línea de visión al golpear | Modificar la vida (usa `Hurtbox.receive_hit`) |
| `enemies/enemy_brain.gd` | Decide el estado y coordina todo lo anterior | Física, daño o presentación |
| `enemies/enemy_debug_view.gd` | Muestra estado, vida, radio, campo de visión y ruta | — |

**El enemigo no tiene un sistema de daño propio.** Usa los mismos `Hitbox`, `Hurtbox`, `HealthComponent` y `DamageInfo` que el jugador y la trampa. Por eso la invulnerabilidad de la esquiva del jugador funciona contra él sin código extra.

## Máquina de estados (`EnemyBrain`)

Todas las transiciones pasan por `_change_state()`, que aplica las reglas globales: de `DEAD` no se sale, los efectos de entrada se ejecutan una sola vez y se emite `state_changed`.

| Estado | Comportamiento | Transiciones |
|---|---|---|
| `IDLE` | Quieto. También es la espera en cada punto de patrulla | ve al jugador → `CHASE` · pasó `patrol_wait_time` y hay ruta → `PATROL` |
| `PATROL` | Camina al siguiente punto con navegación | ve al jugador → `CHASE` · llega → `IDLE` · punto inalcanzable → lo salta |
| `CHASE` | Persigue la posición del jugador si lo ve, o la última conocida si no | en alcance, mirando al jugador y sin cooldown → `ATTACK` · condición de abandono → `RETURN` |
| `ATTACK` | Quieto. `EnemyMeleeAttack` ejecuta el golpe | termina el ataque → `CHASE` |
| `RETURN` | Vuelve al punto de patrulla actual (o al punto de aparición) | llega → `IDLE` · ve al jugador cerca de casa → `CHASE` |
| `HURT` | Aturdido `hurt_duration` segundos | → `CHASE` (el golpe delata al atacante) |
| `DEAD` | Apaga ataque, percepción, navegación, hurtbox, colisión y física | ninguna (terminal) |

**Condiciones de abandono** (CHASE → RETURN):
- No ve al jugador desde hace más de `lose_sight_time`.
- El jugador está a más de `lose_target_distance`.
- El enemigo se alejó más de `leash_distance` del punto donde empezó a perseguir.
- El jugador murió.
- La última posición conocida es inalcanzable durante más de `unreachable_give_up_time`.

**Sin parpadeos de estado:**
- Para entrar en combate tiene que ver al jugador **y** estar dentro de `detection_radius`. Como `lose_target_distance` es mayor que `detection_radius`, hay histéresis: un dato de visión de hace 0,15 s no puede revertir una decisión de abandono.
- Si el jugador es visible pero inalcanzable (por ejemplo, sobre la plataforma de la arena), el enemigo se queda en el borde mirándolo en lugar de alternar entre perseguir y volver.
- En `RETURN` solo vuelve a perseguir cerca de su zona (`leash_distance × 0.5`).

**Reglas de interrupción** (configurables en `EnemyData`):
- `can_be_staggered`: si es `false`, nunca se interrumpe.
- `stagger_damage_threshold`: daño mínimo para interrumpir.
- `armored_while_attacking`: superarmadura durante el ataque.
- `stagger_immunity_time`: después de un aturdimiento, los golpes siguientes no aturden durante ese tiempo. Evita el *stun-lock*: el combo de 3 golpes aturde con el primero y el enemigo puede responder.

Un golpe que no interrumpe igual hace destellar al enemigo y lo pone a perseguir si estaba tranquilo.

## Percepción

1. Distancia horizontal ≤ `detection_radius`.
2. Ángulo dentro de `field_of_view_degrees`, salvo que esté a menos de `proximity_radius` (proximidad).
3. **Raycast** desde los ojos (`eye_height`) hasta el pecho del jugador, solo contra la capa `world`. Las paredes bloquean la visión.

Las comprobaciones corren cada `perception_interval` segundos (0,15), no en cada frame. El primer chequeo de cada enemigo se desfasa al azar para que muchos enemigos no hagan raycasts en el mismo frame. El raycast solo se hace si pasan las pruebas de distancia y ángulo, que son más baratas.

El objetivo se busca por el **grupo `player`**, no por rutas de escena. Si no hay nadie en ese grupo se emite una advertencia y el enemigo nunca detecta a nadie, pero no se rompe.

## Navegación

- `RuntimeNavigationRegion` (`scripts/level/runtime_navigation_region.gd`) genera el navmesh **al cargar el nivel** a partir de los `StaticBody3D` hijos (capa `world`). Si la generación no produce polígonos, lo reporta como error.
- `EnemyNavigator` solo pide una ruta nueva si el destino se movió más de `repath_distance` (0,75 m), y como máximo cada `repath_interval` (0,3 s). Un destino completamente nuevo se aplica al instante.
- Movimiento: el cerebro toma la dirección del siguiente punto de la ruta y se la pasa a `EnemyCharacter`, que sigue usando gravedad y `move_and_slide`. **No atraviesa paredes:** la ruta las rodea y la física lo impide igual.
- **Vigilante de progreso:** si hacia un destino fijo no se acerca al menos 10 cm en 1 s (por ejemplo, empujando un pilar junto a un punto que quedó fuera del navmesh), ese tiempo también cuenta como inalcanzable. Con destinos que se mueven, como un jugador perseguido, se reinicia.
- **Destinos inalcanzables:** el tiempo sin progreso se acumula en `_unreachable_time`. Pasado `unreachable_give_up_time`, el enemigo salta el punto de patrulla, abandona la persecución o se queda en el lugar si no puede volver a casa. Nunca se bloquea.

> Detalle técnico: el navmesh queda unos 0,5 m sobre el suelo por la cuantización en celdas, y `NavigationAgent3D` mide la distancia en 3D. Por eso `path_desired_distance` y `target_desired_distance` valen 1,0 m. La llegada real la mide el cerebro en plano horizontal con `arrival_tolerance`, y el último tramo se recorre en línea recta.

## Combate del enemigo

```
CHASE: jugador visible, a ≤ attack_range, mirándolo (±25°), sin cooldown
  └─► ATTACK: windup (sigue girando hacia el jugador) → active (hitbox encendido) → recovery → cooldown
```

- **El daño solo se aplica en la ventana activa**, una vez por objetivo (gracias a `Hitbox`).
- **No golpea a través de paredes:** no empieza un ataque sin línea de visión, y además, en el momento del impacto, `EnemyMeleeAttack` vuelve a lanzar un raycast antes de aplicar el daño.
- **No golpea fuera de alcance:** el hitbox mide `attack_reach` de profundidad frente al cuerpo.
- **La esquiva funciona:** el daño pasa por `HealthComponent.apply_damage`, que lo rechaza durante los i-frames.
- Si lo interrumpen, el ataque se cancela y **igual se aplica el cooldown**, así no contraataca al instante.

## Configuración: `resources/enemies/corrupted_soldier.tres` (`EnemyData`)

| Grupo | Parámetro | Valor |
|---|---|---|
| Identidad | `id` / `display_name` | `corrupted_soldier` / Soldado Corrompido |
| Vida | `max_health` | 80 |
| Movimiento | `patrol_speed` / `chase_speed` | 1,8 / 4,0 m/s (el jugador camina a 4,5 y corre a 7,5: se le puede escapar) |
| | `acceleration` / `rotation_speed` | 20 / 8 |
| Ataque | `attack_damage` | 20 |
| | `attack_range` | 1,8 m (distancia para iniciar) |
| | `attack_reach` × `attack_width` × `attack_height` | 1,7 × 1,2 × 1,4 m |
| | `attack_windup` / `attack_active` / `attack_recovery` | 0,6 / 0,18 / 0,6 s |
| | `attack_cooldown` | 1,2 s |
| | `track_target_during_windup` | true |
| Percepción | `detection_radius` | 12 m |
| | `field_of_view_degrees` | 110° |
| | `proximity_radius` | 2 m (0 = desactivada) |
| | `eye_height` / `perception_interval` | 1,6 m / 0,15 s |
| Persecución | `lose_target_distance` / `leash_distance` | 18 / 25 m |
| | `lose_sight_time` / `unreachable_give_up_time` | 3 / 2 s |
| Patrulla | `patrol_wait_time` / `arrival_tolerance` | 1,5 s / 0,6 m |
| Reacciones | `can_be_staggered` / `stagger_damage_threshold` | true / 0 |
| | `armored_while_attacking` | false |
| | `hurt_duration` / `stagger_immunity_time` | 0,45 / 1,2 s |
| | `corpse_duration` | 6 s (0 = el cuerpo queda) |

`EnemyData.validate()` avisa por consola de combinaciones problemáticas, por ejemplo un `attack_range` que el hitbox no alcanza o un `lose_target_distance` menor que el radio de detección.

## Cómo crear otro enemigo

1. Duplicá `corrupted_soldier.tres` y cambiá los valores. Para cambiar solo los números no hace falta código.
2. Duplicá la escena o heredala (*Nueva escena heredada*), asigná el nuevo `EnemyData` en el nodo raíz y cambiá la parte visual.
3. Para un patrón de ataque distinto, creá otro componente al estilo de `EnemyMeleeAttack` con la misma interfaz (`can_start`, `start`, `cancel`, `is_attacking`).

## Agregar un enemigo a un nivel

1. El nivel necesita un **`NavigationRegion3D` con navmesh**: usá `RuntimeNavigationRegion` o generalo en el editor. La geometría estática va como hija.
2. Instanciá `corrupted_soldier.tscn`.
3. Para patrullar, creá un `Node3D` con `Marker3D` hijos (en orden) y asignalo a **Brain → Patrol Route** (botón *Editable Children* en la instancia, o desde el inspector). Sin ruta, el enemigo queda en Idle sin errores.
4. El jugador tiene que estar en el grupo `player`. `player.tscn` ya lo está.

## Depuración

- **F3** alterna la vista de depuración de todos los enemigos: estado, vida, "VE AL JUGADOR", círculo de detección, bordes del campo de visión y ruta de navegación (celeste). En la arena arranca visible.
- `DebugView.log_transitions = true` imprime **una línea por transición** (`[CorruptedSoldier] Patrol -> Chase`), nunca por frame.
- En el editor, *Depurar → Navegación visible* muestra el navmesh generado.

## Pruebas automatizadas

`tests/enemy_tests.gd` carga la arena real y verifica 53 condiciones, organizadas en tres etapas:

1. **Patrullaje y detección:** aparición, patrulla en orden, campo de visión, paredes, espalda, proximidad y ausencia de ruta.
2. **Persecución y navegación:** rodear paredes, persecución hasta el alcance, abandono estable sin parpadeos, regreso a la ruta y objetivo inalcanzable.
3. **Combate:** ataque con daño exacto, sin golpes fuera de alcance ni a través de paredes, esquiva con i-frames, daño ligero y fuerte, interrupción del ataque, jugador muerto, muerte y limpieza del enemigo.

```bash
godot --headless --path . --script res://tests/enemy_tests.gd
```
