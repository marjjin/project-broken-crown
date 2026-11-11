# Nivel 1 — El Despertar

El protagonista, un antiguo miembro de la Guardia Real, despierta en su propia tumba más de cien años después de la traición del rey. Recorre la cripta, descansa ante la estatua de la Guardia, atraviesa las catacumbas y sale al exterior, desde donde ve a lo lejos la **Aldea Devastada**.

Escena: `scenes/levels/the_awakening/the_awakening.tscn` (es la escena principal: **F5**).

## Mapa (vista superior, norte = arriba, −Z)

```
                          ┌──────────── F: terraza (y = 3) ────────────┐   → vista de la aldea (norte)
                          └──────────────┬───────── salida ────────────┘
                                         │ rampa ascendente (F)
                     ┌───────────────────┴───────────────────┐
                     │      E: Cámara del Guardián (vacía)   │  antorchas rojas, 4 pilares, coberturas
                     └───────────────────┬───────────────────┘
                                         │
                     ┌───────────────────┴──────┐
                     │ D2: Sala de huesos       │  2 soldados (patrulla + guardia fijo)
                     └───────────────────┬──────┘
                                         │
   ┌──────────────┐  ┌─────────────┐  ┌──┴───────────┐        ┌──────────────┐
   │ C: Sala de   ├──┤ D0 (puerta) ├──┤ D1: Osario   ├─ ▒▒ ───┤ D3: Cripta   │  ruta secundaria:
   │  la Guardia  │  └─────────────┘  │ 1 soldado    │ escom- │ oculta       │  medallón + altar
   │ ★ estatua    │                   └──────────────┘ bros   └──────────────┘  de armas
   └──────┬───────┘
          │ (puerta)
   ┌──────┴───────┐
   │ B2: Salón    │  1 soldado (primer encuentro), pilares, inscripción
   └──────┬───────┘
          │ B1
   ┌──────┴───────┐
   │ A: Cámara    │  inicio, sarcófago, lápida, puerta a la cripta
   │  funeraria   │
   └──────────────┘
```

## Sectores

Cada sector es una escena propia en `scenes/levels/the_awakening/`, armada con instancias de `CryptRoom` (salas y pasillos generados), pilares, antorchas y objetos interactivos. Todas usan coordenadas del nivel.

| Sector | Escena | Contenido | Ambientación |
|---|---|---|---|
| **A — Cámara funeraria** | `sector_a_burial_chamber.tscn` | Inicio del jugador (`PlayerStart`, mirando al norte), sarcófago con la tapa corrida, lápida legible, 4 pilares, **puerta** a la cripta | 4 antorchas cálidas |
| **B — Pasillos de la cripta** | `sector_b_crypt_halls.tscn` | Pasillo B1, salón B2 (10 × 12 m) con 4 pilares y escombros, **primer Soldado Corrompido** patrullando, inscripción del juramento, pasillo B3 | Antorchas cálidas |
| **C — Sala de la Guardia** | `sector_c_guard_hall.tscn` | Sala de 14 × 14 m y 5 m de alto, **estatua de la Guardia Real (checkpoint)**, inscripción, **dos puertas**: la de entrada y la de las catacumbas | **Zona segura:** luz de la estatua fría y azulada que pasa a dorada al activarla, antorchas suaves |
| **D — Catacumbas** | `sector_d_catacombs.tscn` | D0 (paso), D1 osario con 1 soldado, D2 sala de huesos con 2 soldados (uno patrulla y otro hace guardia fijo), **ruta secundaria**: pasillo con escombros que se saltan y cripta oculta D3 con el **Medallón de la Guardia** y el **altar de armas vacío** (`WeaponMount`) | Más oscuro. La cripta oculta tiene una antorcha tenue y el brillo dorado del medallón |
| **E — Cámara del Guardián** | `sector_e_guardian_chamber.tscn` | Arena de 22 × 22 m y 7 m de alto, 4 pilares, 2 coberturas, entrada y salida, `MinibossSpawn` reservado, inscripción. **Vacía**: el miniboss es de una fase posterior | **Peligro:** antorchas rojas |
| **F — Salida de la tumba** | `sector_f_tomb_exit.tscn` | Rampa ascendente de 14 m (sube 3 m), terraza exterior con parapetos y paredes invisibles, **disparador de fin de nivel** | Luz de luna entrando por el pasillo y cielo crepuscular rojizo |
| Vista exterior | `devastated_village_vista.tscn` | Ladera, valle, 14 casas en ruinas (algunas sin techo), torre de iglesia, 3 fuegos y una cresta lejana. **Solo mallas, sin colisiones** | Niebla de distancia y fuegos naranjas |

**Ruta principal:** A → B → C (checkpoint) → D1 → D2 → E → F.
**Ruta secundaria (opcional):** D1 → pasillo este → saltar los escombros → D3.

### Orientación sin flechas

- Las antorchas marcan los vanos de la ruta principal.
- La sala segura usa luz fría y la arena usa luz roja.
- El brillo dorado del medallón se ve desde el pasillo de la ruta secundaria.
- La luz de luna invita a subir por la rampa.

## Construcción modular

| Pieza | Archivo | Uso |
|---|---|---|
| `CryptRoom` (`@tool`) | `scripts/level/crypt_room.gd`, `scenes/level/crypt_room.tscn` | Sala o pasillo: `inner_size`, `height`, `wall_thickness` y `openings` (lado, desplazamiento, ancho). Genera piso, paredes, dinteles y techo con `BoxObstacle`. Se ve en el editor y se actualiza al cambiar los valores |
| Pilar | `scenes/props/crypt_pillar.tscn` | Fuste + capitel |
| Antorcha | `scenes/props/wall_torch.tscn` | Soporte + llama emisiva + `OmniLight3D` sin sombras con parpadeo (`TorchFlicker`) |
| Casa en ruinas | `scenes/props/ruined_house.tscn` | Solo mallas |
| Puerta | `scenes/interaction/crypt_door.tscn` | Ver [INTERACTION.md](INTERACTION.md) |
| Estatua (checkpoint) | `scenes/interaction/guard_statue.tscn` | Ver [INTERACTION.md](INTERACTION.md) |
| Inscripción | `scenes/interaction/inscription_tablet.tscn` | Lápida legible (título + texto configurables) |
| Altar de armas | `scenes/interaction/weapon_altar.tscn` | Inscripción con un `WeaponMount` para una futura segunda arma |
| Medallón | `scenes/interaction/guard_medallion.tscn` | Coleccionable provisional |

Toda la geometría es provisional. Una `CryptRoom` o un pilar se reemplazan por un modelo sin tocar la lógica, porque la lógica vive en las puertas, la estatua, los enemigos y el `LevelController`, no en la geometría.

### Materiales compartidos

En `resources/materials/`: `crypt_wall`, `crypt_floor` y `crypt_ceiling` son **PBR con texturas CC0 de Poly Haven** (albedo, normal, rugosidad y AO a 1K, triplanar en coordenadas del mundo, así la escala es igual en cualquier caja). `statue_stone` es piedra procedural, más `flame`, `relic_gold`, `old_wood`, `dark_iron`, `ruin_plaster` y `burnt_roof`. Todas las piezas reutilizan estos materiales.

## Navegación

- Una única `RuntimeNavigationRegion` (`Crypt`) contiene los seis sectores y genera el navmesh al cargar el nivel (alrededor de 250 polígonos).
- **Filtro de altura** (`filter_baking_aabb`, y de −1 a 0,85): no se genera navmesh sobre muros, pilares, techos ni sarcófagos.
- **Puertas:** cerradas, la hoja se incluye como pared en el navmesh. Al terminar de abrirse habilitan un `NavigationLink3D` a través del vano, sin regenerar la región.
- **Escombros** de la ruta secundaria (0,9 m): el jugador los salta, pero el navmesh no los cruza, así que los enemigos no entran a D3.
- La rampa y la terraza (sector F) quedan fuera de la navegación porque ahí no hay enemigos.

## Iluminación y rendimiento

- **Renderizador Forward+.**
  - Entorno: niebla volumétrica tenue, niebla de distancia, SSAO, glow y tonemapping AgX.
  - Luz ambiente fría y baja.
  - Una luna direccional con sombras para el exterior; los techos bloquean su luz dentro de la cripta.
- **Luces:** 28 `OmniLight3D` en total (antorchas, estatua, medallón, luz de luna y fuegos de la aldea). **Solo la estatua proyecta sombras.**
- **Sin scripts por frame en el nivel:** el parpadeo de las antorchas y la animación del medallón son Tweens en bucle del motor, la indicación de interacción reacciona a señales de área y el HUD reacciona a señales.
- **Geometría:** cajas con colisión `BoxShape3D`. La aldea no tiene colisiones.

## Flujo del nivel

1. `LevelController` coloca al jugador en `PlayerStart` (incluida la orientación de la cámara), registra el nivel en `GameSession` y muestra el título.
2. Puertas, estatua, inscripciones y coleccionable funcionan solos mediante `Interactable`.
3. Al entrar en la zona de salida de la terraza, `LevelExit` marca el nivel como completado y muestra el mensaje final. El jugador queda dentro del escenario y todavía no se carga otra región.
