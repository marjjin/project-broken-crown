# Interacción, checkpoints y sesión (Fase 4)

## Sistema de interacción

Un único contrato, sin sistemas distintos por tipo de objeto:

```
Player
└── Interactor (PlayerInteractor, Area3D, máscara: capa 6 "interactable")
        │ area_entered / area_exited → candidatos
        │ elige el mejor (más cerca + más de frente) → focus_changed(target)
        │ tecla E (InputActions.INTERACT) → target.interact(player)
        ▼
Interactable (Area3D, capa 6)  ──interacted(interactor)──►  Door / Checkpoint / Inscription / Collectible
```

| Pieza | Archivo | Responsabilidad |
|---|---|---|
| `Interactable` | `scripts/interaction/interactable.gd` | Contrato: `prompt`, `enabled`, `one_shot`, `can_interact()`, `interact()`, señal `interacted` |
| `PlayerInteractor` | `scripts/interaction/player_interactor.gd` | Detecta candidatos por señales de área, elige el foco y ejecuta la interacción con **E** (gamepad: X o Cuadrado) |
| `LevelHud` | `scripts/ui/level_hud.gd` | Muestra la indicación `[E] <prompt>` y el cartel de mensajes |

### Reglas

- **Alcance:** solo cuentan los `Interactable` que tocan la esfera de 1,6 m del jugador. Fuera de esa distancia no hay foco ni indicación.
- **Prioridad:** gana el más cercano, con bonificación al que está de frente.
- **Estados bloqueados:** muerto, atacando, esquivando o aturdido no se puede interactuar, solo en `LOCOMOTION`. La indicación desaparece mientras tanto.
- **Rendimiento:** sin candidatos cerca, el interactor no procesa nada. Con candidatos, reevalúa el foco 10 veces por segundo.

### Cómo agregar un objeto interactivo

1. Agregá a tu escena un hijo `Area3D` con `interactable.gd`, capa 6, máscara 0, `monitoring` apagado y una `CollisionShape3D` que defina el alcance.
2. En el script del objeto, conectá `interactable.interacted` y hacé lo que corresponda.
3. Listo: la detección, la indicación y la tecla ya funcionan.

## Puertas (`Door`, `scenes/interaction/crypt_door.tscn`)

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `starts_open` | false | Arranca abierta |
| `locked` / `locked_message` | false / "Está trabada. No cede." | Si está trabada, muestra el mensaje en lugar de abrirse. `unlock()` la destraba (para llaves futuras) |
| `prompt_open` / `prompt_locked` | "Abrir" / "Examinar" | Texto de la indicación |
| `open_angle_degrees` | 90 | Positivo: abre hacia −Z local, alejándose de quien está del lado +Z. Negativo: hacia +Z. Con 90° queda pegada a la pared |
| `open_duration` | 0,9 s | Duración de la animación provisional |

- **Colisión:** la hoja es un `AnimatableBody3D` en la capa `world`. Cerrada bloquea al jugador. La animación mueve **directamente** su transformación alrededor de la bisagra y en el tick de física, porque un cuerpo sincronizado con la física no sigue una transformación heredada de un padre animado.
- **Navegación:** cerrada, el navmesh la trata como pared. Al terminar de abrirse habilita su `NavigationLink3D` (1,6 m a cada lado del vano) y los enemigos pueden atravesarla sin regenerar la región.
- Una puerta abierta deshabilita su `Interactable` (no vuelve a cerrarse en esta fase).

## Checkpoint (`Checkpoint`, `scenes/interaction/guard_statue.tscn`)

Al **descansar** (E) frente a la estatua de la Guardia Real:

1. `player.set_spawn_point(SpawnPoint)` fija la posición y la orientación de reaparición.
2. `HealthComponent.revive()` y `StaminaComponent.refill()`: se reutilizan los componentes existentes, sin duplicar lógica.
3. `GameSession.activate_checkpoint(id)` lo registra como activo. Las demás estatuas se apagan solas al escuchar la señal.
4. Confirmación visual: el cartel "Punto de descanso", la luz que pasa de azul tenue a dorada y una llama a los pies.

**Al morir**, el flujo existente (`PlayerActionController`) no cambia:
- **muerte:** se ejecuta `respawn_delay` (3 s),
- **reaparición:** `player.respawn()` lleva al jugador al último punto de reaparición y orienta la cámara detrás de él,
- **restauración:** `revive()` y `refill()`,
- **reinicio de estados:** `reset_pose()` y vuelta a locomoción.

Si el jugador cae fuera del mapa, también reaparece en el último checkpoint.

| Parámetro | Descripción |
|---|---|
| `checkpoint_id` | Identificador (en El Despertar: `guard_hall`) |
| `display_name` | Nombre que se muestra en la confirmación |
| `spawn_point` | `Marker3D` donde reaparece el jugador. Su −Z es hacia donde mira |
| `inactive_energy` / `active_energy`, `inactive_color` / `active_color` | Luz de la estatua |

El checkpoint dura **solo la sesión**: no se guarda en disco.

## Inscripciones, coleccionable y salida

| Objeto | Script | Comportamiento |
|---|---|---|
| Inscripción / altar | `inscription.gd` | Muestra `title` y `text` en el cartel |
| Medallón | `collectible.gd` | `GameSession.collect(id)`, cartel "Obtenido: …" y desaparece. Si ya se recogió en la sesión, no vuelve a aparecer. **Sin inventario** todavía |
| Salida | `scripts/levels/level_exit.gd` | Al entrar el jugador (grupo `player`): `GameSession.complete_level()` y mensaje final, una sola vez |

## `GameSession` (autoload)

`scripts/core/game_session.gd` (clase `GameSessionState`, registrada como autoload `GameSession`) es el estado de la sesión en memoria y el canal de eventos del nivel. Los objetos anuncian lo que pasa y la interfaz escucha, así que ningún objeto del juego referencia al HUD.

| Miembro | Uso |
|---|---|
| `notify(title, body)` → `notification_requested` | Carteles (`LevelHud`) |
| `activate_checkpoint(id)` → `checkpoint_activated`, `active_checkpoint` | Checkpoints |
| `collect(id, name)` → `item_collected`, `has_collected(id)` | Coleccionables |
| `complete_level(id)` → `level_completed`, `is_level_completed(id)` | Final de nivel |
| `start_level(id)`, `current_level`, `reset()` | Ciclo de vida |

Un futuro sistema de guardado puede serializar estos campos sin tocar los objetos del nivel.

> **Acceso:** siempre con `GameSessionState.instance()`, nunca con el identificador global `GameSession`. El acceso estático se resuelve al ejecutar, así que los scripts compilan aunque el editor todavía no haya cargado la lista de autoloads (por ejemplo, justo después de agregarlo) y también en las pruebas con `--script`.
